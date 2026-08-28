import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/data/journey_repository.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/journey_timeline.dart';

/// Visit Completed Screen — Shows final summary with journey timeline.
class VisitCompletedScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? visitData;

  const VisitCompletedScreen({super.key, this.visitData});

  @override
  ConsumerState<VisitCompletedScreen> createState() =>
      _VisitCompletedScreenState();
}

class _VisitCompletedScreenState extends ConsumerState<VisitCompletedScreen> {
  List<Map<String, dynamic>> _journeyEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJourney();
  }

  Future<void> _loadJourney() async {
    final visitId = widget.visitData?['id'] as String?;
    if (visitId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final journeyRepo = ref.read(journeyRepositoryProvider);
      final events = await journeyRepo.getJourney(visitId);
      if (mounted) {
        setState(() {
          _journeyEvents = events;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitor = widget.visitData?['visitors'] as Map<String, dynamic>? ?? {};
    final firstName = visitor['first_name'] ?? 'Visitante';
    final checkedInAt = widget.visitData?['checked_in_at'] as String?;
    final now = DateTime.now();

    // Calculate duration
    String durationText = '';
    if (checkedInAt != null) {
      final start = DateTime.parse(checkedInAt);
      final duration = now.difference(start);
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      durationText = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
    }

    final timeFormat = DateFormat('HH:mm');

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
                  const SizedBox(height: 16),
                  // Success icon — green for success, NEVER orange
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: KigoTheme.green100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 48,
                      color: KigoTheme.green600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Visita completada',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: KigoTheme.slate900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gracias, $firstName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: KigoTheme.slate500,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Duration summary card
                  Container(
                    decoration: BoxDecoration(
                      color: KigoTheme.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: KigoTheme.umbral200),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (checkedInAt != null)
                          _SummaryItem(
                            label: 'Entrada',
                            value: timeFormat
                                .format(DateTime.parse(checkedInAt).toLocal()),
                          ),
                        _SummaryItem(
                          label: 'Salida',
                          value: timeFormat.format(now),
                        ),
                        if (durationText.isNotEmpty)
                          _SummaryItem(
                            label: 'Duración',
                            value: durationText,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Journey section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recorrido de visita',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: KigoTheme.slate900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: KigoTheme.kigo500,
                              ),
                            )
                          : SingleChildScrollView(
                              child: JourneyTimeline(events: _journeyEvents),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // Return to welcome
            Padding(
              padding: const EdgeInsets.all(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: KigoTheme.orangeGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: MaterialButton(
                  onPressed: () => context.go('/'),
                  height: 46,
                  minWidth: double.infinity,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Finalizar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: KigoTheme.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: KigoTheme.slate900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: KigoTheme.gray400,
          ),
        ),
      ],
    );
  }
}
