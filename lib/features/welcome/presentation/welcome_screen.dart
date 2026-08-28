import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kigo_theme.dart';

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
/// 4. Console access (staff only, nearly invisible)
///
/// Semantic CTA: Orange — intent, no money on screen
/// Removals: Removed "Identifícate para continuar" — redundant with button labels
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Kigo brand mark
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: KigoTheme.kigo500.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.waving_hand_rounded,
                  size: 36,
                  color: KigoTheme.kigo500,
                ),
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
                label: 'Tengo visita programada',
                onPressed: () => context.push('/visit-lookup'),
              ),
              const SizedBox(height: 12),

              // Secondary action — new registration (guided flow)
              OutlinedButton(
                onPressed: () => context.push('/kiosk/purpose'),
                child: const Text('Registrar visita'),
              ),

              const Spacer(flex: 3),

              // Footer — console access for staff
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Kigo Welcome Intelligence',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: KigoTheme.gray400,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.push('/console/login'),
                    child: Text(
                      'Consola',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: KigoTheme.gray400,
                      ),
                    ),
                  ),
                ],
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
