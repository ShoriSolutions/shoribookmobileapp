import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/shori_logo.dart';
import '../../../models/business.dart';
import '../../../routing/route_paths.dart';
import '../../auth/application/auth_providers.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import '../../staff/application/staff_providers.dart';

/// V12 · More — the hub for everything that isn't day-to-day. Business
/// card, then grouped Business / Grow / Account menus with the trial state
/// surfaced on Subscription.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final role = membership?.role;
    final business = membership?.business;
    final isAdmin = role != null && can(role, Permission.manageSettings);
    final canBill = role != null && can(role, Permission.manageBilling);
    final staffCount = ref.watch(staffListProvider).valueOrNull?.length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const Text('More',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.ink)),
            const SizedBox(height: 16),
            if (business != null) _businessCard(context, business),
            const SizedBox(height: 20),
            if (isAdmin) ...[
              const _GroupLabel('Business'),
              _MenuCard(rows: [
                _MenuRow(
                  icon: Icons.groups_outlined,
                  title: 'Staff',
                  subtitle: staffCount != null ? '$staffCount active' : null,
                  onTap: () => context.push(RoutePaths.staff),
                ),
                _MenuRow(
                  icon: Icons.access_time,
                  title: 'Availability',
                  subtitle: 'Working hours & rules',
                  onTap: () => context.push(RoutePaths.availability),
                ),
                _MenuRow(
                  icon: Icons.credit_card_outlined,
                  title: 'Deposits & payments',
                  subtitle: 'No-show protection',
                  onTap: () => context.push(RoutePaths.deposits),
                ),
                _MenuRow(
                  icon: Icons.storefront_outlined,
                  title: 'Marketplace profile',
                  subtitle: business != null && business.isMarketplaceListed
                      ? 'Live'
                      : 'Not listed',
                  onTap: () => context.push(RoutePaths.profileMarketplace),
                ),
              ]),
              const SizedBox(height: 20),
              const _GroupLabel('Grow'),
              _MenuCard(rows: [
                _MenuRow(
                  icon: Icons.show_chart,
                  title: 'Reports',
                  subtitle: 'Revenue & metrics',
                  onTap: () => context.push(RoutePaths.reports),
                ),
                _MenuRow(
                  icon: Icons.notifications_none,
                  title: 'Reminders & automations',
                  subtitle: 'WhatsApp reminders',
                  onTap: () => context.push(RoutePaths.notificationSettings),
                ),
              ]),
              const SizedBox(height: 20),
            ],
            const _GroupLabel('Account'),
            _MenuCard(rows: [
              if (canBill)
                _MenuRow(
                  icon: Icons.workspace_premium_outlined,
                  iconTint: business?.subscriptionStatus == 'trialing'
                      ? AppColors.terracottaTint
                      : AppColors.sageLight,
                  iconColor: business?.subscriptionStatus == 'trialing'
                      ? AppColors.terracottaDeep
                      : AppColors.sageDark,
                  title: 'Subscription',
                  subtitle: _subLabel(business),
                  subtitleColor: business?.subscriptionStatus == 'trialing'
                      ? AppColors.terracottaDeep
                      : null,
                  onTap: () => context.push(RoutePaths.subscription),
                ),
              _MenuRow(
                icon: Icons.help_outline,
                title: 'Help & support',
                onTap: () => context.push(RoutePaths.support),
              ),
              _MenuRow(
                icon: Icons.logout,
                iconTint: const Color(0xFFF7ECE9),
                iconColor: AppColors.danger,
                title: 'Log out',
                danger: true,
                onTap: () => _signOut(context, ref),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String? _subLabel(Business? b) {
    if (b == null) return null;
    switch (b.subscriptionStatus) {
      case 'trialing':
        final d = b.trialEndsAt?.difference(DateTime.now()).inDays;
        return d != null ? 'Trial · $d days left' : 'Free trial';
      case 'active':
        return 'Active';
      case 'past_due':
        return 'Payment due';
      default:
        return 'Choose a plan';
    }
  }

  Widget _businessCard(BuildContext context, Business business) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.sageLight,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const ShoriLogo(markSize: 30, showWordmark: false),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(business.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (business.category != null)
                      BusinessCategory.labelFor(business.category)
                          .split(' / ')
                          .first,
                    business.address,
                  ]
                      .where((s) => s != null && s.trim().isNotEmpty)
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                context.push(RoutePaths.previewBusiness(business.slug)),
            child: const Text('View listing',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.sageDark)),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: "You'll need to log in again to access your dashboard.",
      confirmLabel: 'Log out',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    }
  }
}

// ── Grouped menu pieces (shared visual with the customer profile) ──────

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

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.rows});
  final List<_MenuRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: AppColors.divider, indent: 60),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.subtitleColor,
    this.iconTint = AppColors.sageLight,
    this.iconColor = AppColors.sageDark,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;
  final Color iconTint;
  final Color iconColor;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconTint, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: danger ? AppColors.danger : AppColors.ink)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: subtitleColor != null
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: subtitleColor ?? AppColors.muted)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}
