import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// A vertical list of "✓ feature" rows. Reused in the summary and inside
/// each pricing card.
class FeatureList extends StatelessWidget {
  const FeatureList({super.key, required this.features, this.color});

  final List<String> features;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.sage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in features)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: c),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(f, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
