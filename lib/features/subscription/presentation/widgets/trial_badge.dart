import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Prominent "✨ 30 DAYS FREE" pill on a soft accent background.
class TrialBadge extends StatelessWidget {
  const TrialBadge({super.key, this.label = '✨ 30 DAYS FREE'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.terracotta.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.terracotta,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
