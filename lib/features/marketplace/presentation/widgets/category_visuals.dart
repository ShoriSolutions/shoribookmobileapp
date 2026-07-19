import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// The three placeholder cover gradients from the design system
/// (README → Assets). Real vendor photos replace the gradient when present.
enum CoverGradient { sage, terracotta, blue }

const _sageGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF7A9E8C), Color(0xFF5C8070)],
);
const _terracottaGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFE39A72), Color(0xFFD97A4F)],
);
const _blueGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFBADAEA), Color(0xFFA3D0E6)],
);

/// The visual identity for a business/service category: a Lucide-style
/// line icon plus its cover gradient and tinted-tile accent, so covers,
/// avatars and category tiles stay consistent across the marketplace.
class CategoryVisual {
  final IconData icon;
  final LinearGradient gradient;

  /// Accent colour a line icon takes on a tinted category tile.
  final Color accent;

  /// Pastel background for a tinted category tile.
  final Color tint;

  const CategoryVisual({
    required this.icon,
    required this.gradient,
    required this.accent,
    required this.tint,
  });

  static const _sage = CategoryVisual(
    icon: Icons.content_cut,
    gradient: _sageGradient,
    accent: AppColors.sageDark,
    tint: AppColors.sageLight,
  );

  static const _map = <String, CategoryVisual>{
    'barber': CategoryVisual(
      icon: Icons.content_cut,
      gradient: _sageGradient,
      accent: AppColors.sageDark,
      tint: AppColors.sageLight,
    ),
    'nail_tech': CategoryVisual(
      icon: Icons.brush_outlined,
      gradient: _terracottaGradient,
      accent: AppColors.terracottaDeep,
      tint: AppColors.terracottaTint,
    ),
    'lash_artist': CategoryVisual(
      icon: Icons.remove_red_eye_outlined,
      gradient: _blueGradient,
      accent: Color(0xFF3E7A96),
      tint: Color(0xFFE7F2F8),
    ),
    'brow_artist': CategoryVisual(
      icon: Icons.auto_awesome_outlined,
      gradient: _terracottaGradient,
      accent: AppColors.terracottaDeep,
      tint: AppColors.terracottaTint,
    ),
    'esthetician': CategoryVisual(
      icon: Icons.spa_outlined,
      gradient: _sageGradient,
      accent: AppColors.sageDark,
      tint: AppColors.sageLight,
    ),
    'hair_stylist': CategoryVisual(
      icon: Icons.content_cut,
      gradient: _blueGradient,
      accent: Color(0xFF3E7A96),
      tint: Color(0xFFE7F2F8),
    ),
    'personal_trainer': CategoryVisual(
      icon: Icons.fitness_center,
      gradient: _terracottaGradient,
      accent: AppColors.terracottaDeep,
      tint: AppColors.terracottaTint,
    ),
    'other': CategoryVisual(
      icon: Icons.storefront_outlined,
      gradient: _sageGradient,
      accent: AppColors.sageDark,
      tint: AppColors.sageLight,
    ),
  };

  /// The visual for a category value (e.g. 'barber'); falls back to a
  /// neutral sage storefront for unknown/null values.
  static CategoryVisual of(String? category) => _map[category] ?? _sage;
}
