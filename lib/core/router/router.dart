import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/welcome/presentation/welcome_screen.dart';
import '../../features/visits/presentation/visit_lookup_screen.dart';
import '../../features/visits/presentation/visit_found_screen.dart';
import '../../features/visits/presentation/visitor_registration_screen.dart';
import '../../features/visits/presentation/purpose_screen.dart';
import '../../features/visits/presentation/kiosk_identity_screen.dart';
import '../../features/visits/presentation/kiosk_context_screen.dart';
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
import '../../features/console/presentation/console_login_screen.dart';
import '../../features/console/presentation/console_shell.dart';
import '../../features/console/presentation/dashboard_screen.dart';
import '../../features/console/presentation/visits_screen.dart';
import '../../features/console/presentation/visit_detail_screen.dart';

/// Kigo motion: slide forward 300ms, back 250ms — smooth cubic
CustomTransitionPage<void> _slideTransition(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Forward: new screen slides in from right
      final slideIn = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeInOutCubic));
      // Outgoing: current screen slides slightly left + fades
      final slideOut = Tween(begin: Offset.zero, end: const Offset(-0.3, 0.0))
          .chain(CurveTween(curve: Curves.easeInOutCubic));
      final fadeOut = Tween(begin: 1.0, end: 0.5)
          .chain(CurveTween(curve: Curves.easeIn));

      return Stack(
        children: [
          // Outgoing screen
          SlideTransition(
            position: secondaryAnimation.drive(slideOut),
            child: FadeTransition(
              opacity: secondaryAnimation.drive(fadeOut),
              child: child,
            ),
          ),
          // Incoming screen
          SlideTransition(
            position: animation.drive(slideIn),
            child: child,
          ),
        ],
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

  // Console routes (Admin/Host experience)
  static const String consoleLogin = '/console/login';
  static const String consoleDashboard = '/console';
  static const String consoleVisits = '/console/visits';
  static const String consoleVisitDetail = '/console/visits/:id';
}

/// Router provider — single instance shared across the app.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RoutePaths.welcome,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
      final isConsoleRoute = state.uri.path.startsWith('/console');
      final isLoginRoute = state.uri.path == '/console/login';

      // If going to console (not login) and not authenticated → redirect to login
      if (isConsoleRoute && !isLoginRoute && !isLoggedIn) {
        return '/console/login';
      }

      // If on login page and already authenticated → go to dashboard
      if (isLoginRoute && isLoggedIn) {
        return '/console';
      }

      return null;
    },
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
          const PurposeScreen(), state,
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
      // === CONSOLE ROUTES (Admin/Host) ===
      GoRoute(
        path: RoutePaths.consoleLogin,
        name: 'console-login',
        builder: (context, state) => const ConsoleLoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ConsoleShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.consoleDashboard,
            name: 'console-dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: RoutePaths.consoleVisits,
            name: 'console-visits',
            builder: (context, state) => const VisitsScreen(),
          ),
          GoRoute(
            path: RoutePaths.consoleVisitDetail,
            name: 'console-visit-detail',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final data = state.extra as Map<String, dynamic>?;
              return VisitDetailScreen(visitId: id, initialData: data);
            },
          ),
        ],
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
