import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the user tapped "Don't show again" on the launch
/// subscription promo, so it never auto-opens for them afterwards.
class SubscriptionPromoPrefs {
  static const _key = 'subscription_promo_dismissed_v1';

  Future<bool> dismissedForever() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setDismissedForever() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
