import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/staff_profile.dart';
import '../../business_context/application/active_business_provider.dart';
import '../data/invite_repository.dart';
import '../data/staff_repository.dart';

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return StaffRepository(ref.watch(supabaseClientProvider));
});

final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  return InviteRepository(ref.watch(supabaseClientProvider));
});

final staffListProvider = FutureProvider.autoDispose<List<StaffProfile>>((
  ref,
) async {
  final membership = await ref.watch(activeMembershipProvider.future);
  if (membership == null) return [];
  return ref.watch(staffRepositoryProvider).fetchAll(membership.business.id);
});
