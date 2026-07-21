/// Business-time conversions. These are thin wrappers over
/// [TimeZoneService], which uses the IANA tz database so Daylight Saving
/// Time is handled automatically. The old fixed-offset table has been
/// retired in favour of real IANA/DST conversions.
///
/// Never use device-local time (`DateTime.now()` and friends) for
/// anything shown as "business time" — the device's timezone can differ
/// from the business's configured timezone (e.g. an owner checking the
/// app while traveling). Always route through [businessLocalToUtc] /
/// [utcToBusinessLocal].
library;

import '../time/time_zone_service.dart';

const String defaultBusinessTimezone = TimeZoneService.fallbackZone;

/// Converts a business-local date + "HH:MM" time to a UTC DateTime.
/// DST-aware (via the IANA tz database).
DateTime businessLocalToUtc({
  required String date, // "YYYY-MM-DD"
  required String time, // "HH:MM"
  required String? timezone,
}) =>
    TimeZoneService.localToUtc(date: date, time: time, zone: timezone);

/// Converts a UTC DateTime to the business's local wall-clock DateTime
/// (fields represent business-local time; DST-aware).
DateTime utcToBusinessLocal(DateTime utc, String? timezone) =>
    TimeZoneService.utcToZone(utc, timezone);

/// "YYYY-MM-DD" for a UTC instant, expressed in business-local time.
String businessLocalDateString(DateTime utc, String? timezone) {
  final local = utcToBusinessLocal(utc, timezone);
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
