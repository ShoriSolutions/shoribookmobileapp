import 'package:flutter/foundation.dart';

/// Builds a "directions to" URL for the device's preferred maps app:
/// Apple Maps on iOS/macOS, Google Maps everywhere else (on Android this
/// opens the Google Maps app if installed; web/other fall back to the
/// browser). Launch it with `LaunchMode.externalApplication`.
///
/// `defaultTargetPlatform` is used (not `dart:io` Platform) so this is
/// safe on web too.
Uri directionsUrl(double latitude, double longitude) {
  final isApple = defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  if (isApple) {
    return Uri.parse('https://maps.apple.com/?daddr=$latitude,$longitude');
  }
  return Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
  );
}
