import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import 'auth_providers.dart';

/// Result of a successful registration — whether the session is already
/// active (no email confirmation required) or the user needs to check
/// their inbox first.
class RegisterResult {
  final bool sessionActive;
  const RegisterResult({required this.sessionActive});
}

class CustomerRegisterController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<RegisterResult?> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final sessionActive = await ref
          .read(authRepositoryProvider)
          .signUpCustomer(email: email, password: password, fullName: fullName);
      state = const AsyncData(null);
      return RegisterResult(sessionActive: sessionActive);
    } catch (e, st) {
      state = AsyncError(AppException.from(e), st);
      return null;
    }
  }
}

final customerRegisterControllerProvider =
    AsyncNotifierProvider<CustomerRegisterController, void>(
      CustomerRegisterController.new,
    );
