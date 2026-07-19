import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/open_now.dart';
import '../../../models/availability_models.dart';
import '../../../models/business.dart';
import '../../../models/service.dart';
import '../../../models/staff_profile.dart';
import '../data/marketplace_repository.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository(ref.watch(supabaseClientProvider));
});

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// The customer's current location when "Near me" is on (null when off).
/// Results are sorted by distance to this point.
final customerLocationProvider =
    StateProvider<({double lat, double lng})?>((ref) => null);

/// Debounced so typing doesn't fire a query per keystroke.
final searchResultsProvider = FutureProvider.autoDispose<List<Business>>((
  ref,
) async {
  final query = ref.watch(searchQueryProvider);
  final category = ref.watch(selectedCategoryProvider);

  // A new query supersedes an in-flight one (Riverpod discards the stale
  // AsyncValue), so a plain delay is sufficient debouncing — no manual
  // Timer/cancellation bookkeeping needed.
  if (query.trim().isNotEmpty) {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  return ref
      .watch(marketplaceRepositoryProvider)
      .search(query: query, category: category);
});

/// Map of business id -> whether it's open right now, for the current
/// search results. Only businesses whose open/closed state is known (they
/// have hours on record) appear; callers hide the chip for the rest.
/// Loaded separately from [searchResultsProvider] so the list paints
/// immediately and the status chips fill in a moment later.
final marketplaceOpenNowProvider =
    FutureProvider.autoDispose<Map<String, bool>>((ref) async {
  final businesses = await ref.watch(searchResultsProvider.future);
  if (businesses.isEmpty) return const {};
  final hoursByBiz = await ref
      .watch(marketplaceRepositoryProvider)
      .fetchHoursForBusinessIds(businesses.map((b) => b.id).toList());
  final result = <String, bool>{};
  for (final b in businesses) {
    final open = isOpenNow(hoursByBiz[b.id] ?? const [], b.timezone);
    if (open != null) result[b.id] = open;
  }
  return result;
});

/// Count of discoverable businesses per category value, for the
/// Categories tab's "N nearby" labels.
final categoryCountsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  return ref.watch(marketplaceRepositoryProvider).fetchCategoryCounts();
});

class BusinessProfileData {
  final Business business;
  final List<Service> services;
  final List<StaffProfile> staff;
  final List<BusinessHours> hours;
  final Map<String, Set<String>> serviceStaffLinks;

  const BusinessProfileData({
    required this.business,
    required this.services,
    required this.staff,
    required this.hours,
    required this.serviceStaffLinks,
  });
}

final businessProfileProvider = FutureProvider.autoDispose
    .family<BusinessProfileData?, String>((ref, slug) async {
      final repo = ref.watch(marketplaceRepositoryProvider);
      final business = await repo.fetchBySlug(slug);
      if (business == null) return null;

      final results = await Future.wait([
        repo.fetchServices(business.id),
        repo.fetchStaff(business.id),
        repo.fetchBusinessHours(business.id),
        repo.fetchServiceStaffLinks(business.id),
      ]);

      return BusinessProfileData(
        business: business,
        services: results[0] as List<Service>,
        staff: results[1] as List<StaffProfile>,
        hours: results[2] as List<BusinessHours>,
        serviceStaffLinks: results[3] as Map<String, Set<String>>,
      );
    });
