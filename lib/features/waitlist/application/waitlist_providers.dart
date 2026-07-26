import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/waitlist_entry.dart';
import '../../auth/application/auth_providers.dart';
import '../data/guest_waitlist_store.dart';
import '../data/waitlist_repository.dart';

final waitlistRepositoryProvider = Provider<WaitlistRepository>((ref) {
  return WaitlistRepository(ref.watch(supabaseClientProvider));
});

final guestWaitlistStoreProvider =
    Provider<GuestWaitlistStore>((ref) => GuestWaitlistStore());

/// The current customer's waitlist entries — their own when signed in, or the
/// ones joined on this device (id + phone) as a guest.
final myWaitlistProvider =
    FutureProvider.autoDispose<List<WaitlistEntry>>((ref) async {
  final authStatus = ref.watch(authStatusProvider);
  final repo = ref.watch(waitlistRepositoryProvider);
  if (authStatus == AuthStatus.authenticated) {
    final uid = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    if (uid == null) return [];
    return repo.fetchMine(uid);
  }
  final refs = await ref.watch(guestWaitlistStoreProvider).all();
  if (refs.isEmpty) return [];
  return repo.fetchGuest(refs);
});

/// A business's active waitlist entries (vendor view).
final businessWaitlistProvider = FutureProvider.autoDispose
    .family<List<WaitlistEntry>, String>((ref, businessId) async {
  return ref.watch(waitlistRepositoryProvider).fetchForBusiness(businessId);
});
