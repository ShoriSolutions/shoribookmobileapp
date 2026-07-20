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

/// Billing cadence the vendor is viewing/choosing.
enum BillingPeriod { monthly, yearly }

/// The annual-billing discount percent, read from app_config
/// (annual_discount_percent) so promos are configurable server-side with
/// no app change. Defaults to 20 if unset/unreachable.
final annualDiscountPercentProvider = FutureProvider<double>((ref) async {
  try {
    final row = await ref
        .watch(supabaseClientProvider)
        .from('app_config')
        .select('num_value')
        .eq('key', 'annual_discount_percent')
        .maybeSingle();
    return (row?['num_value'] as num?)?.toDouble() ?? 20;
  } catch (_) {
    return 20;
  }
});

/// Annual price for a monthly amount given the configured discount:
/// monthly x 12 x (1 - percent/100).
double annualAmount(double monthlyAmount, double discountPercent) {
  return monthlyAmount * 12 * (1 - discountPercent / 100);
}
