class DashboardStats {
  final int bookingsToday;
  final int bookingsThisWeek;
  final int completedThisMonth;
  final double revenueThisMonth;
  final int noShowsThisMonth;
  final int pendingDepositsCount;

  const DashboardStats({
    required this.bookingsToday,
    required this.bookingsThisWeek,
    required this.completedThisMonth,
    required this.revenueThisMonth,
    required this.noShowsThisMonth,
    required this.pendingDepositsCount,
  });

  static const zero = DashboardStats(
    bookingsToday: 0,
    bookingsThisWeek: 0,
    completedThisMonth: 0,
    revenueThisMonth: 0,
    noShowsThisMonth: 0,
    pendingDepositsCount: 0,
  );
}
