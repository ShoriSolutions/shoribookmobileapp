import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/profile.dart';
import '../../auth/application/auth_providers.dart';
import '../../business_context/application/active_business_provider.dart';
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

/// Which experience the app should show. The two well-known roles map
/// directly; anything else (a web-created professional role, 'admin', or a
/// missing/blank profile) is resolved from real business membership rather
/// than the role string, so a valid professional is never turned away just
/// because their role isn't literally 'entrepreneur'. `unsupported` is only
/// for accounts that are neither a customer nor a member of any business.
enum AppMode { businessOwner, customer, unsupported }

/// Null while the mode isn't known yet — the profile is still resolving, or a
/// non-standard role is still waiting on its membership read. Callers should
/// treat null as "not yet known", not as "unsupported".
final appModeProvider = Provider<AppMode?>((ref) {
  final profileAsync = ref.watch(myProfileProvider);
  return profileAsync.whenOrNull(
    data: (profile) {
      final role = profile?.role;
      if (role == 'user') return AppMode.customer;
      if (role == 'entrepreneur') return AppMode.businessOwner;
      // Unknown/absent role: decide from business membership. A member of any
      // business is a business user; anyone else (including a true admin,
      // whose surface is web-only) stays unsupported here.
      final membershipAsync = ref.watch(activeMembershipProvider);
      return membershipAsync.when(
        loading: () => null, // not yet known -- the router waits on splash
        error: (_, __) => AppMode.unsupported,
        data: (m) => m != null ? AppMode.businessOwner : AppMode.unsupported,
      );
    },
  );
});
