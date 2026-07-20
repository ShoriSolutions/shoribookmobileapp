import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/input_hints.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/availability_models.dart';
import '../../../models/staff_profile.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import '../application/staff_providers.dart';

final _staffDetailProvider = FutureProvider.autoDispose
    .family<(StaffProfile, List<StaffAvailability>), String>((ref, staffId) async {
      final repo = ref.watch(staffRepositoryProvider);
      final results = await Future.wait([
        repo.fetchById(staffId),
        repo.fetchAvailability(staffId),
      ]);
      return (
        results[0] as StaffProfile,
        results[1] as List<StaffAvailability>,
      );
    });

class StaffDetailScreen extends ConsumerWidget {
  final String staffId;

  const StaffDetailScreen({super.key, required this.staffId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(_staffDetailProvider(staffId));
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final canManage =
        membership != null && can(membership.role, Permission.manageStaff);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff member'),
        actions: [
          if (canManage)
            asyncData.maybeWhen(
              data: (data) => IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showEditSheet(context, ref, data.$1),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => ErrorRetryView(
          message: 'Could not load this staff member.',
          onRetry: () => ref.invalidate(_staffDetailProvider(staffId)),
        ),
        data: (data) {
          final staff = data.$1;
          final availability = data.$2;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.sageLight,
                    foregroundColor: AppColors.sageDark,
                    backgroundImage: staff.profileImageUrl != null
                        ? NetworkImage(staff.profileImageUrl!)
                        : null,
                    child: staff.profileImageUrl == null
                        ? Text(
                            staff.name.isNotEmpty
                                ? staff.name[0].toUpperCase()
                                : '?',
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (staff.roles.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final r in staff.roles)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.sageLight,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(r,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.sageDark)),
                                  ),
                              ],
                            ),
                          )
                        else if (staff.role != null)
                          Text(staff.role!),
                      ],
                    ),
                  ),
                ],
              ),
              if ((staff.bio ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(staff.bio!),
              ],
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (staff.phone != null) Text('Phone: ${staff.phone}'),
                      if (staff.email != null) Text('Email: ${staff.email}'),
                      if (staff.instagramUrl != null)
                        Text('Instagram: ${staff.instagramUrl}'),
                      Text(staff.isActive ? 'Active' : 'Inactive'),
                      Text(
                        staff.isBookable ? 'Bookable' : 'Not bookable',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Weekly schedule', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              if (availability.isEmpty)
                Text(
                  "No custom schedule set — follows the business's default hours.",
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final a in availability)
                        ListTile(
                          title: Text(weekdayLabels[a.dayOfWeek]),
                          trailing: Text(
                            a.isAvailable
                                ? '${a.startTime.substring(0, 5)} – ${a.endTime.substring(0, 5)}'
                                : 'Off',
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditSheet(
    BuildContext context,
    WidgetRef ref,
    StaffProfile staff,
  ) async {
    final nameController = TextEditingController(text: staff.name);
    final customRoleController = TextEditingController();
    final bioController = TextEditingController(text: staff.bio ?? '');
    final phoneController = TextEditingController(text: staff.phone ?? '');
    final roles = {...staff.roles};
    bool isActive = staff.isActive;
    bool isBookable = staff.isBookable;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit staff member', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                const Text('Job roles',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in {..._suggestedRoles, ...roles})
                      _RoleChip(
                        label: r,
                        selected: roles.contains(r),
                        onTap: () => setState(() =>
                            roles.contains(r) ? roles.remove(r) : roles.add(r)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customRoleController,
                        decoration: const InputDecoration(
                            labelText: 'Add a custom role'),
                        onSubmitted: (_) {
                          final v = customRoleController.text.trim();
                          if (v.isNotEmpty) {
                            setState(() => roles.add(v));
                            customRoleController.clear();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: AppColors.sage),
                      onPressed: () {
                        final v = customRoleController.text.trim();
                        if (v.isNotEmpty) {
                          setState(() => roles.add(v));
                          customRoleController.clear();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    hintText: kPhoneHint,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setState(() => isActive = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bookable'),
                  value: isBookable,
                  onChanged: (v) => setState(() => isBookable = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final membership = ref.read(
                          activeMembershipProvider,
                        ).valueOrNull;
                        if (membership == null) return;
                        final updated = StaffProfile(
                          id: staff.id,
                          businessId: staff.businessId,
                          memberId: staff.memberId,
                          name: nameController.text.trim(),
                          role: roles.isEmpty ? null : roles.first,
                          roles: roles.toList(),
                          bio: bioController.text.trim().isEmpty
                              ? null
                              : bioController.text.trim(),
                          profileImageUrl: staff.profileImageUrl,
                          email: staff.email,
                          phone: phoneController.text.trim().isEmpty
                              ? null
                              : phoneController.text.trim(),
                          instagramUrl: staff.instagramUrl,
                          isActive: isActive,
                          isBookable: isBookable,
                          displayOrder: staff.displayOrder,
                        );
                        await ref
                            .read(staffRepositoryProvider)
                            .update(staff.id, updated, membership.business.id);
                        ref.invalidate(_staffDetailProvider(staff.id));
                        ref.invalidate(staffListProvider);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      } catch (e) {
                        if (ctx.mounted) {
                          showAppSnackBar(
                            ctx,
                            message: AppException.from(e).message,
                            isError: true,
                          );
                        }
                      }
                    },
                    child: const Text('Save changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Common job roles suggested to owners; they can also add custom ones.
/// A base for future role-based permissions.
const _suggestedRoles = <String>[
  'Barber',
  'Hair Stylist',
  'Nail Technician',
  'Lash Artist',
  'Brow Artist',
  'Esthetician',
  'Massage Therapist',
  'Makeup Artist',
  'Personal Trainer',
  'Receptionist',
];

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.sage : AppColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? AppColors.sage : AppColors.parchment),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 15, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.ink)),
          ],
        ),
      ),
    );
  }
}
