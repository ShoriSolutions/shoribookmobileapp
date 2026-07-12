class ReportSummary {
  final int totalAppointments;
  final int completedCount;
  final int cancelledCount;
  final int noShowCount;
  final int pendingCount;
  final int confirmedCount;
  final double totalRevenue;
  final double depositsCollected;
  final int pendingDepositsCount;
  final List<({String date, int count})> appointmentsByDay;
  final List<({String date, double revenue})> revenueByDay;
  final Map<String, int> statusBreakdown;
  final Map<String, int> bookingSourceBreakdown;
  final List<({String serviceId, String name, int count})> topServices;

  const ReportSummary({
    required this.totalAppointments,
    required this.completedCount,
    required this.cancelledCount,
    required this.noShowCount,
    required this.pendingCount,
    required this.confirmedCount,
    required this.totalRevenue,
    required this.depositsCollected,
    required this.pendingDepositsCount,
    required this.appointmentsByDay,
    required this.revenueByDay,
    required this.statusBreakdown,
    required this.bookingSourceBreakdown,
    required this.topServices,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) => ReportSummary(
    totalAppointments: json['total_appointments'] as int? ?? 0,
    completedCount: json['completed_count'] as int? ?? 0,
    cancelledCount: json['cancelled_count'] as int? ?? 0,
    noShowCount: json['no_show_count'] as int? ?? 0,
    pendingCount: json['pending_count'] as int? ?? 0,
    confirmedCount: json['confirmed_count'] as int? ?? 0,
    totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
    depositsCollected: (json['deposits_collected'] as num?)?.toDouble() ?? 0,
    pendingDepositsCount: json['pending_deposits_count'] as int? ?? 0,
    appointmentsByDay:
        (json['appointments_by_day'] as List<dynamic>? ?? [])
            .map(
              (e) => (
                date: e['date'] as String,
                count: e['count'] as int,
              ),
            )
            .toList(),
    revenueByDay:
        (json['revenue_by_day'] as List<dynamic>? ?? [])
            .map(
              (e) => (
                date: e['date'] as String,
                revenue: (e['revenue'] as num?)?.toDouble() ?? 0,
              ),
            )
            .toList(),
    statusBreakdown: Map<String, int>.from(
      (json['status_breakdown'] as Map<dynamic, dynamic>? ?? {}),
    ),
    bookingSourceBreakdown: Map<String, int>.from(
      (json['booking_source_breakdown'] as Map<dynamic, dynamic>? ?? {}),
    ),
    topServices:
        (json['top_services'] as List<dynamic>? ?? [])
            .map(
              (e) => (
                serviceId: e['service_id'] as String,
                name: e['name'] as String,
                count: e['count'] as int,
              ),
            )
            .toList(),
  );
}
