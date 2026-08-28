import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/kigo_error.dart';
import '../data/dashboard_providers.dart';

/// Dashboard Screen — Main console landing page with real stats.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.person, size: 18),
                label: Text(
                  user.email?.split('@').first ?? 'User',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/console/login');
            },
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardStatsProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hoy',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: KigoTheme.slate900,
                ),
              ),
              const SizedBox(height: 24),

              // Stats
              statsAsync.when(
                data: (stats) => _StatsGrid(stats: stats),
                loading: () => const _StatsGrid(
                  stats: DashboardStats(),
                  isLoading: true,
                ),
                error: (e, _) => KigoError(
                  message: 'No se pudieron cargar las estadísticas. Intenta de nuevo.',
                  onRetry: () => ref.invalidate(dashboardStatsProvider),
                ),
              ),

              const SizedBox(height: 32),

              // Quick actions
              const Text(
                'Acciones rápidas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: KigoTheme.slate900,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _QuickAction(
                    icon: Icons.people_outline,
                    label: 'Ver visitas',
                    onTap: () => context.go('/console/visits'),
                  ),
                  _QuickAction(
                    icon: Icons.hourglass_empty,
                    label: 'Pendientes',
                    onTap: () => context.go('/console/visits?filter=pending'),
                  ),
                  _QuickAction(
                    icon: Icons.person_pin_circle,
                    label: 'Activas',
                    onTap: () => context.go('/console/visits?filter=active'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final DashboardStats stats;
  final bool isLoading;

  const _StatsGrid({required this.stats, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _StatCard(
              title: 'Visitas hoy',
              value: isLoading ? '—' : '${stats.totalToday}',
              icon: Icons.calendar_today,
              badgeBg: KigoTheme.sky50,
              badgeColor: KigoTheme.sky900,
            ),
            _StatCard(
              title: 'Activas',
              value: isLoading ? '—' : '${stats.active}',
              icon: Icons.person_pin_circle,
              badgeBg: KigoTheme.green100,
              badgeColor: KigoTheme.green600,
            ),
            _StatCard(
              title: 'Pendientes',
              value: isLoading ? '—' : '${stats.pending}',
              icon: Icons.hourglass_empty,
              badgeBg: KigoTheme.yellow50,
              badgeColor: KigoTheme.yellow400,
            ),
            _StatCard(
              title: 'Completadas',
              value: isLoading ? '—' : '${stats.completed}',
              icon: Icons.check_circle_outline,
              badgeBg: KigoTheme.umbral100,
              badgeColor: KigoTheme.slate500,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color badgeBg;
  final Color badgeColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.badgeBg,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KigoTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KigoTheme.umbral200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: badgeColor, size: 22),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: KigoTheme.slate900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: KigoTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KigoTheme.umbral200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: KigoTheme.kigo500),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: KigoTheme.slate900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
