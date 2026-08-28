import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/journey_repository.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/journey_timeline.dart';

/// Active Visit Screen — Shows the visit in progress.
class ActiveVisitScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? visitData;

  const ActiveVisitScreen({super.key, this.visitData});

  @override
  ConsumerState<ActiveVisitScreen> createState() => _ActiveVisitScreenState();
}

class _ActiveVisitScreenState extends ConsumerState<ActiveVisitScreen> {
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;
  DateTime? _checkInTime;
  List<Map<String, dynamic>> _journeyEvents = [];

  @override
  void initState() {
    super.initState();
    _initCheckInTime();
    _startDurationTimer();
    _loadJourney();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  void _initCheckInTime() {
    final checkedInAt = widget.visitData?['checked_in_at'] as String?;
    if (checkedInAt != null) {
      _checkInTime = DateTime.parse(checkedInAt);
    } else {
      _checkInTime = DateTime.now();
    }
    _elapsed = DateTime.now().difference(_checkInTime!);
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(_checkInTime!);
      });
    });
  }

  Future<void> _loadJourney() async {
    final visitId = widget.visitData?['id'] as String?;
    if (visitId == null) return;

    try {
      final journeyRepo = ref.read(journeyRepositoryProvider);
      final events = await journeyRepo.getJourney(visitId);
      if (mounted) {
        setState(() => _journeyEvents = events);
      }
    } catch (_) {}
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final visitor = widget.visitData?['visitors'] as Map<String, dynamic>? ?? {};
    final host = widget.visitData?['profiles'] as Map<String, dynamic>? ?? {};
    final firstName = visitor['first_name'] ?? 'Visitante';
    final lastName = visitor['last_name'] ?? '';
    final hostName = host['full_name'] ?? '';
    final area = widget.visitData?['area'] ?? '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Active badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: KigoTheme.green100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: KigoTheme.green600.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: KigoTheme.green600,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'VISITA ACTIVA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: KigoTheme.green600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Visitor name
                  Text(
                    '$firstName $lastName',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: KigoTheme.slate900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Duration counter
                  Text(
                    _formatDuration(_elapsed),
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w300,
                      color: KigoTheme.kigo500,
                    ),
                  ),
                  const Text(
                    'Duración',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: KigoTheme.gray500,
                    ),
                  ),
                ],
              ),
            ),

            // Info card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: KigoTheme.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: KigoTheme.umbral200),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (hostName.isNotEmpty)
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.person_outline,
                          label: 'Anfitrión',
                          value: hostName,
                        ),
                      ),
                    if (area.isNotEmpty) ...[
                      if (hostName.isNotEmpty)
                        Container(
                          width: 1,
                          height: 40,
                          color: KigoTheme.umbral200,
                        ),
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.meeting_room_outlined,
                          label: 'Área',
                          value: area,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Journey timeline
            if (_journeyEvents.isNotEmpty)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recorrido',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: KigoTheme.slate900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: JourneyTimeline(events: _journeyEvents),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const Expanded(child: SizedBox()),

            // Actions
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Contact host
                  if (hostName.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Notificación enviada a $hostName'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('Contactar anfitrión'),
                    ),
                  if (hostName.isNotEmpty) const SizedBox(height: 12),

                  // Check out — primary CTA
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: KigoTheme.orangeGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: MaterialButton(
                      onPressed: () {
                        context.push('/checkout', extra: widget.visitData);
                      },
                      height: 46,
                      minWidth: double.infinity,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: KigoTheme.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Finalizar visita',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: KigoTheme.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: KigoTheme.slate500),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: KigoTheme.gray400,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: KigoTheme.slate900,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
