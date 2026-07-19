import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/business.dart';
import '../../../routing/route_paths.dart';
import '../../auth/application/auth_providers.dart';
import '../../marketplace/presentation/widgets/category_visuals.dart';
import '../application/favorites_providers.dart';
import 'widgets/favorite_button.dart';

/// C11 · Favourites — a 2-col grid of saved businesses (gradient cover,
/// filled heart), reached from Profile. Signing in syncs across devices.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStatus = ref.watch(authStatusProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(RoutePaths.account),
                  ),
                  const SizedBox(width: 4),
                  const Text('Favourites',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                ],
              ),
            ),
            Expanded(
              child: authStatus != AuthStatus.authenticated
                  ? const EmptyState(
                      icon: '🤍',
                      title: 'Sign in to see your favourites',
                      message: 'Save businesses you love and find them here.',
                    )
                  : Consumer(
                      builder: (context, ref, _) {
                        final favoritesAsync =
                            ref.watch(favoriteBusinessesProvider);
                        return RefreshIndicator(
                          onRefresh: () =>
                              ref.refresh(favoriteBusinessesProvider.future),
                          child: favoritesAsync.when(
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
                            error: (err, st) => ListView(children: [
                              const SizedBox(height: 80),
                              ErrorRetryView(
                                message: 'Could not load your favourites.',
                                onRetry: () => ref
                                    .invalidate(favoriteBusinessesProvider),
                              ),
                            ]),
                            data: (businesses) {
                              if (businesses.isEmpty) {
                                return ListView(children: const [
                                  SizedBox(height: 60),
                                  EmptyState(
                                    icon: '🤍',
                                    title: 'No favourites yet',
                                    message:
                                        'Tap the heart on a business to save it here.',
                                  ),
                                ]);
                              }
                              return GridView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 0.82,
                                ),
                                itemCount: businesses.length,
                                itemBuilder: (context, i) =>
                                    _FavTile(business: businesses[i]),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavTile extends StatelessWidget {
  const _FavTile({required this.business});
  final Business business;

  @override
  Widget build(BuildContext context) {
    final visual = CategoryVisual.of(business.category);
    return GestureDetector(
      onTap: () => context.push(RoutePaths.businessProfile(business.slug)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.parchment),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18)),
                      child: business.coverImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: business.coverImageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (c, u, e) => _grad(visual),
                            )
                          : _grad(visual),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: FavoriteButton(business: business),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(business.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (business.category != null)
                        BusinessCategory.labelFor(business.category)
                            .split(' / ')
                            .first,
                      business.address,
                    ]
                        .where((s) => s != null && s.trim().isNotEmpty)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grad(CategoryVisual visual) {
    return Container(
      decoration: BoxDecoration(gradient: visual.gradient),
      alignment: Alignment.center,
      child: Icon(visual.icon, color: Colors.white, size: 40),
    );
  }
}
