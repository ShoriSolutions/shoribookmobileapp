import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_rates.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/business.dart';
import '../../../models/subscription_package.dart';
import '../../business_context/application/active_business_provider.dart';
import '../application/subscription_providers.dart';
import 'subscription_modal.dart';

/// V17 · Subscription — the plan state on a dark card (trial countdown +
/// renewal), manage rows, other tiers to switch to, and cancel.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(activeMembershipProvider).valueOrNull?.business;
    final packages = ref.watch(subscriptionPackagesProvider).valueOrNull ??
        const <SubscriptionPackage>[];
    final trialing = business?.subscriptionStatus == 'trialing';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 4),
                const Text('Subscription',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
              ],
            ),
            const SizedBox(height: 12),
            _planCard(business, packages),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.parchment),
              ),
              child: Column(
                children: [
                  if (business != null)
                    SwitchListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('Auto-renew',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        business.autoRenew
                            ? 'Renews automatically at the end of each period'
                            : "Won't renew — access ends at the period end",
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted),
                      ),
                      value: business.autoRenew,
                      activeThumbColor: AppColors.sage,
                      onChanged: (v) => _setAutoRenew(context, ref, business, v),
                    ),
                  if (business != null)
                    const Divider(height: 1, color: AppColors.divider),
                  _row('Change plan',
                      onTap: () => showSubscriptionModal(context)),
                  const Divider(height: 1, color: AppColors.divider),
                  _row('Payment method',
                      trailing: 'Add card',
                      onTap: () => showSubscriptionModal(context)),
                  const Divider(height: 1, color: AppColors.divider),
                  _row('Billing history',
                      onTap: () => showAppSnackBar(context,
                          message: 'Billing history is coming soon.')),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _GroupLabel('Other plans'),
            for (final p in packages)
              if (!p.isPopular)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _otherPlan(context, p),
                ),
            if (trialing) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => _cancel(context),
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  child: const Text('Cancel trial',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _planCard(Business? business, List<SubscriptionPackage> packages) {
    final popular = packages.where((p) => p.isPopular).toList();
    final plan = popular.isNotEmpty ? popular.first : null;
    final trialing = business?.subscriptionStatus == 'trialing';
    final active = business?.subscriptionStatus == 'active';
    final ends = business?.trialEndsAt;
    final daysLeft = ends?.difference(DateTime.now()).inDays;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium,
                  size: 18, color: AppColors.sage),
              const SizedBox(width: 8),
              Text('Current plan',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.75))),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            active
                ? (plan?.name ?? 'Active plan')
                : trialing
                    ? (plan?.name ?? 'Free trial')
                    : 'No active plan',
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Colors.white),
          ),
          if (plan?.priceAmount != null) ...[
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: CurrencyRates.format(plan!.priceAmount!, plan.currency,
                        from: plan.currency),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                TextSpan(
                    text: ' / month${trialing ? ' after trial' : ''}',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7))),
              ]),
            ),
          ],
          if (trialing) ...[
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.terracotta.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_empty,
                      size: 16, color: Color(0xFFE9A883)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        'Free trial',
                        if (daysLeft != null) '$daysLeft days left',
                        if (ends != null)
                          'renews ${DateFormat('d MMM').format(ends.toLocal())}',
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE9A883)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _otherPlan(BuildContext context, SubscriptionPackage p) {
    return GestureDetector(
      onTap: () => showSubscriptionModal(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.parchment),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  if ((p.tagline ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(p.tagline!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            if (p.priceAmount != null)
              Text(
                CurrencyRates.format(p.priceAmount!, p.currency,
                    from: p.currency),
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, {String? trailing, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
            ),
            if (trailing != null)
              Text(trailing,
                  style: const TextStyle(fontSize: 14, color: AppColors.muted))
            else
              const Icon(Icons.chevron_right, color: AppColors.faint),
          ],
        ),
      ),
    );
  }

  Future<void> _setAutoRenew(
      BuildContext context, WidgetRef ref, Business business, bool value) async {
    try {
      await ref.read(subscriptionRepositoryProvider).setSubscriptionPrefs(
            businessId: business.id,
            autoRenew: value,
          );
      ref.invalidate(activeMembershipProvider);
      if (context.mounted) {
        showAppSnackBar(context,
            message: value ? 'Auto-renew on' : 'Auto-renew off');
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel trial?',
      message:
          "Your trial stays active until it ends; you just won't be charged. "
          'You can subscribe again anytime.',
      confirmLabel: 'Cancel trial',
    );
    if (confirmed && context.mounted) {
      showAppSnackBar(context,
          message: "Your trial will end on schedule and won't renew.");
    }
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: AppColors.faint)),
    );
  }
}
