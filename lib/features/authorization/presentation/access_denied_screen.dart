import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/services/f10_door_service.dart';
import '../../../core/theme/kigo_theme.dart';

/// Access Denied Screen — Shown when host rejects or policy denies.
///
/// IMPORTANT: Do NOT use aggressive language or make the visitor feel criminal.
class AccessDeniedScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? visitData;

  const AccessDeniedScreen({super.key, this.visitData});

  @override
  ConsumerState<AccessDeniedScreen> createState() => _AccessDeniedScreenState();
}

class _AccessDeniedScreenState extends ConsumerState<AccessDeniedScreen> {
  @override
  void initState() {
    super.initState();
    // Error cue + RED LED when the denial screen appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(soundServiceProvider).playError();
      ref.read(f10DoorServiceProvider).setLedColor(F10LedColor.red, brightness: 200);
    });
  }

  @override
  void dispose() {
    // Turn the LED off when leaving the denial screen.
    ref.read(f10DoorServiceProvider).ledOff();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hostName =
        (widget.visitData?['profiles'] as Map<String, dynamic>?)?['full_name'] ?? '';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Icon — uses red for denied, but not aggressive
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: KigoTheme.red100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    size: 40,
                    color: KigoTheme.red500,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Title — neutral, not aggressive
              const Text(
                'Visita no autorizada',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: KigoTheme.slate900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Explanation
              const Text(
                'En este momento tu visita no ha sido autorizada.\n\n'
                'Esto puede deberse a que tu anfitrión no está disponible '
                'o que la visita no pudo ser confirmada.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: KigoTheme.slate500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Suggestion card
              Container(
                decoration: BoxDecoration(
                  color: KigoTheme.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: KigoTheme.umbral200),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿Qué puedes hacer?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: KigoTheme.slate900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _SuggestionRow(
                      icon: Icons.support_agent,
                      text: 'Acude a recepción para asistencia',
                    ),
                    if (hostName.isNotEmpty)
                      _SuggestionRow(
                        icon: Icons.phone_outlined,
                        text: 'Contacta directamente a $hostName',
                      ),
                    const _SuggestionRow(
                      icon: Icons.schedule,
                      text: 'Intenta nuevamente más tarde',
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Contact reception
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Se ha notificado a recepción'),
                    ),
                  );
                },
                icon: const Icon(Icons.support_agent, size: 18),
                label: const Text('Contactar recepción'),
              ),
              const SizedBox(height: 12),

              // Return to welcome
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text(
                  'Volver al inicio',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: KigoTheme.gray500,
                  ),
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SuggestionRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: KigoTheme.slate500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: KigoTheme.slate900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
