import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/visit_repository.dart';
import '../../../core/data/journey_repository.dart';
import '../../../core/theme/kigo_theme.dart';

/// Access Granted / Checked-In Screen.
///
/// Success uses green600 — NEVER orange.
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performCheckIn();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _performCheckIn() async {
    if (_hasCheckedIn) return;
    _hasCheckedIn = true;

    final visitId = widget.visitData?['id'] as String?;
    if (visitId == null) return;

    try {
      final visitRepo = ref.read(visitRepositoryProvider);
      final journeyRepo = ref.read(journeyRepositoryProvider);

      await visitRepo.checkIn(visitId);
      await journeyRepo.logEvent(
        visitId: visitId,
        eventType: 'CHECKED_IN',
      );
    } catch (_) {
      // Non-critical — the screen still shows success
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitor = widget.visitData?['visitors'] as Map<String, dynamic>? ?? {};
    final host = widget.visitData?['profiles'] as Map<String, dynamic>? ?? {};
    final firstName = visitor['first_name'] ?? 'Visitante';
    final hostName = host['full_name'] ?? '';
    final area = widget.visitData?['area'] ?? '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // Back from checked-in goes to welcome (reset kiosk)
          context.go('/');
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const Spacer(flex: 2),

              // Success animation
              Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: KigoTheme.green100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 64,
                      color: KigoTheme.green600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Title — success uses green600
              const Text(
                'Acceso autorizado',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: KigoTheme.green600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Bienvenido, $firstName',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: KigoTheme.slate500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Visit info card
              Container(
                decoration: BoxDecoration(
                  color: KigoTheme.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: KigoTheme.umbral200),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hostName.isNotEmpty)
                      _InfoRow(
                        icon: Icons.person_outline,
                        label: 'Anfitrión',
                        value: hostName,
                      ),
                    if (area.isNotEmpty)
                      _InfoRow(
                        icon: Icons.meeting_room_outlined,
                        label: 'Área',
                        value: area,
                      ),
                    _InfoRow(
                      icon: Icons.access_time,
                      label: 'Check-in',
                      value: _formatTime(DateTime.now()),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Continue to active visit — green gradient for success
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: KigoTheme.greenGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: MaterialButton(
                  onPressed: () {
                    context.pushReplacement('/active-visit',
                        extra: widget.visitData);
                  },
                  height: 46,
                  minWidth: double.infinity,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: KigoTheme.white,
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: KigoTheme.slate500),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: KigoTheme.gray400,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: KigoTheme.slate900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
