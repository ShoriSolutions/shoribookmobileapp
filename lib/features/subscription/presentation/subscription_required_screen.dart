import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../models/trial_eligibility.dart';
import '../../../routing/route_paths.dart';
import '../../auth/application/auth_providers.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import '../application/subscription_providers.dart';
import 'subscription_modal.dart';

/// Hard gate shown to a business owner/staff whose trial has ended (or who
/// never started one) and has no active subscription. The router keeps them
/// here until they start a trial or subscribe.
class SubscriptionRequiredScreen extends ConsumerStatefulWidget {
  const SubscriptionRequiredScreen({super.key});

  @override
  ConsumerState<SubscriptionRequiredScreen> createState() =>
      _SubscriptionRequiredScreenState();
}

class _SubscriptionRequiredScreenState
    extends ConsumerState<SubscriptionRequiredScreen> {
  bool _busy = false;

  Future<void> _startTrial(String businessId) async {
    setState(() => _busy = true);
    try {
      final res =
          await ref.read(subscriptionRepositoryProvider).startTrial(businessId);
      if (!mounted) return;
      if (res.status == TrialStatus.trialing) {
        // Access granted — the router reroutes to the dashboard.
        ref.invalidate(activeMembershipProvider);
      } else {
        showAppSnackBar(context, message: res.message);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    if (membership == null) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final business = membership.business;
    final canBill = can(membership.role, Permission.manageBilling);
    final neverTrialed = business.subscriptionStatus == 'none';

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.sageLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium_outlined,
                      size: 40, color: AppColors.sageDark),
                ),
                const SizedBox(height: 20),
                Text(
                  !canBill
                      ? 'Subscription needed'
                      : neverTrialed
                          ? 'Start your free trial'
                          : 'Your free trial has ended',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  !canBill
                      ? "This business's ShoriBooks subscription has ended. "
                          'Please ask the owner to renew to continue.'
                      : neverTrialed
                          ? 'Get 14 days of full access to everything — no card '
                              'needed to start.'
                          : 'Subscribe to keep managing your bookings, clients '
                              'and schedule.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 28),

                if (canBill) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _busy
                          ? null
                          : neverTrialed
                              ? () => _startTrial(business.id)
                              : () => showSubscriptionModal(context),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(neverTrialed
                              ? 'Start 14-day free trial'
                              : 'Choose a plan'),
                    ),
                  ),
                  if (neverTrialed)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => showSubscriptionModal(context),
                      child: const Text('See all plans'),
                    ),
                ],

                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(RoutePaths.login),
                  child: const Text('Switch account'),
                ),
                TextButton(
                  onPressed: _signOut,
                  child: const Text('Sign out',
                      style: TextStyle(color: AppColors.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
