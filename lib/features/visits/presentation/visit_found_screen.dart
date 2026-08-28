import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/kigo_theme.dart';

/// Visit Found Screen — Shows pre-registered visit details.
///
/// The visitor was found in the system. Confirm and continue.
class VisitFoundScreen extends StatelessWidget {
  final Map<String, dynamic> visitData;

  const VisitFoundScreen({super.key, required this.visitData});

  @override
  Widget build(BuildContext context) {
    // Extract data
    final visitor = visitData['visitors'] as Map<String, dynamic>? ?? {};
    final host = visitData['profiles'] as Map<String, dynamic>? ?? {};
    final firstName = visitor['first_name'] ?? '';
    final company = visitor['company'] ?? '';
    final hostName = host['full_name'] ?? 'No asignado';
    final purpose = visitData['purpose'] ?? '';
    final area = visitData['area'] ?? '';
    final scheduledStart = visitData['scheduled_start'];
    final scheduledEnd = visitData['scheduled_end'];
    final isPreauthorized = visitData['is_preauthorized'] == true;

    // Format schedule
    String scheduleText = '';
    if (scheduledStart != null) {
      final start = DateTime.parse(scheduledStart);
      final timeFormat = DateFormat('HH:mm');
      scheduleText = timeFormat.format(start);
      if (scheduledEnd != null) {
        final end = DateTime.parse(scheduledEnd);
        scheduleText += ' — ${timeFormat.format(end)}';
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // Back button
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
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: KigoTheme.slate900,
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Success icon
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: KigoTheme.green100,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 40,
                    color: KigoTheme.green600,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Greeting
              Text(
                'Bienvenido, $firstName',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: KigoTheme.slate900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Encontramos una visita programada para ti',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: KigoTheme.slate500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Visit details card
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
                    if (company.isNotEmpty)
                      _DetailRow(
                        icon: Icons.business,
                        label: 'Empresa',
                        value: company,
                      ),
                    _DetailRow(
                      icon: Icons.person_outline,
                      label: 'Anfitrión',
                      value: hostName,
                    ),
                    if (purpose.isNotEmpty)
                      _DetailRow(
                        icon: Icons.description_outlined,
                        label: 'Motivo',
                        value: purpose,
                      ),
                    if (area.isNotEmpty)
                      _DetailRow(
                        icon: Icons.meeting_room_outlined,
                        label: 'Área',
                        value: area,
                      ),
                    if (scheduleText.isNotEmpty)
                      _DetailRow(
                        icon: Icons.schedule,
                        label: 'Horario',
                        value: scheduleText,
                      ),
                    if (isPreauthorized)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: KigoTheme.green100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 16, color: KigoTheme.green600),
                              SizedBox(width: 6),
                              Text(
                                'Pre-autorizado',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: KigoTheme.green600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Continue button — primary CTA with gradient
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: KigoTheme.orangeGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: MaterialButton(
                  onPressed: () {
                    context.push('/consent', extra: visitData);
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
              const SizedBox(height: 12),

              // Escape hatch
              TextButton(
                onPressed: () => context.pop(),
                child: const Text(
                  'Esta no es mi visita',
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
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
