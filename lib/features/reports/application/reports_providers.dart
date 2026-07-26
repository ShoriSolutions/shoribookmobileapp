import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../business_context/application/active_business_provider.dart';
import '../data/confirmation_analytics.dart';
import '../data/report_summary.dart';
import '../data/reports_repository.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(supabaseClientProvider));
});

enum ReportRange {
  week('Week'),
  month('Month'),
  quarter('Quarter'),
  year('Year');

  final String label;
  const ReportRange(this.label);
}

final reportRangeProvider = StateProvider<ReportRange>((ref) => ReportRange.month);

/// The [start, end] dates for a report range, relative to today.
({DateTime start, DateTime end}) reportRangeDates(ReportRange range) {
  final now = DateTime.now();
  switch (range) {
    case ReportRange.week:
      final start = now.subtract(Duration(days: now.weekday % 7));
      return (start: start, end: start.add(const Duration(days: 6)));
    case ReportRange.month:
      return (
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      );
    case ReportRange.quarter:
      final firstMonthOfQuarter = now.month - ((now.month - 1) % 3);
      return (
        start: DateTime(now.year, firstMonthOfQuarter, 1),
        end: DateTime(now.year, firstMonthOfQuarter + 3, 0),
      );
    case ReportRange.year:
      return (start: DateTime(now.year, 1, 1), end: DateTime(now.year, 12, 31));
  }
}

final reportSummaryProvider = FutureProvider.autoDispose<ReportSummary>((
  ref,
) async {
  final membership = await ref.watch(activeMembershipProvider.future);
  if (membership == null) {
    throw StateError('No active business');
  }
  final dates = reportRangeDates(ref.watch(reportRangeProvider));
  return ref.watch(reportsRepositoryProvider).fetchSummary(
        businessId: membership.business.id,
        startDate: dates.start,
        endDate: dates.end,
      );
});

/// Confirmation-window + waitlist analytics for the selected range.
final confirmationAnalyticsProvider =
    FutureProvider.autoDispose<ConfirmationAnalytics>((ref) async {
  final membership = await ref.watch(activeMembershipProvider.future);
  if (membership == null) {
    throw StateError('No active business');
  }
  final dates = reportRangeDates(ref.watch(reportRangeProvider));
  return ref.watch(reportsRepositoryProvider).fetchConfirmationAnalytics(
        businessId: membership.business.id,
        startDate: dates.start,
        endDate: dates.end,
      );
});
