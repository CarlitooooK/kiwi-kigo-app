import 'package:equatable/equatable.dart';
import '../../../core/constants/app_constants.dart';

/// The result of an access policy evaluation.
class AccessDecision extends Equatable {
  final String decision; // GRANTED, DENIED, REQUIRES_HOST, MANUAL_REVIEW
  final String reason;
  final List<String> factors;

  const AccessDecision({
    required this.decision,
    required this.reason,
    this.factors = const [],
  });

  bool get isGranted => decision == AppConstants.decisionGranted;
  bool get requiresHost => decision == AppConstants.decisionRequiresHost;
  bool get isDenied => decision == AppConstants.decisionDenied;

  @override
  List<Object?> get props => [decision, reason, factors];
}

/// Context data for evaluating access policy.
class AccessContext {
  final bool isPreAuthorized;
  final bool isWithinSchedule;
  final bool hasValidIdentity;
  final bool hasAcceptableEvidence;
  final double trustScore;
  final bool autoAccessEnabled;
  final double trustThreshold;
  final String visitorType;

  const AccessContext({
    required this.isPreAuthorized,
    required this.isWithinSchedule,
    required this.hasValidIdentity,
    required this.hasAcceptableEvidence,
    required this.trustScore,
    required this.autoAccessEnabled,
    required this.trustThreshold,
    required this.visitorType,
  });
}

/// Access Policy Engine.
/// 
/// Evaluates whether a visit should be automatically granted,
/// requires host approval, or should be denied.
/// 
/// The AI (TrustScore) provides information.
/// The policy determines the action.
class AccessPolicyEngine {
  /// Evaluates access based on all available context.
  AccessDecision evaluate(AccessContext context) {
    final factors = <String>[];

    // Pre-authorized + valid identity = fast track
    if (context.isPreAuthorized && context.hasValidIdentity) {
      factors.add('Pre-authorized visit');
      factors.add('Valid identity');

      if (context.isWithinSchedule) {
        factors.add('Within schedule');
        return AccessDecision(
          decision: AppConstants.decisionGranted,
          reason: 'Pre-authorized visit with valid identity within schedule',
          factors: factors,
        );
      } else {
        factors.add('Outside schedule');
        // Still grant if trust is high enough
        if (context.trustScore >= context.trustThreshold) {
          return AccessDecision(
            decision: AppConstants.decisionGranted,
            reason: 'Pre-authorized with acceptable trust score',
            factors: factors,
          );
        }
      }
    }

    // Auto-access enabled + all criteria met
    if (context.autoAccessEnabled &&
        context.hasValidIdentity &&
        context.hasAcceptableEvidence &&
        context.trustScore >= context.trustThreshold &&
        context.isWithinSchedule) {
      factors.addAll([
        'Auto-access enabled',
        'Valid identity',
        'Acceptable evidence',
        'Trust score: ${context.trustScore}',
        'Within schedule',
      ]);
      return AccessDecision(
        decision: AppConstants.decisionGranted,
        reason: 'AI-assisted access: all criteria met',
        factors: factors,
      );
    }

    // Not enough for auto-grant, but not a reject either
    if (context.hasValidIdentity && context.hasAcceptableEvidence) {
      factors.add('Valid identity and evidence');
      if (context.trustScore < context.trustThreshold) {
        factors.add('Trust score below threshold');
      }
      if (!context.autoAccessEnabled) {
        factors.add('Auto-access not enabled');
      }
      return AccessDecision(
        decision: AppConstants.decisionRequiresHost,
        reason: 'Host authorization required',
        factors: factors,
      );
    }

    // Missing critical evidence
    if (!context.hasValidIdentity || !context.hasAcceptableEvidence) {
      factors.add('Missing or invalid evidence');
      return AccessDecision(
        decision: AppConstants.decisionManualReview,
        reason: 'Insufficient evidence for automated decision',
        factors: factors,
      );
    }

    return AccessDecision(
      decision: AppConstants.decisionRequiresHost,
      reason: 'Default: requires host approval',
      factors: factors,
    );
  }
}
