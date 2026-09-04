import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/welcome/presentation/welcome_screen.dart';
import '../../features/welcome/presentation/recurrent_entry_screen.dart';
import '../../features/welcome/presentation/host_fast_entry_screen.dart';
import '../../features/support/presentation/support_screen.dart';
import '../../features/visits/presentation/visit_lookup_screen.dart';
import '../../features/visits/presentation/visit_found_screen.dart';
import '../../features/visits/presentation/visitor_registration_screen.dart';
import '../../features/visits/presentation/purpose_screen.dart';
import '../../features/visits/presentation/kiosk_identity_screen.dart';
import '../../features/visits/presentation/kiosk_context_screen.dart';
import '../../features/voice/presentation/voice_registration_screen.dart';
import '../../features/consent/presentation/consent_screen.dart';
import '../../features/identity/presentation/identity_capture_screen.dart';
import '../../features/evidence/presentation/photo_capture_screen.dart';
import '../../features/evidence/presentation/evidence_processing_screen.dart';
import '../../features/evidence/presentation/evidence_result_screen.dart';
import '../../features/authorization/presentation/waiting_approval_screen.dart';
import '../../features/authorization/presentation/checked_in_screen.dart';
import '../../features/authorization/presentation/access_denied_screen.dart';
import '../../features/journey/presentation/active_visit_screen.dart';
import '../../features/journey/presentation/checkout_screen.dart';
import '../../features/journey/presentation/visit_completed_screen.dart';

/// Kigo motion: slide forward 300ms, back 250ms — smooth cubic
CustomTransitionPage<void> _slideTransition(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Forward: this screen slides in from the right when entering.
      final slideIn = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeInOutCubic));
      // When another screen covers this one, it slides slightly left + fades.
      final slideOut = Tween(begin: Offset.zero, end: const Offset(-0.3, 0.0))
          .chain(CurveTween(curve: Curves.easeInOutCubic));
      final fadeOut = Tween(begin: 1.0, end: 0.5)
          .chain(CurveTween(curve: Curves.easeIn));

      // IMPORTANT: render `child` exactly ONCE. Both the incoming (animation)
      // and outgoing (secondaryAnimation) motions are composed onto the same
      // subtree — rendering `child` twice duplicates any GlobalKey it holds
      // (e.g. Form keys), flooding "Multiple widgets used the same GlobalKey".
      return SlideTransition(
        position: secondaryAnimation.drive(slideOut),
        child: FadeTransition(
          opacity: secondaryAnimation.drive(fadeOut),
          child: SlideTransition(
            position: animation.drive(slideIn),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Kigo motion: fade + scale for result/success screens (400ms)
CustomTransitionPage<void> _fadeScaleTransition(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fadeTween = Tween(begin: 0.0, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOut));
      final scaleTween = Tween(begin: 0.95, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: animation.drive(fadeTween),
        child: ScaleTransition(
          scale: animation.drive(scaleTween),
          child: child,
        ),
      );
    },
  );
}

/// Route paths
class RoutePaths {
  RoutePaths._();

  // Kiosk routes (Visitor experience)
  static const String welcome = '/';
  static const String visitLookup = '/visit-lookup';
  static const String visitFound = '/visit-found';
  static const String registration = '/register';
  static const String consent = '/consent';
  static const String identity = '/identity';
  static const String photo = '/photo';
  static const String processing = '/processing';
  static const String processingResult = '/processing-result';
  static const String waitingApproval = '/waiting-approval';
  static const String checkedIn = '/checked-in';
  static const String accessDenied = '/access-denied';
  static const String activeVisit = '/active-visit';
  static const String checkout = '/checkout';
  static const String visitCompleted = '/visit-completed';
}

/// Router provider — single instance shared across the app.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RoutePaths.welcome,
    debugLogDiagnostics: true,
    routes: [
      // === KIOSK ROUTES (Visitor) ===
      GoRoute(
        path: RoutePaths.welcome,
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.visitLookup,
        name: 'visit-lookup',
        pageBuilder: (context, state) => _slideTransition(
          const VisitLookupScreen(), state,
        ),
      ),
      GoRoute(
        path: RoutePaths.visitFound,
        name: 'visit-found',
        pageBuilder: (context, state) {
          final visitData = state.extra as Map<String, dynamic>?;
          if (visitData == null) {
            return _slideTransition(const VisitLookupScreen(), state);
          }
          return _slideTransition(VisitFoundScreen(visitData: visitData), state);
        },
      ),
      GoRoute(
        path: RoutePaths.registration,
        name: 'registration',
        pageBuilder: (context, state) => _slideTransition(
          const VisitorRegistrationScreen(), state,
        ),
      ),
      // New kiosk flow: Purpose → Identity → Context
      GoRoute(
        path: '/kiosk/purpose',
        name: 'kiosk-purpose',
        pageBuilder: (context, state) => _slideTransition(
          PurposeScreen(flowData: state.extra as Map<String, dynamic>?), state,
        ),
      ),
      // Voice-guided registration (on-device STT/TTS), touch fallback inside.
      GoRoute(
        path: '/kiosk/voice',
        name: 'kiosk-voice',
        pageBuilder: (context, state) => _slideTransition(
          const VoiceRegistrationScreen(), state,
        ),
      ),
      // "Ya vengo seguido" — face fast-path for enrolled/recurrent visitors.
      GoRoute(
        path: '/recurrent',
        name: 'recurrent',
        pageBuilder: (context, state) => _slideTransition(
          const RecurrentEntryScreen(), state,
        ),
      ),
      // Host NFC fast-entry — recognized host tapped their card on Welcome.
      GoRoute(
        path: '/host-entry',
        name: 'host-entry',
        pageBuilder: (context, state) => _fadeScaleTransition(
          HostFastEntryScreen(hostName: state.extra as String?), state,
        ),
      ),
      // Support — QR the visitor scans with the Kigo app to call support.
      GoRoute(
        path: '/support',
        name: 'support',
        pageBuilder: (context, state) => _slideTransition(
          const SupportScreen(), state,
        ),
      ),
      GoRoute(
        path: '/kiosk/identity',
        name: 'kiosk-identity',
        pageBuilder: (context, state) {
          final flowData = state.extra as Map<String, dynamic>?;
          return _slideTransition(
            KioskIdentityScreen(flowData: flowData), state,
          );
        },
      ),
      GoRoute(
        path: '/kiosk/context',
        name: 'kiosk-context',
        pageBuilder: (context, state) {
          final flowData = state.extra as Map<String, dynamic>?;
          return _slideTransition(
            KioskContextScreen(flowData: flowData), state,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.consent,
        name: 'consent',
        pageBuilder: (context, state) {
          final visitData = state.extra as Map<String, dynamic>?;
          return _slideTransition(ConsentScreen(visitData: visitData), state);
        },
      ),
      GoRoute(
        path: RoutePaths.identity,
        name: 'identity',
        pageBuilder: (context, state) {
          final visitData = state.extra as Map<String, dynamic>?;
          return _slideTransition(
            IdentityCaptureScreen(visitData: visitData), state,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.photo,
        name: 'photo',
        pageBuilder: (context, state) {
          final visitData = state.extra as Map<String, dynamic>?;
          return _slideTransition(
            PhotoCaptureScreen(visitData: visitData), state,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.processing,
        name: 'processing',
        pageBuilder: (context, state) {
          final visitData = state.extra as Map<String, dynamic>?;
          return _fadeScaleTransition(
            EvidenceProcessingScreen(visitData: visitData), state,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.processingResult,
        name: 'processing-result',
        pageBuilder: (context, state) {
          final visitData = state.extra as Map<String, dynamic>?;
          return _fadeScaleTransition(
            EvidenceResultScreen(visitData: visitData), state,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.waitingApproval,
        name: 'waiting-approval',
        pageBuilder: (context, state) {
          final visitData = state.extra as Map<String, dynamic>?;
          return _slideTransition(
            WaitingApprovalScreen(visitData: visitData), state,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.checkedIn,
        name: 'checked-in',
        pageBuilder: (context, state) {
          final visitData = state.extra as Map<String, dynamic>?;
          return _fadeScaleTransition(
            CheckedInScreen(visitData: visitData), state,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.accessDenied,
        name: 'access-denied',
        pageBuilder: (context, state) {
          final visitData = state.extra as Map<String, dynamic>?;
          return _fadeScaleTransition(
            AccessDeniedScreen(visitData: visitData), state,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.activeVisit,
        name: 'active-visit',
        pageBuilder: (context, state) {
          final visitData = state.extra as Map<String, dynamic>?;
          return _fadeScaleTransition(
            ActiveVisitScreen(visitData: visitData), state,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.checkout,
        name: 'checkout',
        pageBuilder: (context, state) {
          final visitData = state.extra as Map<String, dynamic>?;
          return _slideTransition(
            CheckoutScreen(visitData: visitData), state,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.visitCompleted,
        name: 'visit-completed',
        pageBuilder: (context, state) {
          final visitData = state.extra as Map<String, dynamic>?;
          return _fadeScaleTransition(
            VisitCompletedScreen(visitData: visitData), state,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Página no encontrada',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(state.uri.toString()),
          ],
        ),
      ),
    ),
  );
});
