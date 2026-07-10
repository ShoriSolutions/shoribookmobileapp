import 'package:intl/intl.dart';
import 'timezone_offsets.dart';

/// Human-readable formatters that always take a UTC instant + the
/// business's timezone — never the device's local time. See
/// timezone_offsets.dart for why.
class DateTimeFormatters {
  const DateTimeFormatters._();

  static String time(DateTime utc, String? timezone) {
    final local = utcToBusinessLocal(utc, timezone);
    return DateFormat('h:mm a').format(local);
  }

  static String timeRange(DateTime startUtc, DateTime endUtc, String? tz) {
    return '${time(startUtc, tz)} – ${time(endUtc, tz)}';
  }

  static String weekdayDate(DateTime utc, String? timezone) {
    final local = utcToBusinessLocal(utc, timezone);
    return DateFormat('EEE, MMM d').format(local);
  }

  static String fullDate(DateTime utc, String? timezone) {
    final local = utcToBusinessLocal(utc, timezone);
    return DateFormat('EEEE, MMMM d, y').format(local);
  }

  static String monthYear(DateTime utc, String? timezone) {
    final local = utcToBusinessLocal(utc, timezone);
    return DateFormat('MMMM y').format(local);
  }

  /// Relative label for a date already expressed as business-local
  /// "YYYY-MM-DD" against "today" in the same business timezone.
  static String relativeDayLabel(String isoDate, String? timezone) {
    final now = DateTime.now().toUtc();
    final todayStr = businessLocalDateString(now, timezone);
    final tomorrowStr = businessLocalDateString(
      now.add(const Duration(days: 1)),
      timezone,
    );
    final yesterdayStr = businessLocalDateString(
      now.subtract(const Duration(days: 1)),
      timezone,
    );
    if (isoDate == todayStr) return 'Today';
    if (isoDate == tomorrowStr) return 'Tomorrow';
    if (isoDate == yesterdayStr) return 'Yesterday';
    final parts = isoDate.split('-').map(int.parse).toList();
    return DateFormat(
      'EEE, MMM d',
    ).format(DateTime(parts[0], parts[1], parts[2]));
  }
}
