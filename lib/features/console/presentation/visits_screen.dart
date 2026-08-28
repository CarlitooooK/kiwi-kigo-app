import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/data/visit_repository.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/kigo_error.dart';
import '../../../shared/widgets/kigo_empty.dart';

/// Visit filter options.
enum VisitFilter { all, active, pending, completed, rejected }

/// Provider for the current filter.
final visitFilterProvider = StateProvider<VisitFilter>((ref) => VisitFilter.all);

/// Provider for visits list based on current filter.
final consoleVisitsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final visitRepo = ref.watch(visitRepositoryProvider);
  final filter = ref.watch(visitFilterProvider);

  String? statusFilter;
  switch (filter) {
    case VisitFilter.active:
      statusFilter = 'ACTIVE';
      break;
    case VisitFilter.pending:
      statusFilter = 'IN_PROGRESS';
      break;
    case VisitFilter.completed:
      statusFilter = 'COMPLETED';
      break;
    case VisitFilter.rejected:
      statusFilter = 'REJECTED';
      break;
    case VisitFilter.all:
      statusFilter = null;
      break;
  }

  return visitRepo.getVisitsByOrganization(
    'a0000000-0000-0000-0000-000000000001',
    statusFilter: statusFilter,
    limit: 100,
  );
});

/// Visits Screen — List of all visits with filters.
class VisitsScreen extends ConsumerWidget {
  const VisitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(visitFilterProvider);
    final visitsAsync = ref.watch(consoleVisitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitas'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(consoleVisitsProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: VisitFilter.values.map((f) {
                final isSelected = f == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filterLabel(f)),
                    selected: isSelected,
                    onSelected: (_) {
                      ref.read(visitFilterProvider.notifier).state = f;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: KigoTheme.umbral200),

          // Visits list
          Expanded(
            child: visitsAsync.when(
              data: (visits) {
                if (visits.isEmpty) {
                  return KigoEmpty(
                    title: 'No hay visitas ${_filterLabel(filter).toLowerCase()}',
                    icon: Icons.event_busy,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(consoleVisitsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: visits.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final visit = visits[index];
                      return _VisitCard(
                        visit: visit,
                        onTap: () {
                          context.push(
                            '/console/visits/${visit['id']}',
                            extra: visit,
                          );
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: KigoTheme.kigo500),
              ),
              error: (e, _) => KigoError(
                message: 'No se pudieron cargar las visitas. Intenta de nuevo.',
                onRetry: () => ref.invalidate(consoleVisitsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(VisitFilter filter) {
    switch (filter) {
      case VisitFilter.all:
        return 'Todas';
      case VisitFilter.active:
        return 'Activas';
      case VisitFilter.pending:
        return 'Pendientes';
      case VisitFilter.completed:
        return 'Completadas';
      case VisitFilter.rejected:
        return 'Rechazadas';
    }
  }
}

class _VisitCard extends StatelessWidget {
  final Map<String, dynamic> visit;
  final VoidCallback onTap;

  const _VisitCard({required this.visit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final visitor = visit['visitors'] as Map<String, dynamic>? ?? {};
    final host = visit['profiles'] as Map<String, dynamic>? ?? {};
    final firstName = visitor['first_name'] ?? '';
    final lastName = visitor['last_name'] ?? '';
    final company = visitor['company'] ?? '';
    final hostName = host['full_name'] ?? '';
    final status = visit['status'] as String? ?? '';
    final createdAt = visit['created_at'] as String?;

    final timeStr = createdAt != null
        ? DateFormat('HH:mm').format(DateTime.parse(createdAt).toLocal())
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: KigoTheme.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KigoTheme.umbral200),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: _statusBgColor(status),
              child: Text(
                firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: _statusTextColor(status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$firstName $lastName',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: KigoTheme.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (company.isNotEmpty) ...[
                        Text(
                          company,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: KigoTheme.gray500,
                          ),
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(color: KigoTheme.gray400),
                        ),
                      ],
                      if (hostName.isNotEmpty)
                        Text(
                          hostName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: KigoTheme.gray500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Status + time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusBadge(status: status),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: KigoTheme.gray500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'ACTIVE':
      case 'CHECKED_IN':
        return KigoTheme.green100;
      case 'PENDING':
      case 'PRE_AUTHORIZED':
      case 'IN_PROGRESS':
        return KigoTheme.yellow50;
      case 'COMPLETED':
        return KigoTheme.umbral100;
      case 'REJECTED':
      case 'CANCELLED':
        return KigoTheme.red100;
      default:
        return KigoTheme.umbral100;
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'ACTIVE':
      case 'CHECKED_IN':
        return KigoTheme.green600;
      case 'PENDING':
      case 'PRE_AUTHORIZED':
      case 'IN_PROGRESS':
        return KigoTheme.yellow400;
      case 'COMPLETED':
        return KigoTheme.slate500;
      case 'REJECTED':
      case 'CANCELLED':
        return KigoTheme.red500;
      default:
        return KigoTheme.slate500;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBgColor();
    final textColor = _getTextColor();
    final label = _getLabel();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Color _getBgColor() {
    switch (status) {
      case 'ACTIVE':
      case 'CHECKED_IN':
        return KigoTheme.green100;
      case 'PENDING':
      case 'PRE_AUTHORIZED':
        return KigoTheme.sky50;
      case 'IN_PROGRESS':
        return KigoTheme.yellow50;
      case 'COMPLETED':
        return KigoTheme.umbral100;
      case 'REJECTED':
      case 'CANCELLED':
        return KigoTheme.red100;
      default:
        return KigoTheme.umbral100;
    }
  }

  Color _getTextColor() {
    switch (status) {
      case 'ACTIVE':
      case 'CHECKED_IN':
        return KigoTheme.green600;
      case 'PENDING':
      case 'PRE_AUTHORIZED':
        return KigoTheme.sky900;
      case 'IN_PROGRESS':
        return KigoTheme.yellow400;
      case 'COMPLETED':
        return KigoTheme.slate500;
      case 'REJECTED':
      case 'CANCELLED':
        return KigoTheme.red500;
      default:
        return KigoTheme.slate500;
    }
  }

  String _getLabel() {
    switch (status) {
      case 'ACTIVE':
        return 'Activa';
      case 'CHECKED_IN':
        return 'Check-in';
      case 'PENDING':
        return 'Pendiente';
      case 'PRE_AUTHORIZED':
        return 'Pre-autorizada';
      case 'IN_PROGRESS':
        return 'En proceso';
      case 'COMPLETED':
        return 'Completada';
      case 'REJECTED':
        return 'Rechazada';
      case 'CANCELLED':
        return 'Cancelada';
      default:
        return status;
    }
  }
}
