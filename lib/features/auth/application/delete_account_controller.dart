import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import 'auth_providers.dart';

/// Two-step account deletion: send an email confirmation code, then verify
/// it and permanently delete the account.
class DeleteAccountController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> sendCode() async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).sendEmailOtp();
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(AppException.from(e), st);
      return false;
    }
  }

  Future<bool> confirmDelete(String code) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).deleteAccount(code);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(AppException.from(e), st);
      return false;
    }
  }
}

final deleteAccountControllerProvider =
    AsyncNotifierProvider<DeleteAccountController, void>(
      DeleteAccountController.new,
    );
