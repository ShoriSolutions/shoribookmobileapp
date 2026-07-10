import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/profile.dart';
import '../../auth/application/auth_providers.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

/// The logged-in user's platform-wide profile (profiles.role), distinct
/// from the business-scoped BusinessRole that business_context owns.
/// Same shape as ActiveMembershipNotifier: null when unauthenticated.
final myProfileProvider = AsyncNotifierProvider<MyProfileNotifier, Profile?>(
  MyProfileNotifier.new,
);

class MyProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final authStatus = ref.watch(authStatusProvider);
    if (authStatus != AuthStatus.authenticated) return null;

    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return null;

    return ref.read(profileRepositoryProvider).fetchMyProfile(userId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Which experience the app should show, derived from profiles.role.
/// `unsupported` covers 'admin', unrecognized values, and — while the
/// profile is still resolving — is never returned (see appModeProvider,
/// which surfaces loading/null separately rather than guessing).
enum AppMode { businessOwner, customer, unsupported }

/// Null while the profile hasn't resolved yet (unauthenticated, or the
/// AsyncValue is still loading) — callers should treat null as "not yet
/// known", not as "unsupported".
final appModeProvider = Provider<AppMode?>((ref) {
  final profileAsync = ref.watch(myProfileProvider);
  return profileAsync.whenOrNull(
    data: (profile) {
      if (profile == null) return null;
      switch (profile.role) {
        case 'entrepreneur':
          return AppMode.businessOwner;
        case 'user':
          return AppMode.customer;
        default:
          return AppMode.unsupported;
      }
    },
  );
});
