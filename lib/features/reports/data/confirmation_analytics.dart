/// Confirmation-window + waitlist analytics for a period, from the
/// get_confirmation_waitlist_analytics RPC. Rates are 0..1 (null when the
/// denominator is 0); [avgConfirmationMinutes] is null when nothing confirmed.
class ConfirmationAnalytics {
  final int confirmationRequiredTotal;
  final int confirmedTotal;
  final int expiredTotal;
  final int pendingTotal;
  final double? confirmationRate;
  final double? avgConfirmationMinutes;
  final int waitlistTotal;
  final int waitlistNotified;
  final int waitlistConverted;
  final double? waitlistConversionRate;
  final int expiredCustomers;
  final int rebookedCustomers;
  final double? rebookRate;

  const ConfirmationAnalytics({
    required this.confirmationRequiredTotal,
    required this.confirmedTotal,
    required this.expiredTotal,
    required this.pendingTotal,
    required this.confirmationRate,
    required this.avgConfirmationMinutes,
    required this.waitlistTotal,
    required this.waitlistNotified,
    required this.waitlistConverted,
    required this.waitlistConversionRate,
    required this.expiredCustomers,
    required this.rebookedCustomers,
    required this.rebookRate,
  });

  /// True when there's nothing to show (no confirmation or waitlist activity).
  bool get isEmpty =>
      confirmationRequiredTotal == 0 && waitlistTotal == 0 && expiredTotal == 0;

  factory ConfirmationAnalytics.fromJson(Map<String, dynamic> json) {
    double? d(String k) => (json[k] as num?)?.toDouble();
    int i(String k) => json[k] as int? ?? 0;
    return ConfirmationAnalytics(
      confirmationRequiredTotal: i('confirmation_required_total'),
      confirmedTotal: i('confirmed_total'),
      expiredTotal: i('expired_total'),
      pendingTotal: i('pending_total'),
      confirmationRate: d('confirmation_rate'),
      avgConfirmationMinutes: d('avg_confirmation_minutes'),
      waitlistTotal: i('waitlist_total'),
      waitlistNotified: i('waitlist_notified'),
      waitlistConverted: i('waitlist_converted'),
      waitlistConversionRate: d('waitlist_conversion_rate'),
      expiredCustomers: i('expired_customers'),
      rebookedCustomers: i('rebooked_customers'),
      rebookRate: d('rebook_rate'),
    );
  }
}
