import 'package:flutter/material.dart';

const Color kStarColor = Color(0xFFE8A33D);

/// Read-only star row (supports halves) with an optional trailing label.
class StarsRow extends StatelessWidget {
  const StarsRow({
    super.key,
    required this.rating,
    this.size = 16,
    this.color = kStarColor,
  });

  final double rating;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            rating >= i + 1
                ? Icons.star_rounded
                : rating >= i + 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_border_rounded,
            size: size,
            color: color,
          ),
      ],
    );
  }
}

/// Tappable 1-5 star input.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 44,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(),
            iconSize: size,
            onPressed: () => onChanged(i),
            icon: Icon(
              i <= value ? Icons.star_rounded : Icons.star_border_rounded,
              color: kStarColor,
            ),
          ),
      ],
    );
  }
}
