import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/availability_models.dart';
import '../../business_context/application/active_business_provider.dart';
import '../data/availability_repository.dart';

final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  return AvailabilityRepository(ref.watch(supabaseClientProvider));
});

/// The active business's weekly hours. Auto-disposes so re-entering the
/// screen re-fetches, and rebuilds if the active business changes.
final businessHoursProvider = FutureProvider.autoDispose<List<BusinessHours>>((
  ref,
) async {
  final membership = ref.watch(activeMembershipProvider).valueOrNull;
  if (membership == null) return const [];
  return ref
      .read(availabilityRepositoryProvider)
      .getBusinessHours(membership.business.id);
});

final blockedTimesProvider = FutureProvider.autoDispose<List<BlockedTime>>((
  ref,
) async {
  final membership = ref.watch(activeMembershipProvider).valueOrNull;
  if (membership == null) return const [];
  return ref
      .read(availabilityRepositoryProvider)
      .getBlockedTimes(membership.business.id);
});

final specialDaysProvider =
    FutureProvider.autoDispose<List<SpecialBusinessDay>>((ref) async {
  final membership = ref.watch(activeMembershipProvider).valueOrNull;
  if (membership == null) return const [];
  return ref
      .read(availabilityRepositoryProvider)
      .getSpecialDays(membership.business.id);
});

/// One staff member's weekly availability, keyed by staff_profile id.
final staffAvailabilityProvider = FutureProvider.autoDispose
    .family<List<StaffAvailability>, String>((ref, staffId) async {
  return ref
      .read(availabilityRepositoryProvider)
      .getStaffAvailability(staffId);
});
