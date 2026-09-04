import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/visit_repository.dart';
import '../../../core/data/journey_repository.dart';
import '../../../core/config/env_config.dart';
import '../../../core/utils/simulated_data.dart';
import '../../../core/theme/kigo_theme.dart';
import '../application/voice_registration_controller.dart';
import '../application/voice_registration_state.dart';

/// Voice-guided registration screen.
///
/// The AI speaks, listens and fills the fields; touch fallback ("Escribir en su
/// lugar") is always available. On confirmation it creates the visitor + visit
/// (same repositories as the touch flow) and continues to consent.
class VoiceRegistrationScreen extends ConsumerStatefulWidget {
  const VoiceRegistrationScreen({super.key});

  @override
  ConsumerState<VoiceRegistrationScreen> createState() =>
      _VoiceRegistrationScreenState();
}

class _VoiceRegistrationScreenState
    extends ConsumerState<VoiceRegistrationScreen> {
  static const _orgId = 'a0000000-0000-0000-0000-000000000001';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceRegistrationControllerProvider.notifier).start();
    });
  }

  Future<void> _submitAndContinue(VoiceRegistrationState s) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final visitRepo = ref.read(visitRepositoryProvider);
      final journeyRepo = ref.read(journeyRepositoryProvider);

      final visitor = await visitRepo.createVisitor(
        firstName: s.firstName ?? '',
        lastName: s.lastName ?? '',
        organizationId: _orgId,
        // Company is simulated (always Kigo); phone is REAL (needed for
        // WhatsApp). Email is intentionally dropped — never asked or stored.
        company: SimulatedData.company,
        phone: (s.phone ?? '').isNotEmpty ? s.phone : null,
        visitorType: s.visitorType ?? 'VISITOR',
      );
      final visit = await visitRepo.createVisit(
        visitorId: visitor['id'],
        organizationId: _orgId,
        purpose: (s.detail ?? '').isNotEmpty ? s.detail : null,
        // Destination area is simulated for the demo.
        area: SimulatedData.randomArea(),
        source: 'KIOSK',
      );
      await journeyRepo.logEvent(
        visitId: visit['id'],
        eventType: 'VISIT_CREATED',
        payload: {
          'source': 'KIOSK',
          'channel': 'VOICE',
          'visitor_type': s.visitorType,
          'host_name_manual': (s.hostName ?? '').isNotEmpty ? s.hostName : null,
          // Kigo identity of the host this visit is addressed to. For the demo
          // it is the fixed test user; in production it comes from a host
          // directory picker. The Kigo mini-app compares this against
          // kigo.auth.init().userId to confirm the viewer is the right host.
          'host_kigo_user_id': EnvConfig.testHostLegacyUserId,
        },
      );

      if (!mounted) return;
      context.push('/consent', extra: {...visit, 'visitors': visitor});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No pudimos registrar tu visita. Continúa con la pantalla.'),
            backgroundColor: KigoTheme.red500,
          ),
        );
        setState(() => _submitting = false);
      }
    }
  }

  void _goTouch() {
    ref.read(voiceRegistrationControllerProvider.notifier).cancel();
    context.pushReplacement('/kiosk/purpose');
  }

  /// Visitor said the data was wrong: hand off to the touch form with
  /// everything captured prefilled, starting at the name step so they can fix
  /// any field and continue.
  void _goCorrect() {
    final notifier = ref.read(voiceRegistrationControllerProvider.notifier);
    final data = notifier.toFlowData();
    notifier.cancel();
    context.pushReplacement('/kiosk/identity', extra: data);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VoiceRegistrationState>(voiceRegistrationControllerProvider,
        (prev, next) {
      if (next.step == VoiceStep.done && !_submitting) {
        _submitAndContinue(next);
      } else if (next.step == VoiceStep.correct && !_submitting) {
        _goCorrect();
      }
    });

    final s = ref.watch(voiceRegistrationControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    ref.read(voiceRegistrationControllerProvider.notifier).cancel();
                    context.pop();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: KigoTheme.umbral100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: KigoTheme.slate900),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Animated mic / speaking indicator
              Center(child: _VoiceOrb(listening: s.listening, speaking: s.speaking)),
              const SizedBox(height: 32),

              // Current prompt (what the assistant is asking)
              Text(
                s.prompt.isEmpty ? 'Preparando asistente de voz' : s.prompt,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: KigoTheme.slate900,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // What we heard
              if (s.heardText != null && s.heardText!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: KigoTheme.umbral100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '"${s.heardText!}"',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: KigoTheme.slate500,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 12),
              _StatusLine(state: s),

              const Spacer(flex: 3),

              if (_submitting)
                const Center(
                  child: CircularProgressIndicator(color: KigoTheme.kigo500),
                )
              else ...[
                // Touch fallback — always available (PRD requirement).
                OutlinedButton.icon(
                  onPressed: _goTouch,
                  icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                  label: Text(s.step == VoiceStep.fallback
                      ? 'Continuar con la pantalla'
                      : 'Prefiero escribir'),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final VoiceRegistrationState state;
  const _StatusLine({required this.state});

  @override
  Widget build(BuildContext context) {
    String label;
    if (state.speaking) {
      label = 'Hablando';
    } else if (state.listening) {
      label = 'Escuchando';
    } else if (state.step == VoiceStep.submitting) {
      label = 'Registrando';
    } else {
      label = '';
    }
    if (label.isEmpty) return const SizedBox(height: 18);
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: KigoTheme.kigo500,
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Pulsing orb: orange while speaking, green ring while listening.
class _VoiceOrb extends StatefulWidget {
  final bool listening;
  final bool speaking;
  const _VoiceOrb({required this.listening, required this.speaking});

  @override
  State<_VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<_VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.listening || widget.speaking;
    final color = widget.listening ? KigoTheme.green600 : KigoTheme.kigo500;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final scale = active ? 1.0 + (_c.value * 0.12) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.10),
              border: Border.all(color: color.withValues(alpha: 0.5), width: 3),
            ),
            child: Icon(
              widget.listening ? Icons.mic_rounded : Icons.record_voice_over_rounded,
              size: 52,
              color: color,
            ),
          ),
        );
      },
    );
  }
}
