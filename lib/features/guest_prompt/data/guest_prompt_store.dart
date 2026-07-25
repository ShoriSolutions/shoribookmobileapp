import 'package:shared_preferences/shared_preferences.dart';

/// Remembers when the "create a free account" prompt was last shown to a
/// guest, so it never nags. Shown at most once per [_cooldown] window,
/// triggered by natural moments (a completed booking, opening My Bookings)
/// — never on app launch.
class GuestPromptStore {
  static const _key = 'guest_account_prompt_last_shown_v1';
  static const _cooldown = Duration(days: 30);

  Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return true;
    final last = DateTime.tryParse(raw);
    if (last == null) return true;
    return DateTime.now().difference(last) > _cooldown;
  }

  Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, DateTime.now().toIso8601String());
  }
}
