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
  @override
  Future<ActiveMembership?> build() async {
    final authStatus = ref.watch(authStatusProvider);
    if (authStatus != AuthStatus.authenticated) return null;

    final profile = await ref.watch(myProfileProvider.future);
    if (profile?.role != 'entrepreneur') return null;

    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return null;

    return ref.read(businessRepositoryProvider).getActiveMembership(userId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
