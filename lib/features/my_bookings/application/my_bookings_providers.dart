import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/appointment.dart';
import '../../auth/application/auth_providers.dart';
import '../data/guest_bookings_store.dart';
import '../data/my_bookings_repository.dart';

final myBookingsRepositoryProvider = Provider<MyBookingsRepository>((ref) {
  return MyBookingsRepository(ref.watch(supabaseClientProvider));
});

final guestBookingsStoreProvider =
    Provider<GuestBookingsStore>((ref) => GuestBookingsStore());

/// The phone a guest booked this appointment with (from on-device storage),
/// or null if signed in / not made on this device. Lets a guest cancel or
/// reschedule their own booking without an account.
final guestBookingPhoneProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, id) async {
  if (ref.watch(authStatusProvider) == AuthStatus.authenticated) return null;
  return ref.watch(guestBookingsStoreProvider).phoneFor(id);
});

final myBookingsProvider = FutureProvider.autoDispose<List<Appointment>>((
  ref,
) async {
  final authStatus = ref.watch(authStatusProvider);
  final repo = ref.watch(myBookingsRepositoryProvider);
  if (authStatus == AuthStatus.authenticated) {
    return repo.fetchMyBookings();
  }
  // Guest: show the bookings made on this device (looked up by id + phone).
  final refs = await ref.watch(guestBookingsStoreProvider).all();
  if (refs.isEmpty) return [];
  return repo.fetchGuestBookings(refs);
});

final bookingDetailProvider = FutureProvider.autoDispose
    .family<Appointment, String>((ref, id) async {
  final authStatus = ref.watch(authStatusProvider);
  final repo = ref.watch(myBookingsRepositoryProvider);
  if (authStatus == AuthStatus.authenticated) {
    return repo.fetchById(id);
  }
  final phone = await ref.watch(guestBookingsStoreProvider).phoneFor(id);
  if (phone == null) {
    throw StateError('This booking was not made on this device.');
  }
  return repo.fetchGuestById(id, phone);
});
