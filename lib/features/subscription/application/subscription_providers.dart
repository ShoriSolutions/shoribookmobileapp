import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/subscription_package.dart';
import '../data/subscription_promo_prefs.dart';
import '../data/subscription_repository.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepository(ref.watch(supabaseClientProvider)),
);

final subscriptionPromoPrefsProvider =
    Provider<SubscriptionPromoPrefs>((ref) => SubscriptionPromoPrefs());

/// The dynamic package catalog. Deliberately NOT autoDispose, so the plans
/// are cached for the session and re-opening the modal doesn't refetch —
/// invalidate it to force a background refresh.
final subscriptionPackagesProvider =
    FutureProvider<List<SubscriptionPackage>>((ref) {
  return ref.watch(subscriptionRepositoryProvider).fetchPackages();
});
