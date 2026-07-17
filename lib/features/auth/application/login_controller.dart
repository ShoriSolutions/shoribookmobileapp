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
    final authRepo = ref.read(authRepositoryProvider);
    final normEmail = email.trim().toLowerCase();

    // Pre-check: is this account locked out from too many recent attempts?
    // Best-effort — a missing migration must never block a valid login.
    try {
      final lock = await authRepo.checkLoginLock(normEmail);
      if (lock != null && lock['locked'] == true) {
        state = AsyncError(
          AppException(_lockedMessage(lock)),
          StackTrace.current,
        );
        return false;
      }
    } catch (_) {}

    try {
      await authRepo.signInWithPassword(email: email, password: password);
      // Correct password — clear the failed-attempt counter.
      try {
        await authRepo.resetLoginAttempts(normEmail);
      } catch (_) {}

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

      // Best-effort: if an address was captured at sign-up (before email
      // confirmation), drain it into the profile now. No-op once drained.
      try {
        await authRepo.drainPendingAddress();
        ref.invalidate(myProfileProvider);
      } catch (_) {
        // Swallow: login already succeeded; address can be set later.
      }

      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      final appEx = AppException.from(e);
      // Only wrong-credential failures count toward the limit (not network
      // errors). On the 5th, the account locks and the owner is emailed.
      if (_looksLikeBadCredentials(appEx.message)) {
        try {
          final res = await authRepo.recordFailedLogin(normEmail);
          if (res != null && res['locked'] == true) {
            state = AsyncError(AppException(_lockedMessage(res)), st);
            return false;
          }
          final remaining = (res?['remaining'] as num?)?.toInt();
          if (remaining != null && remaining > 0 && remaining <= 2) {
            state = AsyncError(
              AppException('Incorrect email or password. '
                  '$remaining attempt${remaining == 1 ? '' : 's'} left.'),
              st,
            );
            return false;
          }
        } catch (_) {}
      }
      state = AsyncError(appEx, st);
      return false;
    }
  }

  bool _looksLikeBadCredentials(String message) {
    final m = message.toLowerCase();
    return m.contains('invalid') ||
        m.contains('credential') ||
        m.contains('password');
  }

  String _lockedMessage(Map<String, dynamic> res) {
    final until = res['locked_until'] as String?;
    var mins = 15;
    if (until != null) {
      final diff = DateTime.parse(until).difference(DateTime.now()).inMinutes;
      mins = diff.clamp(1, 60);
    }
    return 'Too many login attempts. For your security this account is '
        'locked for about $mins minute${mins == 1 ? '' : 's'}. We\'ve emailed '
        "you to confirm it was you — if it wasn't, reset your password.";
  }
}

final loginControllerProvider = AsyncNotifierProvider<LoginController, void>(
  LoginController.new,
);
