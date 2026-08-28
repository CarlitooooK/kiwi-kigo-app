import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';

/// Dashboard statistics for today.
class DashboardStats {
  final int totalToday;
  final int active;
  final int pending;
  final int completed;
  final int rejected;

  const DashboardStats({
    this.totalToday = 0,
    this.active = 0,
    this.pending = 0,
    this.completed = 0,
    this.rejected = 0,
  });
}

/// Provider that fetches dashboard stats from Supabase.
/// Uses the hardcoded demo org ID and filters by organization_id directly.
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final client = ref.watch(supabaseProvider);

  // Get today's date range in local time
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  // Query visits directly by organization_id
  // This avoids issues with RLS recursive subqueries
  final visits = await client
      .from('visits')
      .select('status, created_at')
      .eq('organization_id', 'a0000000-0000-0000-0000-000000000001')
      .gte('created_at', todayStart.toUtc().toIso8601String())
      .lt('created_at', todayEnd.toUtc().toIso8601String());

  final allVisits = List<Map<String, dynamic>>.from(visits);

  int active = 0;
  int pending = 0;
  int completed = 0;
  int rejected = 0;

  for (final visit in allVisits) {
    final status = visit['status'] as String? ?? '';
    switch (status) {
      case 'ACTIVE':
      case 'CHECKED_IN':
        active++;
        break;
      case 'PENDING':
      case 'PRE_AUTHORIZED':
      case 'IN_PROGRESS':
        pending++;
        break;
      case 'COMPLETED':
        completed++;
        break;
      case 'REJECTED':
      case 'CANCELLED':
        rejected++;
        break;
    }
  }

  return DashboardStats(
    totalToday: allVisits.length,
    active: active,
    pending: pending,
    completed: completed,
    rejected: rejected,
  );
});
