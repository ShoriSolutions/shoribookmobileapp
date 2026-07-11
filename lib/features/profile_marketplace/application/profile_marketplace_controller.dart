import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../business_context/application/active_business_provider.dart';

/// Toggles the active business's public-visibility flags. Each change is
/// persisted immediately, then the active-membership provider is
/// refreshed so the switches reflect the stored state.
class ProfileMarketplaceController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> setFlags({
    bool? isPublished,
    bool? isMarketplaceListed,
    bool? bookingEnabled,
  }) async {
    state = const AsyncLoading();
    try {
      final business = ref.read(activeMembershipProvider).valueOrNull?.business;
      if (business == null) {
        throw const AppException('No active business.');
      }
      await ref.read(businessRepositoryProvider).updateVisibility(
            business.id,
            isPublished: isPublished,
            isMarketplaceListed: isMarketplaceListed,
            bookingEnabled: bookingEnabled,
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

final profileMarketplaceControllerProvider =
    AsyncNotifierProvider<ProfileMarketplaceController, void>(
      ProfileMarketplaceController.new,
    );
