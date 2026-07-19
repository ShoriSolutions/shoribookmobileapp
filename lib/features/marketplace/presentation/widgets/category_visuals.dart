import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// The three placeholder cover gradients from the design system
/// (README → Assets). Real vendor photos replace the gradient when present.
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

const _blueAccent = Color(0xFF3E7A96);
const _blueTint = Color(0xFFE7F2F8);
const _neutralAccent = Color(0xFF9C8F77);
const _neutralTint = Color(0xFFF2EFE8);

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

  static const _fallback = CategoryVisual(
    icon: Icons.storefront_outlined,
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
      icon: Icons.diamond_outlined,
      gradient: _terracottaGradient,
      accent: AppColors.terracottaDeep,
      tint: AppColors.terracottaTint,
    ),
    'lash_artist': CategoryVisual(
      icon: Icons.remove_red_eye_outlined,
      gradient: _blueGradient,
      accent: _blueAccent,
      tint: _blueTint,
    ),
    'brow_artist': CategoryVisual(
      icon: Icons.auto_awesome_outlined,
      gradient: _terracottaGradient,
      accent: _neutralAccent,
      tint: _neutralTint,
    ),
    'esthetician': CategoryVisual(
      icon: Icons.eco_outlined,
      gradient: _sageGradient,
      accent: AppColors.sageDark,
      tint: AppColors.sageLight,
    ),
    'hair_stylist': CategoryVisual(
      icon: Icons.brush_outlined,
      gradient: _terracottaGradient,
      accent: AppColors.terracottaDeep,
      tint: AppColors.terracottaTint,
    ),
    'personal_trainer': CategoryVisual(
      icon: Icons.fitness_center,
      gradient: _blueGradient,
      accent: _blueAccent,
      tint: _blueTint,
    ),
    'other': CategoryVisual(
      icon: Icons.grid_view_outlined,
      gradient: _sageGradient,
      accent: _neutralAccent,
      tint: _neutralTint,
    ),
  };

  /// The visual for a category value (e.g. 'barber'); falls back to a
  /// neutral sage storefront for unknown/null values.
  static CategoryVisual of(String? category) => _map[category] ?? _fallback;
}
