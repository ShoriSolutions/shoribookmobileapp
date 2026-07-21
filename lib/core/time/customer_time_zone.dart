import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'time_zone_service.dart';

/// Stores the customer's manual time-zone override (Settings). Null = auto
/// (detect from the device). We never require manual selection unless the
/// user chooses to override.
class CustomerTimeZonePrefs {
  static const _key = 'customer_timezone_override_v1';

  Future<String?> override() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> setOverride(String? zone) async {
    final prefs = await SharedPreferences.getInstance();
    if (zone == null || zone.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, zone);
    }
  }
}

final customerTimeZonePrefsProvider =
    Provider<CustomerTimeZonePrefs>((ref) => CustomerTimeZonePrefs());

/// The manual override, if any (drives the Settings toggle). Refresh after
/// changing it to re-resolve [customerTimeZoneProvider].
final customerTimeZoneOverrideProvider =
    FutureProvider<String?>((ref) => ref.watch(customerTimeZonePrefsProvider).override());

/// The customer's effective IANA zone: their manual override, else the
/// auto-detected device zone, else the fallback. Used to show "your local
/// time" and to stamp the booking with the customer's zone.
final customerTimeZoneProvider = FutureProvider<String>((ref) async {
  final override = await ref.watch(customerTimeZoneOverrideProvider.future);
  if (override != null) return override;
  return TimeZoneService.deviceTimeZone();
});
