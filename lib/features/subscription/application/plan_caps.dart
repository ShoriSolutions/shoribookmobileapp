import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../business_context/application/active_business_provider.dart';
import 'subscription_providers.dart';

/// Per‑tier feature caps. During the free trial a business has **full
/// access to everything**; once on a paid plan these caps apply. Unknown or
/// legacy plans fall back to [unlimited] so nothing is ever wrongly blocked.
///
/// Enforced client‑side (this file) for good UX; treat as the display layer —
/// the authoritative limit for services is also enforced by a DB trigger
/// (see 20260720000004_service_plan_limit.sql).
class PlanCaps {
  /// Max active services (null = unlimited).
  final int? maxServices;

  /// Max bookable staff members.
  final int maxStaff;

  final bool deposits;
  final bool reports;
  final bool marketplaceListing;

  const PlanCaps({
    this.maxServices,
    this.maxStaff = 1,
    this.deposits = false,
    this.reports = false,
    this.marketplaceListing = false,
  });

  static const unlimited = PlanCaps(
    maxServices: null,
    maxStaff: 9999,
    deposits: true,
    reports: true,
    marketplaceListing: true,
  );

  /// Caps for a plan by its catalog name. Keep in sync with the
  /// subscription_packages rows (Side Hustle / Solo Pro / Squad).
  factory PlanCaps.forPlanName(String? name) {
    switch (name) {
      case 'Side Hustle':
        return const PlanCaps(maxServices: 5, maxStaff: 1);
      case 'Solo Pro':
        return const PlanCaps(
          maxServices: null,
          maxStaff: 1,
          deposits: true,
          reports: true,
          marketplaceListing: true,
        );
      case 'Squad':
        return const PlanCaps(
          maxServices: null,
          maxStaff: 5,
          deposits: true,
          reports: true,
          marketplaceListing: true,
        );
      default:
        return unlimited; // trial / unknown / legacy → don't block
    }
  }

  bool get servicesUnlimited => maxServices == null;
}

/// The active business's feature caps: full access during the trial, else
/// derived from the subscribed plan.
final activePlanCapsProvider = Provider<PlanCaps>((ref) {
  final business = ref.watch(activeMembershipProvider).valueOrNull?.business;
  if (business == null) return PlanCaps.unlimited;
  // Trial grants full access to everything.
  if (business.subscriptionStatus == 'trialing') return PlanCaps.unlimited;
  final packages =
      ref.watch(subscriptionPackagesProvider).valueOrNull ?? const [];
  String? name;
  for (final p in packages) {
    if (p.id == business.subscriptionPackageId) {
      name = p.name;
      break;
    }
  }
  return PlanCaps.forPlanName(name);
});
