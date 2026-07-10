import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../marketplace/presentation/widgets/business_card.dart';
import '../application/favorites_providers.dart';
import 'widgets/favorite_button.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStatus = ref.watch(authStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: authStatus != AuthStatus.authenticated
          ? const EmptyState(
              icon: '♡',
              title: 'Sign in to see your favorites',
              message: 'Save businesses you love and find them here.',
            )
          : Consumer(
              builder: (context, ref, _) {
                final favoritesAsync = ref.watch(favoriteBusinessesProvider);
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(favoriteBusinessesProvider.future),
                  child: favoritesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, st) => ListView(
                      children: [
                        const SizedBox(height: 80),
                        ErrorRetryView(
                          message: 'Could not load your favorites.',
                          onRetry: () =>
                              ref.invalidate(favoriteBusinessesProvider),
                        ),
                      ],
                    ),
                    data: (businesses) {
                      if (businesses.isEmpty) {
                        return ListView(
                          children: const [
                            SizedBox(height: 60),
                            EmptyState(
                              icon: '♡',
                              title: 'No favorites yet',
                              message:
                                  'Tap the heart on a business to save it here.',
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
                          favoriteButton: FavoriteButton(
                            business: businesses[i],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
