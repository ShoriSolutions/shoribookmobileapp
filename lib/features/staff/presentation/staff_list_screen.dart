import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/staff_profile.dart';
import '../../../routing/route_paths.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import '../application/staff_providers.dart';

class StaffListScreen extends ConsumerWidget {
  const StaffListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider);
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final canManage =
        membership != null && can(membership.role, Permission.manageStaff);

    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.terracotta,
              onPressed: () => context.push(RoutePaths.staffInvite),
              icon: const Icon(Icons.person_add_alt, color: Colors.white),
              label: const Text(
                'Invite',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(staffListProvider.future),
        child: staffAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorRetryView(
                message: 'Could not load staff.',
                onRetry: () => ref.invalidate(staffListProvider),
              ),
            ],
          ),
          data: (staff) {
            if (staff.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: '◈',
                    title: 'No staff added yet',
                    message: 'Add the people who work at your business.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: staff.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _StaffTile(staff: staff[i]),
            );
          },
        ),
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  final StaffProfile staff;

  const _StaffTile({required this.staff});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(RoutePaths.staffDetail(staff.id)),
        child: Opacity(
          opacity: staff.isActive ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.sageLight,
                  foregroundColor: AppColors.sageDark,
                  backgroundImage: staff.profileImageUrl != null
                      ? NetworkImage(staff.profileImageUrl!)
                      : null,
                  child: staff.profileImageUrl == null
                      ? Text(staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?')
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (staff.role != null)
                        Text(
                          staff.role!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                    ],
                  ),
                ),
                if (!staff.isBookable)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text(
                      'Not bookable',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
