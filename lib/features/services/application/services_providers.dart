import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/service.dart';
import '../../business_context/application/active_business_provider.dart';
import '../data/services_repository.dart';

final servicesRepositoryProvider = Provider<ServicesRepository>((ref) {
  return ServicesRepository(ref.watch(supabaseClientProvider));
});

final servicesListProvider = FutureProvider.autoDispose<List<Service>>((
  ref,
) async {
  final membership = await ref.watch(activeMembershipProvider.future);
  if (membership == null) return [];
  return ref.watch(servicesRepositoryProvider).fetchAll(membership.business.id);
});
