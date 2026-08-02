import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../routing/route_paths.dart';
import '../../auth/application/auth_providers.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import '../../payments/application/payment_providers.dart';
import '../../subscription/presentation/subscription_modal.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    if (membership == null) return const SizedBox.shrink();
    final business = membership.business;
    final canManage = can(membership.role, Permission.manageSettings);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(business.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  _Row('Category', business.category ?? '—'),
                  _Row('Phone', business.phone ?? '—'),
                  _Row('Email', business.email ?? '—'),
                  _Row('Address', business.address ?? '—'),
                  _Row('Timezone', business.timezone),
                  _Row('Currency', business.currency),
                  if (!canManage) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Ask an owner or admin to update business details.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'Full business profile editing (logo, hours, socials) '
                      'is available on the Shorivo website.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _DepositStatusCard(canManage: canManage),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Sign out'),
              onTap: () async {
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Sign out?',
                  message: "You'll need to log in again to access your dashboard.",
                  confirmLabel: 'Sign out',
                );
                if (!confirmed) return;
                try {
                  await ref.read(authRepositoryProvider).signOut();
                } catch (e) {
                  if (context.mounted) {
                    showAppSnackBar(
                      context,
                      message: AppException.from(e).message,
                      isError: true,
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// Current deposit capability: enabled, or disabled with the reason (FirstPay
/// setup, or a plan upgrade) and a shortcut to fix it.
class _DepositStatusCard extends ConsumerWidget {
  const _DepositStatusCard({required this.canManage});
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cap = ref.watch(depositCapabilityProvider);
    final enabled = cap == DepositCapability.enabled;

    final String? reason;
    final Widget? action;
    switch (cap) {
      case DepositCapability.enabled:
        reason = 'Customers can be asked for a deposit to secure a booking.';
        action = null;
      case DepositCapability.needsPayment:
        reason = 'FirstPay setup required before deposits can be enabled.';
        action = canManage
            ? TextButton(
                onPressed: () => context.push(RoutePaths.paymentSettings),
                child: const Text('Set up FirstPay'),
              )
            : null;
      case DepositCapability.needsPlan:
        reason = 'Upgrade to Solo Pro or higher to enable deposits.';
        action = canManage
            ? TextButton(
                onPressed: () => showSubscriptionModal(context),
                child: const Text('Upgrade'),
              )
            : null;
      case DepositCapability.noRegionProvider:
        reason = "Deposits aren't available in your country yet.";
        action = canManage
            ? TextButton(
                onPressed: () => context.push(RoutePaths.paymentSettings),
                child: const Text('Payment settings'),
              )
            : null;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(enabled ? Icons.circle : Icons.circle_outlined,
                    size: 14,
                    color: enabled ? AppColors.sage : AppColors.muted),
                const SizedBox(width: 8),
                Text(enabled ? 'Deposits Enabled' : 'Deposits Disabled',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
              ],
            ),
            const SizedBox(height: 6),
            Text(reason,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted)),
            if (action != null)
              Align(alignment: Alignment.centerLeft, child: action),
          ],
        ),
      ),
    );
  }
}
