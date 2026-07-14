import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shori_logo.dart';

/// Shown while the router's redirect logic resolves the auth/session
/// state — never has its own navigation logic, just a branded loading
/// look. The logo fades in on launch.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child:
                    Transform.scale(scale: 0.92 + 0.08 * value, child: child),
              ),
              child: const ShoriLogo(markSize: 104),
            ),
            const SizedBox(height: 44),
            // The app's standard loading indicator (same as the login
            // screen), fading in just after the logo.
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
    );
  }
}
