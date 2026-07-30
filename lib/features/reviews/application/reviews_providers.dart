import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/review.dart';
import '../../business_context/application/active_business_provider.dart';
import '../data/reviews_repository.dart';

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  return ReviewsRepository(ref.watch(supabaseClientProvider));
});

/// Published reviews for a business (public profile).
final businessReviewsProvider = FutureProvider.autoDispose
    .family<List<Review>, String>((ref, businessId) async {
  return ref.watch(reviewsRepositoryProvider).fetchForBusiness(businessId);
});

/// All reviews for the active business (vendor Customer Feedback).
final vendorReviewsProvider =
    FutureProvider.autoDispose<List<Review>>((ref) async {
  final membership = await ref.watch(activeMembershipProvider.future);
  if (membership == null) return const [];
  return ref
      .watch(reviewsRepositoryProvider)
      .fetchForBusiness(membership.business.id, publishedOnly: false);
});

/// The signed-in customer's review for an appointment (null if not reviewed).
final reviewForAppointmentProvider = FutureProvider.autoDispose
    .family<Review?, String>((ref, appointmentId) async {
  return ref
      .watch(reviewsRepositoryProvider)
      .fetchMineForAppointment(appointmentId);
});

/// Minimum words required for a low (1-2 star) rating, from app_config.
final reviewMinWordsProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final row = await ref
        .watch(supabaseClientProvider)
        .from('app_config')
        .select('num_value')
        .eq('key', 'review_low_rating_min_words')
        .maybeSingle();
    return (row?['num_value'] as num?)?.toInt() ?? 75;
  } catch (_) {
    return 75;
  }
});
