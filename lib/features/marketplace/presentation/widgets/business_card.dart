import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/location_service.dart';
import '../../../../models/business.dart';
import '../../../../routing/route_paths.dart';

/// The marketplace business card — used on Discover and Favorites.
/// [favoriteButton] is a slot (not hardcoded to the favorites feature)
/// so this widget has no dependency on that feature's providers.
class BusinessCard extends StatelessWidget {
  final Business business;
  final Widget? favoriteButton;

  /// Straight-line distance to the customer, in metres, when "Near me"
  /// is on. Shown as a small label; null hides it.
  final double? distanceMeters;

  const BusinessCard({
    super.key,
    required this.business,
    this.favoriteButton,
    this.distanceMeters,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push(RoutePaths.businessProfile(business.slug)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: business.coverImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: business.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (c, u, e) => _fallbackCover(),
                        )
                      : _fallbackCover(),
                ),
                if (favoriteButton != null)
                  Positioned(top: 8, right: 8, child: favoriteButton!),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (distanceMeters != null)
                        '📍 ${formatDistance(distanceMeters!)}',
                      business.category?.replaceAll('_', ' '),
                      business.address,
                    ].where((s) => s != null && s.isNotEmpty).join(' · '),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.ink, AppColors.sageDark],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        business.name.isNotEmpty ? business.name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
