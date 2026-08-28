import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/data/journey_repository.dart';
import '../../../core/data/organization_repository.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../domain/access_policy.dart';

/// State for authorization process.
enum AuthorizationStatus {
  initial,
  evaluating,
  autoGranted,
  requiresHost,
  hostApproved,
  hostRejected,
  manualReview,
  escalated,
  error,
}

class AuthorizationState {
  final AuthorizationStatus status;
  final AccessDecision? decision;
  final String? errorMessage;
  final DateTime? requestedAt;

  const AuthorizationState({
    this.status = AuthorizationStatus.initial,
    this.decision,
    this.errorMessage,
    this.requestedAt,
  });

  AuthorizationState copyWith({
    AuthorizationStatus? status,
    AccessDecision? decision,
    String? errorMessage,
    DateTime? requestedAt,
  }) {
    return AuthorizationState(
      status: status ?? this.status,
      decision: decision ?? this.decision,
      errorMessage: errorMessage ?? this.errorMessage,
      requestedAt: requestedAt ?? this.requestedAt,
    );
  }
}

/// Provider that evaluates access policy and manages the authorization flow.
class AuthorizationNotifier extends StateNotifier<AuthorizationState> {
  final Ref _ref;

  AuthorizationNotifier(this._ref) : super(const AuthorizationState());

  /// Evaluates the access policy for a visit and determines the path.
  Future<void> evaluate(Map<String, dynamic> visitData) async {
    state = state.copyWith(status: AuthorizationStatus.evaluating);

    try {
      final client = _ref.read(supabaseProvider);
      final journeyRepo = _ref.read(journeyRepositoryProvider);
      final orgRepo = _ref.read(organizationRepositoryProvider);

      final visitId = visitData['id'] as String;
      final trustScore =
          (visitData['_trust_score'] as num?)?.toDouble() ?? 50.0;
      final isPreauthorized = visitData['is_preauthorized'] == true;

      // Get organization settings
      final orgId = visitData['organization_id'] as String? ??
          'a0000000-0000-0000-0000-000000000001';
      final org = await orgRepo.getById(orgId);
      final settings = org?['settings'] as Map<String, dynamic>? ?? {};

      final autoAccessEnabled =
          settings['auto_access_enabled'] as bool? ?? false;
      final trustThreshold =
          (settings['trust_threshold'] as num?)?.toDouble() ??
              AppConstants.defaultTrustThreshold;

      // Check schedule
      final isWithinSchedule = _checkSchedule(visitData);

      // Build access context
      final accessContext = AccessContext(
        isPreAuthorized: isPreauthorized,
        isWithinSchedule: isWithinSchedule,
        hasValidIdentity: visitData['_evidence_complete'] == true,
        hasAcceptableEvidence: visitData['_evidence_complete'] == true,
        trustScore: trustScore,
        autoAccessEnabled: autoAccessEnabled,
        trustThreshold: trustThreshold,
        visitorType: visitData['visitors']?['visitor_type'] ?? 'VISITOR',
      );

      // Evaluate policy
      final engine = AccessPolicyEngine();
      final decision = engine.evaluate(accessContext);

      // Store the decision in DB
      await client.from('access_decisions').insert({
        'visit_id': visitId,
        'decision': decision.decision,
        'decided_by': decision.isGranted ? 'POLICY_AUTO' : null,
        'reason': decision.reason,
      });

      // Log journey event
      if (decision.isGranted) {
        await journeyRepo.logEvent(
          visitId: visitId,
          eventType: 'AUTO_AUTHORIZED',
          payload: {
            'trust_score': trustScore,
            'factors': decision.factors,
          },
        );

        state = state.copyWith(
          status: AuthorizationStatus.autoGranted,
          decision: decision,
        );
      } else if (decision.requiresHost) {
        await journeyRepo.logEvent(
          visitId: visitId,
          eventType: 'ACCESS_REQUESTED',
          payload: {'reason': decision.reason},
        );
        await journeyRepo.logEvent(
          visitId: visitId,
          eventType: 'HOST_NOTIFIED',
          payload: {'host_id': visitData['host_id']},
        );

        state = state.copyWith(
          status: AuthorizationStatus.requiresHost,
          decision: decision,
          requestedAt: DateTime.now(),
        );
      } else if (decision.isDenied) {
        await journeyRepo.logEvent(
          visitId: visitId,
          eventType: 'HOST_REJECTED',
          payload: {'reason': decision.reason, 'auto': true},
        );

        state = state.copyWith(
          status: AuthorizationStatus.manualReview,
          decision: decision,
        );
      } else {
        // MANUAL_REVIEW
        await journeyRepo.logEvent(
          visitId: visitId,
          eventType: 'ACCESS_REQUESTED',
          payload: {'reason': decision.reason, 'manual_review': true},
        );

        state = state.copyWith(
          status: AuthorizationStatus.manualReview,
          decision: decision,
          requestedAt: DateTime.now(),
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthorizationStatus.error,
        errorMessage: 'Error al evaluar acceso: $e',
      );
    }
  }

  /// Simulates host approval (for MVP, will use Realtime later).
  Future<void> simulateHostApproval(String visitId) async {
    try {
      final client = _ref.read(supabaseProvider);
      final journeyRepo = _ref.read(journeyRepositoryProvider);

      await client.from('access_decisions').insert({
        'visit_id': visitId,
        'decision': 'GRANTED',
        'decided_by': 'HOST',
        'reason': 'Host approved the visit',
      });

      await journeyRepo.logEvent(
        visitId: visitId,
        eventType: 'HOST_APPROVED',
      );

      state = state.copyWith(status: AuthorizationStatus.hostApproved);
    } catch (e) {
      state = state.copyWith(
        status: AuthorizationStatus.error,
        errorMessage: 'Error: $e',
      );
    }
  }

  /// Simulates host rejection.
  Future<void> simulateHostRejection(String visitId, String reason) async {
    try {
      final client = _ref.read(supabaseProvider);
      final journeyRepo = _ref.read(journeyRepositoryProvider);

      await client.from('access_decisions').insert({
        'visit_id': visitId,
        'decision': 'DENIED',
        'decided_by': 'HOST',
        'reason': reason,
      });

      await client
          .from('visits')
          .update({'status': 'REJECTED'})
          .eq('id', visitId);

      await journeyRepo.logEvent(
        visitId: visitId,
        eventType: 'HOST_REJECTED',
        payload: {'reason': reason},
      );

      state = state.copyWith(status: AuthorizationStatus.hostRejected);
    } catch (e) {
      state = state.copyWith(
        status: AuthorizationStatus.error,
        errorMessage: 'Error: $e',
      );
    }
  }

  /// Triggers escalation when host doesn't respond.
  Future<void> escalate(String visitId) async {
    try {
      final journeyRepo = _ref.read(journeyRepositoryProvider);

      await journeyRepo.logEvent(
        visitId: visitId,
        eventType: 'ESCALATED',
        payload: {'reason': 'Host timeout'},
      );

      state = state.copyWith(status: AuthorizationStatus.escalated);
    } catch (e) {
      state = state.copyWith(
        status: AuthorizationStatus.error,
        errorMessage: 'Error: $e',
      );
    }
  }

  bool _checkSchedule(Map<String, dynamic> visitData) {
    final scheduledStart = visitData['scheduled_start'] as String?;
    final scheduledEnd = visitData['scheduled_end'] as String?;

    if (scheduledStart == null) return true; // No schedule = always valid

    final now = DateTime.now();
    final start = DateTime.parse(scheduledStart);
    final end = scheduledEnd != null ? DateTime.parse(scheduledEnd) : null;

    // Allow 30 min early
    final earlyWindow = start.subtract(const Duration(minutes: 30));

    if (now.isBefore(earlyWindow)) return false;
    if (end != null && now.isAfter(end.add(const Duration(minutes: 15)))) {
      return false;
    }
    return true;
  }
}

/// Provider for AuthorizationNotifier.
final authorizationProvider =
    StateNotifierProvider<AuthorizationNotifier, AuthorizationState>((ref) {
  return AuthorizationNotifier(ref);
});
