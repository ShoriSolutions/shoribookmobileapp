import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/payment_profile.dart';
import '../../business_context/application/active_business_provider.dart';
import '../data/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(supabaseClientProvider));
});

/// The active business's FirstPay profile (null when not configured).
final firstPayProfileProvider =
    FutureProvider.autoDispose<PaymentProfile?>((ref) async {
  final membership = await ref.watch(activeMembershipProvider.future);
  if (membership == null) return null;
  return ref
      .watch(paymentRepositoryProvider)
      .fetchProfile(membership.business.id);
});

/// Whether the active business has a ready payment method (deposits allowed).
final depositReadyProvider = FutureProvider.autoDispose<bool>((ref) async {
  final membership = await ref.watch(activeMembershipProvider.future);
  if (membership == null) return false;
  return ref
      .watch(paymentRepositoryProvider)
      .hasReadyPaymentMethod(membership.business.id);
});
