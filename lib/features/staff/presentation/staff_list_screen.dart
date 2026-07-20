import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/staff_profile.dart';
import '../../../routing/route_paths.dart';
import '../../app_mode/application/app_mode_provider.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import '../application/staff_providers.dart';

class StaffListScreen extends ConsumerWidget {
  const StaffListScreen({super.key});

  Future<void> _makeSelfAvailable(BuildContext context, WidgetRef ref) async {
    final membership = ref.read(activeMembershipProvider).valueOrNull;
    if (membership == null) return;
    final name = ref.read(myProfileProvider).valueOrNull?.fullName ?? 'Me';
    try {
      await ref.read(staffRepositoryProvider).addSelfAsStaff(
            businessId: membership.business.id,
            memberId: membership.membershipId,
            name: name,
          );
      ref.invalidate(staffListProvider);
      ref.invalidate(activeMembershipProvider);
      if (context.mounted) {
        showAppSnackBar(context,
            message: "You're now bookable. Set your hours under Availability.");
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider);
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final canManage =
        membership != null && can(membership.role, Permission.manageStaff);
    // Owner/admin who isn't yet a bookable pro (no staff profile linked to
    // their membership) can add themselves.
    final canAddSelf = canManage && membership.staffProfileId == null;

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
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (canAddSelf)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SelfAvailabilityCard(
                      onTap: () => _makeSelfAvailable(context, ref),
                    ),
                  ),
                if (staff.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: '👥',
                      title: 'No staff added yet',
                      message: 'Add the people who work at your business.',
                    ),
                  )
                else
                  for (final s in staff)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _StaffTile(staff: s),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Prompt for an owner/admin who isn't yet a bookable pro to add
/// themselves so customers can book with them and they show as on duty.
class _SelfAvailabilityCard extends StatelessWidget {
  const _SelfAvailabilityCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sageTintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Take bookings yourself',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.sageDark)),
          const SizedBox(height: 2),
          const Text(
            'Add yourself as a bookable pro so customers can book with you '
            'and you show as on duty.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage),
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Make myself available',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
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
                      if (staff.roles.isNotEmpty)
                        Text(
                          staff.roles.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        )
                      else if (staff.role != null)
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
