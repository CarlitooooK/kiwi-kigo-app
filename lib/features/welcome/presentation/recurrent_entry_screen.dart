import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env_config.dart';
import '../../../core/services/f10_door_service.dart';
import '../../../core/services/kigo_host_notifier.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/kigo_camera_overlay.dart';
import '../../trust/data/face_recognition_service.dart';

/// "Ya vengo seguido" — face fast-path for enrolled/recurrent visitors.
///
/// Single-capture (not a live camera): the visitor taps the button, the front
/// camera opens for ONE shot, we recognize the face on-device against enrolled
/// faces and branch:
///   • Recurrent  → open the door directly + notify host ("tu recurrente entró").
///   • Enrolled (not recurrent) → prefill data, continue the normal flow.
///   • Not recognized → gentle message, continue as a normal visit.
///
/// The face is NEVER the sole key for a stranger: only visitors the HOST marked
/// recurrent (after a real, authorized visit + checkout) get direct entry.
class RecurrentEntryScreen extends ConsumerStatefulWidget {
  const RecurrentEntryScreen({super.key});

  @override
  ConsumerState<RecurrentEntryScreen> createState() =>
      _RecurrentEntryScreenState();
}

class _RecurrentEntryScreenState extends ConsumerState<RecurrentEntryScreen> {
  bool _processing = false;
  String _status = 'Toca para reconocerte con tu rostro';
  bool _granted = false;

  Future<void> _startCapture() async {
    if (_processing) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.black,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height,
        child: KigoCameraOverlay(
          useFrontCamera: true,
          onCapture: (image) async {
            Navigator.pop(ctx);
            await _recognize(image.path);
          },
        ),
      ),
    );
  }

  Future<void> _recognize(String path) async {
    setState(() {
      _processing = true;
      _status = 'Reconociendo tu rostro…';
    });
    try {
      final match =
          await ref.read(faceRecognitionServiceProvider).recognize(path);

      if (!mounted) return;

      if (match == null) {
        // Not recognized → normal visit.
        setState(() {
          _processing = false;
          _status = 'No te reconocimos. Continúa con el registro normal.';
        });
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) context.pushReplacement('/kiosk/purpose');
        return;
      }

      final visitor = match.visitor ?? {};
      final firstName = visitor['first_name'] as String? ?? '';

      if (match.isRecurrent) {
        await _grantRecurrentAccess(visitor);
      } else {
        // Enrolled but not recurrent → prefill and continue normal flow.
        setState(() {
          _processing = false;
          _status = 'Hola de nuevo, $firstName. Prellenamos tus datos.';
        });
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        context.pushReplacement('/kiosk/purpose', extra: {
          'first_name': visitor['first_name'],
          'last_name': visitor['last_name'],
          'visitor_type': visitor['visitor_type'],
          'phone': visitor['phone'],
          '_prefill_from_face': true,
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = 'No se pudo reconocer. Intenta de nuevo o regístrate.';
      });
    }
  }

  /// Recurrent visitor: open the door directly and notify the host.
  Future<void> _grantRecurrentAccess(Map<String, dynamic> visitor) async {
    final firstName = visitor['first_name'] as String? ?? 'Visitante';
    setState(() {
      _granted = true;
      _status = 'Bienvenido de nuevo, $firstName. Abriendo…';
    });

    // Success feedback: sound + LED + relay.
    ref.read(soundServiceProvider).playSuccess();
    final door = ref.read(f10DoorServiceProvider);
    await door.setLedColor(F10LedColor.green, brightness: 200);
    await door.openDoor(hold: const Duration(seconds: 5));
    Future.delayed(const Duration(seconds: 5), () => door.ledOff());

    // Notify the host that their recurrent visitor entered (best-effort).
    final visitorName =
        '${visitor['first_name'] ?? ''} ${visitor['last_name'] ?? ''}'.trim();
    // Log a lightweight journey note if we have a recent visit; otherwise skip.
    try {
      await ref.read(kigoHostNotifierProvider).notifyVisitorWaiting(
            hostLegacyUserId: EnvConfig.testHostLegacyUserId,
            visitorName: '$visitorName (recurrente)',
            visitId: '',
            purpose: 'Entrada por rostro',
          );
    } catch (_) {}

    await Future.delayed(const Duration(seconds: 4));
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
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
                  onTap: () => context.pop(),
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
              Center(
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: (_granted ? KigoTheme.green600 : KigoTheme.kigo500)
                        .withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (_granted ? KigoTheme.green600 : KigoTheme.kigo500)
                          .withValues(alpha: 0.4),
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    _granted ? Icons.check_rounded : Icons.face_retouching_natural,
                    size: 64,
                    color: _granted ? KigoTheme.green600 : KigoTheme.kigo500,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Soy visitante frecuente',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: KigoTheme.slate900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _status,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: KigoTheme.slate500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              // Tip: better face scan when the face is unobstructed.
              if (!_processing && !_granted) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: KigoTheme.umbral100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: KigoTheme.umbral200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined,
                          size: 20, color: KigoTheme.kigo500),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Para un mejor reconocimiento, retira lentes de sol, '
                          'gorras o accesorios muy vistosos que cubran tu rostro.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: KigoTheme.slate500,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(flex: 3),
              if (!_processing && !_granted)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KigoTheme.orangeGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: MaterialButton(
                    onPressed: _startCapture,
                    height: 52,
                    minWidth: double.infinity,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Reconocerme',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: KigoTheme.kigo500),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
