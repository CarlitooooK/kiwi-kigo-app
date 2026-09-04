import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/kiosk_service.dart';
import '../../../core/services/f10_nfc_service.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/support_button.dart';
import '../../authorization/data/authorization_provider.dart';

/// Welcome Screen — Kiosk entry point.
///
/// UX ANALYSIS — Welcome
/// User: Visitor arriving at kiosk for the first time in this session
/// Goal: Choose their path quickly (pre-registered or walk-in)
/// Emotional state: Neutral to slightly anxious — first impression
///
/// Visual hierarchy:
/// 1. Warm greeting (establishes trust)
/// 2. Primary CTA: "Tengo visita programada" (most common path)
/// 3. Secondary CTA: "Registrar visita" (walk-in)
///
/// Semantic CTA: Orange — intent, no money on screen
/// Removals: Removed "Identifícate para continuar" — redundant with button labels
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  // Demo host card: any card whose id matches this value grants fast-entry.
  // The value comes from the F10 reader's onSwipe callback (see F10NfcService).
  // Its format depends on the card/reader (may be decimal or hex) — read it
  // from the logs ("F10NfcService: card UID = ...") and paste it here.
  // Verified on-device: the demo host card reads as this UID (7-byte MIFARE/NTAG).
  static const String _demoHostCardUid = '046D8645C22A81';
  // Friendly name greeted on the fast-entry screen for the demo card.
  static const String _demoHostName = 'Anfitrión';

  StreamSubscription<String>? _nfcSub;
  bool _navigating = false; // guards against duplicate taps

  @override
  void initState() {
    super.initState();
    // Entering the idle screen re-arms kiosk (lock task) mode and resets any
    // leftover session state, so the next visitor never inherits the previous
    // one's data — no matter how the previous flow ended (success, denied,
    // cancelled, timeout). PRD non-functional requirement: reset between sessions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kioskServiceProvider).start();
      ref.invalidate(authorizationProvider);
    });

    // NFC is always listening on the Welcome screen. Keep ONE subscription for
    // the whole lifetime of this screen — do NOT cancel/re-subscribe, because
    // cancelling the broadcast stream tears down the native sink. We navigate
    // to the fast-entry screen with `go('/')` on return, which recreates this
    // Welcome (fresh initState → fresh subscription), so re-arming is automatic.
    _nfcSub = ref.read(f10NfcServiceProvider).cardStream.listen(
      _onCardTapped,
      onError: (_) {/* channel not ready (old APK) → NFC stays silent */},
    );
  }

  @override
  void dispose() {
    _nfcSub?.cancel();
    super.dispose();
  }

  void _onCardTapped(String uid) {
    if (_navigating || !mounted) return;
    // Demo: only the defined card grants access. Unknown cards are ignored.
    if (uid.toUpperCase() != _demoHostCardUid.toUpperCase()) return;
    _navigating = true;
    context.push('/host-entry', extra: _demoHostName);
    // Self-heal the guard: whether we return via go('/') (Welcome reused) or a
    // fresh rebuild, clearing the flag after a moment re-arms fast-entry for the
    // next tap. The fast-entry screen stays ~5s, so this never double-fires.
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) _navigating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Kigo brand mark (project logo)
              Image.asset(
                'assets/brand/logo.png',
                width: 84,
                height: 84,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(height: 28),

              // Title — 700 weight, hero anchor
              Text(
                'Bienvenido',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: KigoTheme.slate900,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle — 400 weight, supporting
              Text(
                'Kigo Welcome',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: KigoTheme.kigo500,
                ),
              ),

              const Spacer(flex: 2),

              // Primary CTA — orange gradient
              _KigoCTA(
                label: 'Tengo una visita programada',
                onPressed: () => context.push('/visit-lookup'),
              ),
              const SizedBox(height: 12),

              // Voice-guided registration — lower friction, AI-assisted
              OutlinedButton.icon(
                onPressed: () => context.push('/kiosk/voice'),
                icon: const Icon(Icons.mic_rounded, size: 20),
                label: const Text('Registrarme por voz'),
              ),
              const SizedBox(height: 12),

              // Recurrent / face fast-path — enrolled visitors enter with their face
              OutlinedButton.icon(
                onPressed: () => context.push('/recurrent'),
                icon: const Icon(Icons.face_retouching_natural, size: 20),
                label: const Text('Soy visitante frecuente'),
              ),
              const SizedBox(height: 12),

              // Secondary action — new registration (guided touch flow)
              TextButton(
                onPressed: () => context.push('/kiosk/purpose'),
                child: const Text('Prefiero escribir'),
              ),

              const Spacer(flex: 3),

              // Support — visitor can scan a QR to call support.
              const SupportButton(),
              const SizedBox(height: 4),

              // Footer
              Text(
                'Kigo Welcome Intelligence',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: KigoTheme.gray400,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kigo primary CTA button with orange gradient.
/// Height: 46px fixed. Width: 100%. Border-radius: 14px.
class _KigoCTA extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _KigoCTA({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: KigoTheme.orangeGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
