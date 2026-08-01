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
    // Customers (role 'user') never own a business membership, so skip the
    // business_members query for them. EVERY other role -- 'entrepreneur',
    // a web-created professional role, 'admin', or even a missing/blank
    // profile row -- falls through to the read: if they belong to a business
    // they are treated as a business user regardless of the exact role
    // string. (A genuinely business-less account just settles to null.)
    if (profile?.role == 'user') return null;

    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return null;

    final repo = ref.read(businessRepositoryProvider);
    // Just after a fresh sign-in the session token can lag by a beat before
    // it's attached to requests. `profiles` is public-readable so myProfile
    // succeeds and masks the lag, but `business_members` is gated by
    // auth.uid(), so this first read can come back EMPTY (not an error) --
    // which the router reads as a false "No business found" that a relogin
    // clears. Retry on empty-or-error a few times so it self-heals; a
    // genuinely business-less account just settles to null after the retries.
    for (var attempt = 0;; attempt++) {
      try {
        final membership = await repo.getActiveMembership(userId);
        if (membership != null || attempt >= _retryDelays.length) {
          return membership;
        }
      } catch (_) {
        if (attempt >= _retryDelays.length) rethrow;
      }
      await Future.delayed(_retryDelays[attempt]);
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
