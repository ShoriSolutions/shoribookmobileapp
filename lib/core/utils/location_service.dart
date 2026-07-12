import 'package:geolocator/geolocator.dart';
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
