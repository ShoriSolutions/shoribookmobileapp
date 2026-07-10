import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/appointment.dart';
import '../../auth/application/auth_providers.dart';
import '../data/my_bookings_repository.dart';

final myBookingsRepositoryProvider = Provider<MyBookingsRepository>((ref) {
  return MyBookingsRepository(ref.watch(supabaseClientProvider));
});

final myBookingsProvider = FutureProvider.autoDispose<List<Appointment>>((
  ref,
) async {
  final authStatus = ref.watch(authStatusProvider);
  if (authStatus != AuthStatus.authenticated) return [];
  return ref.watch(myBookingsRepositoryProvider).fetchMyBookings();
});

final bookingDetailProvider = FutureProvider.autoDispose
    .family<Appointment, String>(
      (ref, id) => ref.watch(myBookingsRepositoryProvider).fetchById(id),
    );
