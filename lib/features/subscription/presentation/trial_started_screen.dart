import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/route_paths.dart';
import '../../business_context/application/active_business_provider.dart';

/// V03 · Trial started — success confirmation after starting the 14-day
/// free trial. Mirrors the app's success sheet: what's unlocked + days
/// left, then into the dashboard.
class TrialStartedScreen extends ConsumerWidget {
  const TrialStartedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(activeMembershipProvider).valueOrNull?.business;
    final daysLeft = business?.trialEndsAt != null
        ? business!.trialEndsAt!.difference(DateTime.now()).inDays.clamp(0, 14)
        : 14;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 550),
                curve: Curves.elasticOut,
                builder: (c, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                      color: AppColors.sage, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 50),
                ),
              ),
              const SizedBox(height: 20),
              const Text("You're all set!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.ink)),
              const SizedBox(height: 8),
              const Text(
                'Your 14-day trial is live — every premium feature unlocked. '
                'No charge until it ends.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.muted),
              ),
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.parchment),
                ),
                child: const Column(
                  children: [
                    _FeatureRow('Unlimited services & smart calendar'),
                    Divider(height: 1, color: AppColors.divider, indent: 52),
                    _FeatureRow('Deposits & no-show protection'),
                    Divider(height: 1, color: AppColors.divider, indent: 52),
                    _FeatureRow('Marketplace listing & reports'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.terracottaTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_empty,
                        size: 18, color: AppColors.terracottaDeep),
                    const SizedBox(width: 10),
                    Text("$daysLeft days left · we'll remind you before it ends",
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.terracottaDeep)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => context.go(RoutePaths.home),
                  child: const Text('Go to dashboard',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.check, size: 20, color: AppColors.sage),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
          ),
        ],
      ),
    );
  }
}
