/// Public web links (share / booking pages). Centralized so the live domain
/// is set in ONE place instead of being hardcoded across share sheets.
///
/// IMPORTANT (release): confirm [webBaseUrl] points at the deployed public
/// web domain and that it renders a real booking page before shipping — these
/// URLs are what customers receive when a business shares its booking link.
class AppLinks {
  const AppLinks._();

  /// Base URL of the public web app that hosts the booking/business pages.
  static const String webBaseUrl = 'https://betterbooking.app';

  /// Public booking page for a business slug (optionally tagged with a source).
  static String booking(String slug, {String? source}) {
    final base = '$webBaseUrl/book/$slug';
    return source == null ? base : '$base?source=$source';
  }

  /// Public business profile page for a slug.
  static String business(String slug) => '$webBaseUrl/business/$slug';

  /// The Shorivo website (marketing + account). Android routes all plan
  /// purchases here rather than through Google Play.
  static const String siteBaseUrl = 'https://shorivo.com';

  /// Web billing/checkout page a vendor is sent to when purchasing a plan on
  /// Android (purchases happen on the website, not through Google Play).
  /// [plan] is an optional plan-name hint the web page can preselect.
  static String billing({String? plan}) {
    final base = '$siteBaseUrl/dashboard/billing';
    return (plan == null || plan.isEmpty)
        ? base
        : '$base?plan=${Uri.encodeQueryComponent(plan)}';
  }
}
