import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bubble_background.dart';
import '../../../core/widgets/shori_logo.dart';

/// Shown while the router's redirect logic resolves the auth/session
/// state — never has its own navigation logic, just a branded loading
/// look: the same beige + frosted bubbles as the auth screens, with the
/// logo fading in on launch.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBubbleBeige,
      body: Stack(
        children: [
          const Positioned.fill(child: BubbleBackground()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.scale(
                        scale: 0.92 + 0.08 * value, child: child),
                  ),
                  // Deeper blue than the pale brand mark so it reads on the
                  // beige bubble field (matches the auth header).
                  child: const ShoriLogo(
                    markSize: 104,
                    color: Color(0xFF66A9CE),
                  ),
                ),
                const SizedBox(height: 44),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1600),
                  curve: Curves.easeIn,
                  builder: (context, value, child) =>
                      Opacity(opacity: value, child: child),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.sage,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
