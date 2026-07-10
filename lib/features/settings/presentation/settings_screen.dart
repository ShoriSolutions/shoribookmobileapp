import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../auth/application/auth_providers.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';

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
                      'is available on the BetterBooking website.',
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
