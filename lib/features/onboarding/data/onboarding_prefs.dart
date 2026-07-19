import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the customer has seen the one-slide first-run intro,
/// so it only ever shows once (before the marketplace, guest-first).
class OnboardingPrefs {
  static const _key = 'onboarding_seen_v1';

  Future<bool> seen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
