import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for the toggleable Home stat cards, with display labels. Revenue
/// and bookings-today live in the hero and aren't toggleable.
const dashboardStatCards = <String, String>{
  'completed': 'Completed today',
  'noShows': 'No-shows today',
  'cancelled': 'Cancelled today',
  'pendingDeposits': 'Pending deposits',
  'staffOnDuty': 'Staff on duty',
};

const _prefsKey = 'dashboard_stats_enabled';

/// The set of stat-card keys the owner has chosen to show on Home,
/// persisted per-device via shared_preferences. Defaults to all on.
class DashboardStatsPrefs extends Notifier<Set<String>> {
  SharedPreferences? _prefs;

  @override
  Set<String> build() {
    _load();
    return dashboardStatCards.keys.toSet();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs!.getStringList(_prefsKey);
    if (saved != null) {
      // Keep only keys we still recognise.
      state = saved.where(dashboardStatCards.containsKey).toSet();
    }
  }

  Future<void> setEnabled(String key, bool enabled) async {
    final next = {...state};
    if (enabled) {
      next.add(key);
    } else {
      next.remove(key);
    }
    state = next;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setStringList(_prefsKey, next.toList());
  }
}

final dashboardStatsPrefsProvider =
    NotifierProvider<DashboardStatsPrefs, Set<String>>(
      DashboardStatsPrefs.new,
    );
