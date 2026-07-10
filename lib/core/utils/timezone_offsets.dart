/// Fixed UTC-offset timezone handling, ported from the web app's
/// src/lib/availability.ts / appointments actions.ts approach.
///
/// The Caribbean zones this business operates in never observe DST, so
/// a small fixed-offset lookup table is correct and avoids pulling in
/// the full `timezone` package + its IANA tzdata payload for a business
/// rule this simple. If the business ever expands to a DST-observing
/// timezone, this table (and the web app's identical one) would both
/// need to change.
///
/// Never use device-local time (`DateTime.now()` and friends) for
/// anything shown as "business time" — the device's timezone can differ
/// from the business's configured timezone (e.g. an owner checking the
/// app while traveling). Always route through [businessLocalToUtc] /
/// [utcToBusinessLocal].
class TimezoneOffsets {
  const TimezoneOffsets._();

  static const Map<String, int> offsetHours = {
    'America/Barbados': -4,
    'America/Port_of_Spain': -4,
    'America/Grenada': -4,
    'America/St_Lucia': -4,
    'America/St_Vincent': -4,
    'America/Dominica': -4,
    'America/Antigua': -4,
    'America/Montserrat': -4,
    'America/Puerto_Rico': -4,
    'America/Santo_Domingo': -4,
    'America/Jamaica': -5,
    'UTC': 0,
  };

  static const String defaultTimezone = 'America/Barbados';

  static int offsetFor(String? timezone) =>
      offsetHours[timezone] ?? offsetHours[defaultTimezone]!;
}

/// Converts a business-local date + "HH:MM" time to a UTC DateTime,
/// mirroring the web's `Date.UTC(y, m-1, d, h-offset, min)` math.
DateTime businessLocalToUtc({
  required String date, // "YYYY-MM-DD"
  required String time, // "HH:MM"
  required String? timezone,
}) {
  final offset = TimezoneOffsets.offsetFor(timezone);
  final dateParts = date.split('-').map(int.parse).toList();
  final timeParts = time.split(':').map(int.parse).toList();
  return DateTime.utc(
    dateParts[0],
    dateParts[1],
    dateParts[2],
    timeParts[0] - offset,
    timeParts[1],
  );
}

/// Converts a UTC DateTime to the business's local wall-clock DateTime
/// (still a DateTime, but its fields represent business-local time —
/// use [formatBusinessDate]/[formatBusinessTime] for display).
DateTime utcToBusinessLocal(DateTime utc, String? timezone) {
  final offset = TimezoneOffsets.offsetFor(timezone);
  return utc.toUtc().add(Duration(hours: offset));
}

/// "YYYY-MM-DD" for a UTC instant, expressed in business-local time.
String businessLocalDateString(DateTime utc, String? timezone) {
  final local = utcToBusinessLocal(utc, timezone);
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
