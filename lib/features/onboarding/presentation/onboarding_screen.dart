import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shori_logo.dart';
import '../../../routing/route_paths.dart';
import '../application/onboarding_providers.dart';

/// C01 · First run — one light, skippable intro slide, then straight into
/// the marketplace. No pricing, no "about us" (those live on the website).
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  Future<void> _enterMarketplace(BuildContext context, WidgetRef ref) async {
    await completeOnboarding(ref);
    if (context.mounted) context.go(RoutePaths.discover);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 20, 0),
                child: TextButton(
                  onPressed: () => _enterMarketplace(context, ref),
                  child: const Text('Skip',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted)),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 34),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        color: AppColors.sageLight,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.sage.withValues(alpha: 0.18),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const ShoriLogo(markSize: 82, showWordmark: false),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Book local,\neffortlessly',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 29,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Barbers, nail techs, lash artists and more across '
                      'Barbados — booked in seconds. No account needed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16, height: 1.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 24),
              child: Column(
                children: [
                  const _Dots(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => _enterMarketplace(context, ref),
                      child: const Text('Explore the marketplace',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => context.push(RoutePaths.login),
                    child: const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                              text: 'Have an account? ',
                              style: TextStyle(color: AppColors.muted)),
                          TextSpan(
                              text: 'Log in',
                              style: TextStyle(
                                  color: AppColors.sageDark,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.terracotta,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 7),
        _dot(),
        const SizedBox(width: 7),
        _dot(),
      ],
    );
  }

  Widget _dot() => Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFFDCD6CB),
          shape: BoxShape.circle,
        ),
      );
}
