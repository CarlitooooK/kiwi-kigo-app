import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/kigo_theme.dart';

/// Journey Timeline Widget — Reusable timeline for visitor journey events.
///
/// Used in:
/// - Active Visit screen (kiosk)
/// - Visit detail in console
/// - Visit completed screen
class JourneyTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const JourneyTimeline({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Text(
          'Sin eventos registrados',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: KigoTheme.gray500,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isLast = index == events.length - 1;
        final isFirst = index == 0;
        return _TimelineItem(
          event: event,
          isFirst: isFirst,
          isLast: isLast,
        );
      },
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isFirst;
  final bool isLast;

  const _TimelineItem({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final eventType = event['event_type'] as String? ?? '';
    final createdAt = event['created_at'] as String?;
    final time = createdAt != null
        ? DateFormat('HH:mm').format(DateTime.parse(createdAt).toLocal())
        : '--:--';

    final config = _getEventConfig(eventType);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 48,
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: KigoTheme.gray500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),

          // Timeline line + dot
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // Top connector
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 8,
                    color: KigoTheme.umbral200,
                  ),
                // Dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: config.color,
                    shape: BoxShape.circle,
                  ),
                ),
                // Bottom connector
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: KigoTheme.umbral200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Icon(config.icon, size: 16, color: config.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      config.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
                        color: KigoTheme.slate900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _EventConfig _getEventConfig(String eventType) {
    switch (eventType) {
      case 'VISIT_CREATED':
        return _EventConfig(
          label: 'Visita creada',
          icon: Icons.add_circle_outline,
          color: KigoTheme.sky900,
        );
      case 'VISITOR_ARRIVED':
        return _EventConfig(
          label: 'Visitante llegó',
          icon: Icons.login_rounded,
          color: KigoTheme.sky900,
        );
      case 'IDENTITY_VALIDATED':
        return _EventConfig(
          label: 'Identidad validada',
          icon: Icons.badge_outlined,
          color: KigoTheme.kigo500,
        );
      case 'EVIDENCE_PROCESSED':
        return _EventConfig(
          label: 'Evidencia procesada',
          icon: Icons.fact_check_outlined,
          color: KigoTheme.kigo500,
        );
      case 'TRUST_EVALUATED':
        return _EventConfig(
          label: 'Evaluación completada',
          icon: Icons.analytics_outlined,
          color: KigoTheme.kigo500,
        );
      case 'ACCESS_REQUESTED':
        return _EventConfig(
          label: 'Acceso solicitado',
          icon: Icons.lock_open_outlined,
          color: KigoTheme.yellow400,
        );
      case 'HOST_NOTIFIED':
        return _EventConfig(
          label: 'Anfitrión notificado',
          icon: Icons.notifications_outlined,
          color: KigoTheme.yellow400,
        );
      case 'HOST_APPROVED':
        return _EventConfig(
          label: 'Autorizado por anfitrión',
          icon: Icons.thumb_up_outlined,
          color: KigoTheme.green600,
        );
      case 'HOST_REJECTED':
        return _EventConfig(
          label: 'Rechazado por anfitrión',
          icon: Icons.thumb_down_outlined,
          color: KigoTheme.red500,
        );
      case 'AUTO_AUTHORIZED':
        return _EventConfig(
          label: 'Autorizado automáticamente',
          icon: Icons.verified_outlined,
          color: KigoTheme.green600,
        );
      case 'CHECKED_IN':
        return _EventConfig(
          label: 'Check-in',
          icon: Icons.check_circle_outline,
          color: KigoTheme.green600,
        );
      case 'CHECKED_OUT':
        return _EventConfig(
          label: 'Check-out',
          icon: Icons.logout_rounded,
          color: KigoTheme.sky900,
        );
      case 'ESCALATED':
        return _EventConfig(
          label: 'Escalado',
          icon: Icons.escalator_warning,
          color: KigoTheme.yellow400,
        );
      default:
        return _EventConfig(
          label: eventType,
          icon: Icons.circle_outlined,
          color: KigoTheme.gray400,
        );
    }
  }
}

class _EventConfig {
  final String label;
  final IconData icon;
  final Color color;

  const _EventConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
}
