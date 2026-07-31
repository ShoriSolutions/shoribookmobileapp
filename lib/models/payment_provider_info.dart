/// How a provider stands for a given business country.
enum ProviderAvailability {
  available, // active + country supported -> configurable
  comingSoon, // status coming_soon
  notInRegion, // active but the country isn't supported
  inactive, // hidden
}

/// A row from the payment_providers registry (region-based availability). The
/// app never hardcodes providers -- it reads this and classifies per country.
class PaymentProviderInfo {
  final String id;
  final String name;
  final String? logoAsset;
  final List<String> supportedCountries;
  final String status; // active | coming_soon | inactive
  final List<String> requiredFields;
  final int sortOrder;

  const PaymentProviderInfo({
    required this.id,
    required this.name,
    this.logoAsset,
    this.supportedCountries = const [],
    this.status = 'active',
    this.requiredFields = const [],
    this.sortOrder = 0,
  });

  ProviderAvailability availabilityFor(String country) {
    if (status == 'inactive') return ProviderAvailability.inactive;
    if (status == 'coming_soon') return ProviderAvailability.comingSoon;
    if (supportedCountries.contains(country)) {
      return ProviderAvailability.available;
    }
    return ProviderAvailability.notInRegion;
  }

  static List<String> _strList(dynamic v) =>
      (v as List?)?.map((e) => e.toString()).toList() ?? const [];

  factory PaymentProviderInfo.fromJson(Map<String, dynamic> json) =>
      PaymentProviderInfo(
        id: json['id'] as String,
        name: json['name'] as String? ?? json['id'] as String,
        logoAsset: json['logo_asset'] as String?,
        supportedCountries: _strList(json['supported_countries']),
        status: json['status'] as String? ?? 'active',
        requiredFields: _strList(json['required_fields']),
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}
