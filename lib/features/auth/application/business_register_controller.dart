import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../app_mode/application/app_mode_provider.dart';
import '../../business_context/application/active_business_provider.dart';
import 'auth_providers.dart';
import 'customer_register_controller.dart' show RegisterResult;

/// Business (entrepreneur) self-registration, mirroring
/// CustomerRegisterController. The business row is only created here when
/// a session comes back immediately (autoconfirm on); otherwise it's
/// created at first login — see AuthRepository.registerBusiness and the
/// login controller's post-sign-in hook.
class BusinessRegisterController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<RegisterResult?> signUp({
    required String fullName,
    required String businessName,
    required String category,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final sessionActive = await authRepo.signUpBusiness(
        email: email,
        password: password,
        fullName: fullName,
        businessName: businessName,
        category: category,
      );

      if (sessionActive) {
        // Rare (email confirmation is on for this project), but if a
        // session is live we can create the business straight away and
        // refresh the router's providers so it lands on the business home.
        await authRepo.registerBusiness();
        ref.invalidate(myProfileProvider);
        ref.invalidate(activeMembershipProvider);
      }

      state = const AsyncData(null);
      return RegisterResult(sessionActive: sessionActive);
    } catch (e, st) {
      state = AsyncError(AppException.from(e), st);
      return null;
    }
  }
}

final businessRegisterControllerProvider =
    AsyncNotifierProvider<BusinessRegisterController, void>(
      BusinessRegisterController.new,
    );
