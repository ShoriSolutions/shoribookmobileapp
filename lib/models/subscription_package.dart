/// Billing cadence the vendor is viewing/choosing.
enum BillingPeriod { monthly, yearly }

/// A subscription plan loaded dynamically from the subscription_packages
/// table — nothing about pricing is hardcoded in the app. Carries the
/// store product identifiers used to fetch the real localized price and
/// start an App Store / Play purchase.
class SubscriptionPackage {
  final String id;
  final String name;
  final String? tagline;
  final List<String> features;
  final double? priceAmount; // display/fallback; the store price wins if available
  final String currency;
  final String billingPeriod; // monthly | annual | weekly | once | trial
  final int trialDays;
  final String? storeProductIdIos;
  final String? storeProductIdAndroid;
  final String? storeProductIdIosAnnual;
  final String? storeProductIdAndroidAnnual;
  final bool isPopular;
  final int sortOrder;

  const SubscriptionPackage({
    required this.id,
    required this.name,
    this.tagline,
    this.features = const [],
    this.priceAmount,
    this.currency = 'BBD',
    this.billingPeriod = 'monthly',
    this.trialDays = 14,
    this.storeProductIdIos,
    this.storeProductIdAndroid,
    this.storeProductIdIosAnnual,
    this.storeProductIdAndroidAnnual,
    this.isPopular = false,
    this.sortOrder = 0,
  });

  /// "per month" / "per year" / … — the cadence shown next to the price.
  String get periodLabel {
    switch (billingPeriod) {
      case 'annual':
        return 'per year';
      case 'weekly':
        return 'per week';
      case 'once':
        return 'one-time';
      case 'monthly':
        return 'per month';
      default:
        return '';
    }
  }

  factory SubscriptionPackage.fromJson(Map<String, dynamic> json) =>
      SubscriptionPackage(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Plan',
        tagline: json['tagline'] as String?,
        features: (json['features'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        priceAmount: (json['price_amount'] as num?)?.toDouble(),
        currency: json['currency'] as String? ?? 'BBD',
        billingPeriod: json['billing_period'] as String? ?? 'monthly',
        trialDays: (json['trial_days'] as num?)?.toInt() ?? 14,
        storeProductIdIos: json['store_product_id_ios'] as String?,
        storeProductIdAndroid: json['store_product_id_android'] as String?,
        storeProductIdIosAnnual: json['store_product_id_ios_annual'] as String?,
        storeProductIdAndroidAnnual:
            json['store_product_id_android_annual'] as String?,
        isPopular: json['is_popular'] as bool? ?? false,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );
}
