import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/business.dart';
import '../../../../routing/route_paths.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/favorites_providers.dart';

/// Heart-toggle used on both BusinessCard and the business profile
/// screen. Prompts to log in rather than silently failing when the
/// viewer is browsing anonymously — favoriting requires an identity.
class FavoriteButton extends ConsumerWidget {
  final Business business;

  const FavoriteButton({super.key, required this.business});

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    if (ref.read(authStatusProvider) != AuthStatus.authenticated) {
      context.push(RoutePaths.login);
      return;
    }
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;

    final idsAsync = ref.read(favoriteBusinessIdsProvider);
    final isFavorite = idsAsync.valueOrNull?.contains(business.id) ?? false;
    final repo = ref.read(favoritesRepositoryProvider);

    try {
      if (isFavorite) {
        await repo.removeFavorite(userId: userId, businessId: business.id);
      } else {
        await repo.addFavorite(userId: userId, businessId: business.id);
      }
      ref.invalidate(favoriteBusinessIdsProvider);
      ref.invalidate(favoriteBusinessesProvider);
    } catch (_) {
      // Silent — the heart simply won't have visibly toggled, which is
      // feedback enough for a low-stakes action like this.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idsAsync = ref.watch(favoriteBusinessIdsProvider);
    final isFavorite = idsAsync.valueOrNull?.contains(business.id) ?? false;

    return InkWell(
      onTap: () => _toggle(context, ref),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 18,
          color: isFavorite ? AppColors.danger : AppColors.muted,
        ),
      ),
    );
  }
}
