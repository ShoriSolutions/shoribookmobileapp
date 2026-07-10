import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/route_paths.dart';
import '../../../routing/shell/nav_items.dart';
import '../../business_context/application/active_business_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static const Map<String, String> _routes = {
    'Staff': RoutePaths.staff,
    'Deposits': RoutePaths.deposits,
    'Reports': RoutePaths.reports,
    'Booking Link': RoutePaths.bookingLink,
    'Settings': RoutePaths.settings,
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
                  child: Text(
                    membership.business.name.isNotEmpty
                        ? membership.business.name[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(membership.business.name),
                subtitle: Text(membership.role.value),
              ),
            ),
          const SizedBox(height: 12),
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
        ],
      ),
    );
  }
}
