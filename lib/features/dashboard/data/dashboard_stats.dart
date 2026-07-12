/// Today's at-a-glance numbers for the Home screen. Monthly/weekly
/// aggregates live in the Reports screen instead.
class DashboardStats {
  final int bookingsToday;
  final int completedToday;
  final double revenueToday;
  final int noShowsToday;
  final int cancelledToday;
  final int pendingDepositsCount;
  final int staffOnDuty;
  final int staffTotal;

  const DashboardStats({
    required this.bookingsToday,
    required this.completedToday,
    required this.revenueToday,
    required this.noShowsToday,
    required this.cancelledToday,
    required this.pendingDepositsCount,
    required this.staffOnDuty,
    required this.staffTotal,
  });

  static const zero = DashboardStats(
    bookingsToday: 0,
    completedToday: 0,
    revenueToday: 0,
    noShowsToday: 0,
    cancelledToday: 0,
    pendingDepositsCount: 0,
    staffOnDuty: 0,
    staffTotal: 0,
  );
}
