import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/deposit_submission.dart';
import '../../business_context/application/active_business_provider.dart';
import '../data/deposit_verification_repository.dart';

final depositVerificationRepositoryProvider =
    Provider<DepositVerificationRepository>((ref) {
  return DepositVerificationRepository(ref.watch(supabaseClientProvider));
});

/// Deposits awaiting review for the active business.
final pendingDepositsProvider =
    FutureProvider.autoDispose<List<DepositSubmission>>((ref) async {
  final membership = await ref.watch(activeMembershipProvider.future);
  if (membership == null) return const [];
  return ref
      .watch(depositVerificationRepositoryProvider)
      .fetchPending(membership.business.id);
});

/// Count for badges/banners (0 while loading).
final pendingDepositsCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(pendingDepositsProvider).valueOrNull?.length ?? 0;
});
