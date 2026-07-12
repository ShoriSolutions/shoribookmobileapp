import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/business.dart';
import '../../favorites/presentation/widgets/favorite_button.dart';
import '../application/marketplace_providers.dart';
import 'widgets/business_card.dart';
import 'widgets/category_chip.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();
  bool _locating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleNearMe() async {
    // Already on? Turn it off.
    if (ref.read(customerLocationProvider) != null) {
      ref.read(customerLocationProvider.notifier).state = null;
      return;
    }
    setState(() => _locating = true);
    try {
      final loc = await getCurrentLocation();
      ref.read(customerLocationProvider.notifier).state = loc;
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: AppException.from(e).message,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final location = ref.watch(customerLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search businesses, services, or areas',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                CategoryChip(
                  label: _locating ? 'Locating…' : 'Near me',
                  emoji: '📍',
                  selected: location != null,
                  onTap: _locating ? () {} : _toggleNearMe,
                ),
                const SizedBox(width: 8),
                CategoryChip(
                  label: 'All',
                  emoji: '✦',
                  selected: selectedCategory == null,
                  onTap: () =>
                      ref.read(selectedCategoryProvider.notifier).state = null,
                ),
                const SizedBox(width: 8),
                for (final c in BusinessCategory.all) ...[
                  CategoryChip(
                    label: c.label,
                    emoji: c.emoji,
                    selected: selectedCategory == c.value,
                    onTap: () => ref
                            .read(selectedCategoryProvider.notifier)
                            .state =
                        selectedCategory == c.value ? null : c.value,
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(searchResultsProvider.future),
              child: resultsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    ErrorRetryView(
                      message: 'Could not load businesses.',
                      onRetry: () => ref.invalidate(searchResultsProvider),
                    ),
                  ],
                ),
                data: (businesses) {
                  if (businesses.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 60),
                        EmptyState(
                          icon: '🔍',
                          title: 'No businesses found',
                          message: 'Try a different search or category.',
                        ),
                      ],
                    );
                  }
                  final distances = <String, double>{};
                  var list = businesses;
                  if (location != null) {
                    for (final b in businesses) {
                      if (b.latitude != null && b.longitude != null) {
                        distances[b.id] = Geolocator.distanceBetween(
                          location.lat,
                          location.lng,
                          b.latitude!,
                          b.longitude!,
                        );
                      }
                    }
                    // Nearest first; businesses without coordinates go last.
                    list = [...businesses]..sort((a, b) {
                        final da = distances[a.id];
                        final db = distances[b.id];
                        if (da == null && db == null) return 0;
                        if (da == null) return 1;
                        if (db == null) return -1;
                        return da.compareTo(db);
                      });
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, i) => BusinessCard(
                      business: list[i],
                      favoriteButton: FavoriteButton(business: list[i]),
                      distanceMeters: distances[list[i].id],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
