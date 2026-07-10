import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Shown while the router's redirect logic resolves the auth/session
/// state — never has its own navigation logic, just a loading look.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.sage,
        ),
      ),
    );
  }
}
