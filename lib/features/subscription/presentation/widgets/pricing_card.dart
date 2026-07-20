import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/subscription_package.dart';

/// A selectable plan card. When selected it lifts (shadow), scales up a
/// touch, and highlights in the brand primary. Shows a "⭐ Most Popular"
/// ribbon when the package is flagged in the DB.
class PricingCard extends StatelessWidget {
  const PricingCard({
    super.key,
    required this.package,
    required this.selected,
    required this.onTap,
    required this.priceText,
    this.periodLabel,
  });

  final SubscriptionPackage package;
  final bool selected;
  final VoidCallback onTap;

  /// Resolved price string — the store's localized price if available,
  /// otherwise a formatted fallback from the DB.
  final String priceText;

  /// Overrides the package's own period label (e.g. "/year" for annual
  /// billing). Falls back to [SubscriptionPackage.periodLabel].
  final String? periodLabel;

  @override
  Widget build(BuildContext context) {
    const primary = AppColors.sage;
    return AnimatedScale(
      scale: selected ? 1.0 : 0.98,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? primary : AppColors.parchment,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? primary.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: selected ? 20 : 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          package.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (package.isPopular) const _PopularChip(),
                      const SizedBox(width: 8),
                      _RadioDot(selected: selected),
                    ],
                  ),
                  if (package.tagline != null &&
                      package.tagline!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      package.tagline!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        priceText,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        periodLabel ?? package.periodLabel,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopularChip extends StatelessWidget {
  const _PopularChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        '⭐ Most Popular',
        style: TextStyle(
          color: AppColors.sageDark,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.sage : AppColors.parchment,
          width: 2,
        ),
        color: selected ? AppColors.sage : Colors.transparent,
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}
