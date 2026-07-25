import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Raw auth state change stream — the single source of truth the
/// router's redirect logic and business-context provider both listen to.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// True from the moment a password-recovery deep link signs the user in
/// until they've set a new password. While true, the router pins them to
/// the Set-password screen (otherwise the normal role redirect would bounce
/// them to their home before they can change it).
final passwordRecoveryProvider = StateProvider<bool>((ref) => false);

enum AuthStatus { unknown, unauthenticated, authenticated }

/// Derived, synchronously-readable auth status for the router guard.
/// `unknown` only for the brief window before the first auth event
/// arrives (Supabase.initialize is awaited before runApp, so in
/// practice this resolves almost immediately).
final authStatusProvider = Provider<AuthStatus>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final stateAsync = ref.watch(authStateChangesProvider);

  // An anonymous (guest) session is deliberately treated as unauthenticated
  // so the guest-first UX (browsing, guest booking, "Log in or sign up"
  // prompts) is unchanged. Anonymous users still get a uid for messaging.
  bool realSession(Session? s) => s != null && !(s.user.isAnonymous);

  return stateAsync.when(
    data: (state) => realSession(state.session)
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated,
    loading: () => realSession(authRepo.currentSession)
        ? AuthStatus.authenticated
        : AuthStatus.unknown,
    error: (_, __) => AuthStatus.unauthenticated,
  );
});
