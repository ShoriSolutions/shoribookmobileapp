import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/appointment.dart';
import '../../business_context/application/active_business_provider.dart';
import '../data/dashboard_repository.dart';
import '../data/dashboard_stats.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(supabaseClientProvider));
});

class DashboardData {
  final List<Appointment> todayAppointments;
  final Appointment? nextUpcoming;
  final DashboardStats stats;

  const DashboardData({
    required this.todayAppointments,
    required this.nextUpcoming,
    required this.stats,
  });
}

final dashboardDataProvider = FutureProvider.autoDispose<DashboardData>((
  ref,
) async {
  final membership = await ref.watch(activeMembershipProvider.future);
  if (membership == null) {
    return const DashboardData(
      todayAppointments: [],
      nextUpcoming: null,
      stats: DashboardStats.zero,
    );
  }

  final repo = ref.watch(dashboardRepositoryProvider);
  final businessId = membership.business.id;
  final timezone = membership.business.timezone;
  final staffProfileId = membership.role.value == 'STAFF'
      ? membership.staffProfileId
      : null;

  final results = await Future.wait([
    repo.fetchTodayAppointments(
      businessId: businessId,
      timezone: timezone,
      staffProfileId: staffProfileId,
    ),
    repo.fetchNextUpcoming(
      businessId: businessId,
      staffProfileId: staffProfileId,
    ),
    repo.fetchStats(
      businessId: businessId,
      timezone: timezone,
      staffProfileId: staffProfileId,
    ),
  ]);

  return DashboardData(
    todayAppointments: results[0] as List<Appointment>,
    nextUpcoming: results[1] as Appointment?,
    stats: results[2] as DashboardStats,
  );
});
