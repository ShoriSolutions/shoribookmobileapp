import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../routing/route_paths.dart';
import '../../../routing/shell/nav_items.dart';
import '../../auth/application/auth_providers.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../subscription/presentation/subscription_modal.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static const Map<String, String> _routes = {
    'Staff': RoutePaths.staff,
    'Deposits': RoutePaths.deposits,
    'Reports': RoutePaths.reports,
    'Availability': RoutePaths.availability,
    'Profile & Marketplace': RoutePaths.profileMarketplace,
    'Reminders': RoutePaths.notificationSettings,
    'Help & Support': RoutePaths.support,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final role = membership?.role;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (membership != null)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.sageLight,
                  foregroundColor: AppColors.sageDark,
                  backgroundImage: membership.business.logoUrl != null
                      ? CachedNetworkImageProvider(membership.business.logoUrl!)
                      : null,
                  child: membership.business.logoUrl == null
                      ? Text(
                          membership.business.name.isNotEmpty
                              ? membership.business.name[0].toUpperCase()
                              : '?',
                        )
                      : null,
                ),
                title: Text(membership.business.name),
                subtitle: Text(membership.role.value),
              ),
            ),
          const SizedBox(height: 12),
          _GoPremiumCard(onTap: () => showSubscriptionModal(context)),
          const SizedBox(height: 4),
          for (final item in moreMenuItems)
            if (role == null || item.visibleFor(role))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(item.icon, style: const TextStyle(fontSize: 18)),
                  title: Text(item.label),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => context.push(_routes[item.label]!),
                ),
              ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Sign out'),
              onTap: () => _signOut(context, ref),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever_outlined,
                  color: AppColors.danger),
              title: const Text(
                'Delete account',
                style: TextStyle(color: AppColors.danger),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () => context.push(RoutePaths.deleteAccount),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
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
  }
}

/// Upgrade entry point — opens the premium subscription modal.
class _GoPremiumCard extends StatelessWidget {
  const _GoPremiumCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.sage,
                AppColors.sageDark,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Go Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Start your 30-day free trial',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
