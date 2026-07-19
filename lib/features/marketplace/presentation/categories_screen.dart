import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/route_paths.dart';
import '../application/marketplace_providers.dart';
import 'widgets/category_visuals.dart';

/// C10 · Categories — a 2-col grid of the vendor taxonomy, each tile
/// tinted in its category's accent with a live "N nearby" count. Tapping
/// a tile filters the marketplace home to that category.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  // Ordered to match the design handoff.
  static const _categories = <({String value, String label})>[
    (value: 'barber', label: 'Barbers'),
    (value: 'nail_tech', label: 'Nail techs'),
    (value: 'lash_artist', label: 'Lash artists'),
    (value: 'brow_artist', label: 'Brow artists'),
    (value: 'esthetician', label: 'Estheticians'),
    (value: 'hair_stylist', label: 'Hair stylists'),
    (value: 'personal_trainer', label: 'Personal trainers'),
    (value: 'other', label: 'Everything else'),
  ];

  void _open(BuildContext context, WidgetRef ref, String value) {
    ref.read(selectedCategoryProvider.notifier).state = value;
    ref.read(searchQueryProvider.notifier).state = '';
    context.go(RoutePaths.discover);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(categoryCountsProvider).valueOrNull ?? const {};

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Categories',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppColors.ink)),
                    SizedBox(height: 2),
                    Text('Browse by what you need',
                        style: TextStyle(fontSize: 15, color: AppColors.muted)),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.92,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final c = _categories[i];
                    return _CategoryTile(
                      label: c.label,
                      visual: CategoryVisual.of(c.value),
                      count: counts[c.value] ?? 0,
                      onTap: () => _open(context, ref, c.value),
                    );
                  },
                  childCount: _categories.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.visual,
    required this.count,
    required this.onTap,
  });

  final String label;
  final CategoryVisual visual;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: visual.tint,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(visual.icon, size: 30, color: visual.accent),
              const Spacer(),
              Text(label,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              const SizedBox(height: 2),
              Text('$count nearby',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: visual.accent)),
            ],
          ),
        ),
      ),
    );
  }
}
