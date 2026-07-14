import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The ShoriBooks brand lockup — the "S" mark plus the "ShoriBooks"
/// wordmark. The mark asset is a single-colour shape on transparency, so
/// passing [color] recolours it (e.g. white on a dark header) while
/// keeping its alpha. Reused on the splash, login, and registration
/// screens.
class ShoriLogo extends StatelessWidget {
  const ShoriLogo({
    super.key,
    this.markSize = 72,
    this.color,
    this.showWordmark = true,
  });

  /// Width/height of the square mark. The wordmark scales from it.
  final double markSize;

  /// Recolours the mark and wordmark. Null keeps the mark's brand blue and
  /// draws the wordmark in brand blue.
  final Color? color;

  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final wordColor = color ?? AppColors.shoriBlue;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/branding/shoribookslogo.png',
          width: markSize,
          height: markSize,
          fit: BoxFit.contain,
          color: color,
          colorBlendMode: color != null ? BlendMode.srcIn : null,
        ),
        if (showWordmark) ...[
          SizedBox(height: markSize * 0.12),
          Text(
            'ShoriBooks',
            style: TextStyle(
              fontSize: markSize * 0.28,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: wordColor,
            ),
          ),
        ],
      ],
    );
  }
}
