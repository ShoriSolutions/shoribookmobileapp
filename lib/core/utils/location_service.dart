import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import '../../models/address.dart';
import '../errors/app_exception.dart';

/// Gets the device's current coordinates, handling the location-services
/// and permission checks. Throws an AppException with a friendly message
/// the caller can surface. Shared by the business profile editor and the
/// marketplace "Near me" sort.
Future<({double lat, double lng})> getCurrentLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppException('Location services are turned off.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const AppException(
        'Location permission denied. Enable it in Settings to sort by '
        'distance.',
      );
    }
    final pos = await Geolocator.getCurrentPosition();
    return (lat: pos.latitude, lng: pos.longitude);
  } catch (e) {
    throw AppException.from(e);
  }
}

/// "450 m" / "2.3 km" style label for a distance in metres.
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Reverse-geocodes coordinates into an [Address] using the platform's
/// native geocoder (Core Location on iOS / Geocoder on Android — no API
/// key). If the lookup yields nothing or fails (offline, no result), the
/// returned Address still carries the coordinates so they can be stored.
Future<Address> reverseGeocode(double lat, double lng) async {
  try {
    final marks = await geo.placemarkFromCoordinates(lat, lng);
    if (marks.isEmpty) return Address(latitude: lat, longitude: lng);
    final p = marks.first;
    var street = [p.subThoroughfare, p.thoroughfare]
        .where((s) => s != null && s.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (street.isEmpty) street = _nz(p.street) ?? _nz(p.name) ?? '';
    return Address(
      countryCode: _nz(p.isoCountryCode),
      countryName: _nz(p.country),
      adminArea: _nz(p.administrativeArea),
      city: _nz(p.locality) ?? _nz(p.subAdministrativeArea),
      postalCode: _nz(p.postalCode),
      street: street.isEmpty ? null : street,
      latitude: lat,
      longitude: lng,
    );
  } catch (_) {
    return Address(latitude: lat, longitude: lng);
  }
}

/// One-shot for a "Use my current location" button: permission + GPS +
/// reverse geocode. Throws an [AppException] with a friendly message on
/// permission/service problems (surfaced by [getCurrentLocation]).
Future<Address> resolveCurrentAddress() async {
  final loc = await getCurrentLocation();
  return reverseGeocode(loc.lat, loc.lng);
}

String? _nz(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
