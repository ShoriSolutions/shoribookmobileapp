import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/errors/app_exception.dart';
import '../../business_context/application/active_business_provider.dart';

/// Backs the editable Business Profile screen: saves the profile fields
/// (through the lock-enforcing RPC) and handles logo/cover image uploads.
class BusinessProfileController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Saves all profile fields. Returns the RPC status — 'ok', or 'locked'
  /// if a name/category change was blocked by the 90-day cooldown, or null
  /// on error (surfaced via state).
  Future<String?> save({
    required String businessId,
    required String name,
    String? category,
    String? description,
    String? phone,
    String? email,
    String? address,
    String? whatsappNumber,
    String? instagramUrl,
    String? facebookUrl,
    String? tiktokUrl,
    String? googleMapsUrl,
    List<String>? badges,
    bool? featuredRequested,
    double? latitude,
    double? longitude,
  }) async {
    state = const AsyncLoading();
    try {
      final res =
          await ref.read(businessRepositoryProvider).updateBusinessProfile(
                businessId: businessId,
                name: name,
                category: category,
                description: description,
                phone: phone,
                email: email,
                address: address,
                whatsappNumber: whatsappNumber,
                instagramUrl: instagramUrl,
                facebookUrl: facebookUrl,
                tiktokUrl: tiktokUrl,
                googleMapsUrl: googleMapsUrl,
                badges: badges,
                featuredRequested: featuredRequested,
                latitude: latitude,
                longitude: longitude,
              );
      ref.invalidate(activeMembershipProvider);
      state = const AsyncData(null);
      return (res?['status'] as String?) ?? 'ok';
    } catch (e, st) {
      state = AsyncError(AppException.from(e), st);
      return null;
    }
  }

  /// Gets the device's current coordinates for "use my current location".
  /// Handles permission + service checks; throws an AppException with a
  /// friendly message the caller can show if anything is off.
  Future<({double lat, double lng})> currentLocation() async {
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
          'Location permission denied. Enable it in Settings to use your '
          'current location.',
        );
      }
      final pos = await Geolocator.getCurrentPosition();
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Picks an image from the gallery and uploads it as the logo or cover.
  /// Returns true on success, false if cancelled or on error.
  Future<bool> pickAndUploadImage({
    required String businessId,
    required bool isCover,
  }) async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Downscale on pick so uploads stay small; display always uses
        // BoxFit.cover in a fixed aspect box, so nothing is distorted.
        maxWidth: isCover ? 1600 : 800,
        maxHeight: isCover ? 1600 : 800,
        imageQuality: 85,
      );
      if (file == null) return false; // user cancelled
      state = const AsyncLoading();
      final bytes = await file.readAsBytes();
      final parts = file.name.split('.');
      final ext = parts.length > 1 ? parts.last : 'jpg';
      await ref.read(businessRepositoryProvider).uploadBusinessImage(
            businessId: businessId,
            isCover: isCover,
            bytes: bytes,
            fileExtension: ext,
          );
      ref.invalidate(activeMembershipProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(AppException.from(e), st);
      return false;
    }
  }
}

final businessProfileControllerProvider =
    AsyncNotifierProvider<BusinessProfileController, void>(
      BusinessProfileController.new,
    );
