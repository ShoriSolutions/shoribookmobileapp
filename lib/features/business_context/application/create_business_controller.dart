import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../app_mode/application/app_mode_provider.dart';
import '../../auth/application/auth_providers.dart';
import 'active_business_provider.dart';

/// Drives the in-app "Create your business" form for a logged-in
/// entrepreneur who has no business yet (the no-business screen). Calls
/// the register_business RPC with the entered name/category.
class CreateBusinessController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> create({
    required String name,
    required String category,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .registerBusiness(name: name, category: category);
      final status = result?['status'];
      if (status != 'created' && status != 'exists') {
        throw const AppException(
          "Couldn't create your business. Please try again.",
        );
      }
      // Refresh the providers the router keys off so it routes from the
      // no-business screen to the business home once membership resolves.
      ref.invalidate(myProfileProvider);
      ref.invalidate(activeMembershipProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(AppException.from(e), st);
      return false;
    }
  }
}

final createBusinessControllerProvider =
    AsyncNotifierProvider<CreateBusinessController, void>(
      CreateBusinessController.new,
    );
