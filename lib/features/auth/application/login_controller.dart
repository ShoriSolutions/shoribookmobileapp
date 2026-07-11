import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../app_mode/application/app_mode_provider.dart';
import '../../business_context/application/active_business_provider.dart';
import 'auth_providers.dart';

class LoginController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithPassword(email: email, password: password);

      // Best-effort: if this is an entrepreneur who signed up on mobile
      // but only just confirmed their email, their business is created
      // now from the details stashed at signup (idempotent no-op for
      // everyone else). Never block login on it — a missing RPC (e.g.
      // migration not yet applied) must not stop the user getting in.
      try {
        final result = await authRepo.registerBusiness();
        if (result != null && result['status'] == 'created') {
          // A business was just created — refresh the providers the
          // router keys off so it routes to the business home rather
          // than the no-business screen.
          ref.invalidate(myProfileProvider);
          ref.invalidate(activeMembershipProvider);
        }
      } catch (_) {
        // Swallow: login already succeeded.
      }

      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(AppException.from(e), st);
      return false;
    }
  }
}

final loginControllerProvider = AsyncNotifierProvider<LoginController, void>(
  LoginController.new,
);
