import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../app_mode/application/app_mode_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../data/active_membership.dart';
import '../data/business_repository.dart';

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository(ref.watch(supabaseClientProvider));
});

/// Resolves to the active membership whenever auth state changes to
/// authenticated, and to null when signed out, when an authenticated
/// user has no ACTIVE business membership yet (routes to /no-business),
/// or when the account isn't a business-owner account at all (a
/// customer-role user — see app_mode) — avoids querying business_members
/// for every customer session.
final activeMembershipProvider = AsyncNotifierProvider<
  ActiveMembershipNotifier,
  ActiveMembership?
>(ActiveMembershipNotifier.new);

class ActiveMembershipNotifier extends AsyncNotifier<ActiveMembership?> {
  // Backoff between retries of the first membership read after sign-in.
  static const _retryDelays = [
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
    Duration(milliseconds: 1000),
  ];

  @override
  Future<ActiveMembership?> build() async {
    final authStatus = ref.watch(authStatusProvider);
    if (authStatus != AuthStatus.authenticated) return null;

    final profile = await ref.watch(myProfileProvider.future);
    if (profile?.role != 'entrepreneur') return null;

    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return null;

    final repo = ref.read(businessRepositoryProvider);
    // Just after a fresh sign-in the client's session can lag by a beat, so
    // this first business_members read occasionally fails. Without a retry
    // that failure surfaces as a false "No business found" (the router reads
    // an errored membership the same as an empty one) that a relogin clears.
    // Retry a few times with backoff so it self-heals. A genuine no-business
    // account returns null WITHOUT throwing, so it isn't delayed by this.
    for (var attempt = 0;; attempt++) {
      try {
        return await repo.getActiveMembership(userId);
      } catch (_) {
        if (attempt >= _retryDelays.length) rethrow;
        await Future.delayed(_retryDelays[attempt]);
      }
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
