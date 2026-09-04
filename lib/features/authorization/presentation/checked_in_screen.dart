import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/data/visit_repository.dart';
import '../../../core/data/journey_repository.dart';
import '../../../core/services/f10_door_service.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/theme/kigo_theme.dart';
import '../data/authorization_provider.dart';

/// Access Granted — kiosk success screen.
///
/// Design decision (shared kiosk): the F10 must NOT stay occupied tracking an
/// active visit — that would block the queue. So this screen:
///   1. Checks the visitor in + opens the F10 relay (physical access).
///   2. Shows a badge (name / host / area / time) and a QR the visitor scans
///      to follow their visit in the Kigo app.
///   3. Frees the kiosk on a manual "Listo" button (no auto-timeout, so the
///      visitor has time to scan the QR).
///
/// The active-visit timer, timeline and check-out now live in the Kigo host
/// mini-app, not on the kiosk. Success is green — never orange.
class CheckedInScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? visitData;

  const CheckedInScreen({super.key, this.visitData});

  @override
  ConsumerState<CheckedInScreen> createState() => _CheckedInScreenState();
}

class _CheckedInScreenState extends ConsumerState<CheckedInScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  bool _hasCheckedIn = false;
  bool _doorOpened = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _grantAccess());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _grantAccess() async {
    if (_hasCheckedIn) return;
    _hasCheckedIn = true;

    final visitId = widget.visitData?['id'] as String?;
    if (visitId == null) return;

    try {
      final visitRepo = ref.read(visitRepositoryProvider);
      final journeyRepo = ref.read(journeyRepositoryProvider);

      await visitRepo.checkIn(visitId);
      await journeyRepo.logEvent(visitId: visitId, eventType: 'CHECKED_IN');

      // Success cue: play the sound as soon as access is confirmed.
      ref.read(soundServiceProvider).playSuccess();

      // Physically open the F10 door relay (holds 5s, auto-closes).
      final door = await ref
          .read(f10DoorServiceProvider)
          .openDoor(hold: const Duration(seconds: 5));
      if (mounted) setState(() => _doorOpened = door.isOpened);

      // Light the F10 status LED as a visual "access granted" cue, matching
      // the relay hold. Brightness 200 is the sweet spot on the F10 (255 is
      // slightly harsh, 1 is too dim). Turns off after 5s (same as the relay).
      // Light the F10 LED GREEN as the visual "access granted" cue, matching
      // the relay hold. Green = authorized (per the F10 color LED). Turns off
      // after 5s (same as the relay).
      final doorService = ref.read(f10DoorServiceProvider);
      await doorService.setLedColor(F10LedColor.green, brightness: 200);
      Future.delayed(const Duration(seconds: 5), () => doorService.ledOff());
    } catch (_) {
      // Non-critical — the screen still shows success.
    }
  }

  /// Frees the kiosk for the next visitor. Full reset to welcome.
  void _finish() {
    // Make sure all LEDs are off for the next visitor.
    ref.read(f10DoorServiceProvider).ledOff();
    // Reset session-scoped state so the next visitor never sees this one's
    // data (PRD non-functional requirement: reset between sessions).
    ref.invalidate(authorizationProvider);
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final visitor = widget.visitData?['visitors'] as Map<String, dynamic>? ?? {};
    final host = widget.visitData?['profiles'] as Map<String, dynamic>? ?? {};
    final firstName = visitor['first_name'] ?? 'Visitante';
    final lastName = visitor['last_name'] ?? '';
    final hostName = host['full_name'] ?? '';
    final company = visitor['company'] ?? '';
    final area = widget.visitData?['area'] ?? '';
    final visitId = widget.visitData?['id'] as String? ?? '';

    // QR uses Kigo's real universal-link prefix so scanning it opens the Kigo
    // app (if installed). The `WELCOME:` marker lets the app route it to the
    // read-only visit view instead of the access-scan backend.
    final qrData = 'https://parkimovil.com/app?qr=WELCOME:$visitId';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                // Success mark (green, spring in)
                Center(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        color: KigoTheme.green100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded,
                          size: 52, color: KigoTheme.green600),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Acceso autorizado',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: KigoTheme.green600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _doorOpened ? 'La puerta está abierta, puedes pasar' : 'Puedes pasar',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: KigoTheme.slate500,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Visitor badge (gafete)
                Container(
                  decoration: BoxDecoration(
                    color: KigoTheme.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KigoTheme.umbral200),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const _BadgeHeader(),
                      const SizedBox(height: 16),
                      Text(
                        '$firstName $lastName'.trim(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: KigoTheme.slate900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (hostName.isNotEmpty)
                        _BadgeRow(
                            icon: Icons.person_outline,
                            label: 'Anfitrión',
                            value: hostName),
                      if (company.toString().isNotEmpty)
                        _BadgeRow(
                            icon: Icons.business_outlined,
                            label: 'Empresa',
                            value: company.toString()),
                      if (area.toString().isNotEmpty)
                        _BadgeRow(
                            icon: Icons.meeting_room_outlined,
                            label: 'Área',
                            value: area.toString()),
                      _BadgeRow(
                          icon: Icons.access_time,
                          label: 'Entrada',
                          value: _formatTime(DateTime.now())),

                      const SizedBox(height: 20),
                      const Divider(color: KigoTheme.umbral200, height: 1),
                      const SizedBox(height: 20),

                      // QR to follow the visit in the Kigo app.
                      if (visitId.isNotEmpty) ...[
                        QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 150,
                          backgroundColor: KigoTheme.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: KigoTheme.slate900,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: KigoTheme.slate900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Escanea para seguir tu visita en Kigo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: KigoTheme.gray500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Finish → free the kiosk for the next visitor (manual reset).
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KigoTheme.greenGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: MaterialButton(
                    onPressed: _finish,
                    height: 46,
                    minWidth: double.infinity,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Listo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: KigoTheme.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _BadgeHeader extends StatelessWidget {
  const _BadgeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/brand/logo.png',
          width: 26,
          height: 26,
          filterQuality: FilterQuality.medium,
        ),
        const SizedBox(width: 8),
        const Text(
          'Kigo Welcome',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: KigoTheme.kigo500,
          ),
        ),
      ],
    );
  }
}

class _BadgeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _BadgeRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: KigoTheme.slate500),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: KigoTheme.gray400,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: KigoTheme.slate900,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
