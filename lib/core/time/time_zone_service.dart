import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Centralized time-zone service — the single source of truth for all UTC ↔
/// local conversions, DST handling, device detection, and formatting.
///
/// Rules enforced everywhere in the app:
///  - appointments are stored in **UTC**;
///  - conversions use the **IANA tz database** (via the `timezone` package),
///    so Daylight Saving Time is handled automatically where applicable and
///    zones that don't observe DST (e.g. America/Barbados) stay correct;
///  - never hardcode numeric UTC offsets.
///
/// [businessLocalToUtc] / [utcToBusinessLocal] in timezone_offsets.dart
/// delegate here, so every existing caller is DST-correct for free.
class TimeZoneService {
  const TimeZoneService._();

  static const String fallbackZone = 'America/Barbados';
  static bool _ready = false;

  /// Loads the IANA tz database. Safe to call repeatedly; call once at
  /// startup (main) — conversions also self-initialize defensively.
  static void ensureInitialized() {
    if (_ready) return;
    tzdata.initializeTimeZones();
    _ready = true;
  }

  static tz.Location _location(String? name) {
    ensureInitialized();
    try {
      return tz.getLocation((name == null || name.isEmpty) ? fallbackZone : name);
    } catch (_) {
      return tz.getLocation(fallbackZone);
    }
  }

  /// A wall-clock date ("YYYY-MM-DD") + time ("HH:MM") in [zone] → the UTC
  /// instant. DST-aware.
  static DateTime localToUtc({
    required String date,
    required String time,
    required String? zone,
  }) {
    final d = date.split('-').map(int.parse).toList();
    final t = time.split(':').map(int.parse).toList();
    final loc = _location(zone);
    return tz.TZDateTime(loc, d[0], d[1], d[2], t[0], t[1]).toUtc();
  }

  /// A UTC instant → the wall-clock time in [zone] (a [tz.TZDateTime] whose
  /// fields are that zone's local time; formats/`.hour`/`.weekday` reflect it).
  static tz.TZDateTime utcToZone(DateTime utc, String? zone) {
    return tz.TZDateTime.from(utc.toUtc(), _location(zone));
  }

  /// The device's current IANA zone (e.g. "America/New_York"). Falls back to
  /// [fallbackZone] if detection fails.
  static Future<String> deviceTimeZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final id = info.identifier.trim();
      return id.isEmpty ? fallbackZone : id;
    } catch (_) {
      return fallbackZone;
    }
  }

  /// Whether two zones render a different wall-clock for the given instant
  /// (accounts for DST). Same-name or null → false.
  static bool zonesDiffer(DateTime utc, String? a, String? b) {
    if (a == null || b == null || a == b) return false;
    return utcToZone(utc, a).timeZoneOffset != utcToZone(utc, b).timeZoneOffset;
  }

  /// A friendly place label from an IANA id, e.g. "America/New_York" → "New
  /// York", "Europe/London" → "London". Customer-facing (no GMT/UTC math).
  static String friendlyName(String? zone) {
    if (zone == null || zone.isEmpty) return '';
    return zone.split('/').last.replaceAll('_', ' ');
  }

  /// The zone's short abbreviation for the instant (e.g. AST, EDT, GMT).
  static String abbreviation(DateTime utc, String? zone) =>
      utcToZone(utc, zone).timeZoneName;

  // ── Formatting helpers (all take a UTC instant + a zone) ────────────────

  /// "Tue, Aug 18 · 2:00 PM"
  static String dateTime(DateTime utc, String? zone) {
    final local = utcToZone(utc, zone);
    return DateFormat('EEE, MMM d · h:mm a').format(local);
  }

  /// "Tuesday, August 18 · 2:00 PM"
  static String longDateTime(DateTime utc, String? zone) {
    final local = utcToZone(utc, zone);
    return DateFormat('EEEE, MMMM d · h:mm a').format(local);
  }

  /// "2:00 PM"
  static String time(DateTime utc, String? zone) =>
      DateFormat('h:mm a').format(utcToZone(utc, zone));
}
