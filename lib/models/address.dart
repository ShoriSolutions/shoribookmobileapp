/// A reusable postal address + coordinates, used across registration,
/// profile editing, and (in future) delivery/service-area features. Maps
/// to the address_* columns shared by profiles and businesses.
class Address {
  final String? countryCode; // ISO 3166-1 alpha-2, e.g. 'BB'
  final String? countryName;
  final String? adminArea; // parish / state / province / region
  final String? city;
  final String? postalCode;
  final String? street;
  final double? latitude;
  final double? longitude;

  const Address({
    this.countryCode,
    this.countryName,
    this.adminArea,
    this.city,
    this.postalCode,
    this.street,
    this.latitude,
    this.longitude,
  });

  bool get isEmpty =>
      (countryCode == null || countryCode!.isEmpty) &&
      (adminArea == null || adminArea!.isEmpty) &&
      (city == null || city!.isEmpty) &&
      (postalCode == null || postalCode!.isEmpty) &&
      (street == null || street!.isEmpty) &&
      latitude == null &&
      longitude == null;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Human-readable one-line address (skips blanks).
  String get formatted => [
        street,
        city,
        adminArea,
        postalCode,
        countryName,
      ].where((p) => p != null && p.trim().isNotEmpty).join(', ');

  Address copyWith({
    String? countryCode,
    String? countryName,
    String? adminArea,
    String? city,
    String? postalCode,
    String? street,
    double? latitude,
    double? longitude,
  }) =>
      Address(
        countryCode: countryCode ?? this.countryCode,
        countryName: countryName ?? this.countryName,
        adminArea: adminArea ?? this.adminArea,
        city: city ?? this.city,
        postalCode: postalCode ?? this.postalCode,
        street: street ?? this.street,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        countryCode: json['country_code'] as String?,
        countryName: json['country_name'] as String?,
        adminArea: json['admin_area'] as String?,
        city: json['city'] as String?,
        postalCode: json['postal_code'] as String?,
        street: (json['street_address'] ?? json['address']) as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  /// Map to the profiles columns (street stored as `street_address`).
  Map<String, dynamic> toProfileJson() => {
        'country_code': countryCode,
        'country_name': countryName,
        'admin_area': adminArea,
        'city': city,
        'postal_code': postalCode,
        'street_address': street,
        'latitude': latitude,
        'longitude': longitude,
      };
}
