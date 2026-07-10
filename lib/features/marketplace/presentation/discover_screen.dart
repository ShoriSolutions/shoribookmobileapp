import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

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
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: businesses.length,
                    itemBuilder: (context, i) => BusinessCard(
                      business: businesses[i],
                      favoriteButton: FavoriteButton(business: businesses[i]),
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
