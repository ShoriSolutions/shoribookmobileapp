import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/payment_profile.dart';
import '../../../models/payment_provider_info.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../subscription/application/plan_caps.dart';
import '../data/payment_provider_service.dart';
import '../data/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(supabaseClientProvider));
});

final paymentProviderServiceProvider = Provider<PaymentProviderService>((ref) {
  return PaymentProviderService(ref.watch(supabaseClientProvider));
});

/// The full provider registry (region-based availability).
final paymentProviderRegistryProvider =
    FutureProvider.autoDispose<List<PaymentProviderInfo>>((ref) {
  return ref.watch(paymentProviderServiceProvider).fetchProviders();
});

/// The platform default country (when a business hasn't set its own).
final defaultCountryProvider = FutureProvider.autoDispose<String>((ref) {
  return ref.watch(paymentProviderServiceProvider).defaultCountry();
});

/// The active business's effective country (its own, else the default).
final effectiveBusinessCountryProvider = Provider.autoDispose<String>((ref) {
  final biz = ref.watch(activeMembershipProvider).valueOrNull?.business;
  final def = ref.watch(defaultCountryProvider).valueOrNull ?? 'BB';
  final c = biz?.countryCode?.trim();
  return (c == null || c.isEmpty) ? def : c.toUpperCase();
});

typedef ClassifiedProvider = ({
  PaymentProviderInfo info,
  ProviderAvailability availability,
});

/// The registry classified for the active business's country (inactive hidden).
final businessPaymentProvidersProvider =
    FutureProvider.autoDispose<List<ClassifiedProvider>>((ref) async {
  final all = await ref.watch(paymentProviderRegistryProvider.future);
  final country = ref.watch(effectiveBusinessCountryProvider);
  return [
    for (final p in all)
      if (p.availabilityFor(country) != ProviderAvailability.inactive)
        (info: p, availability: p.availabilityFor(country)),
  ];
});

/// Whether any provider is configurable in the business's region.
final anyProviderAvailableProvider = Provider.autoDispose<bool>((ref) {
  final list = ref.watch(businessPaymentProvidersProvider).valueOrNull ??
      const <ClassifiedProvider>[];
  return list.any((e) => e.availability == ProviderAvailability.available);
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

/// Whether the business can require deposits, and if not, why. Combines the
/// plan gate, the region (no supported provider in the country), and the
/// payment prerequisite.
enum DepositCapability { enabled, needsPayment, needsPlan, noRegionProvider }

final depositCapabilityProvider =
    Provider.autoDispose<DepositCapability>((ref) {
  final caps = ref.watch(activePlanCapsProvider);
  if (!caps.deposits) return DepositCapability.needsPlan;
  // If the registry has loaded and no provider is supported in this region,
  // deposits can't be offered here at all.
  final classified = ref.watch(businessPaymentProvidersProvider);
  if (classified.hasValue &&
      !classified.requireValue
          .any((e) => e.availability == ProviderAvailability.available)) {
    return DepositCapability.noRegionProvider;
  }
  final ready = ref.watch(depositReadyProvider).valueOrNull ?? false;
  return ready ? DepositCapability.enabled : DepositCapability.needsPayment;
});
