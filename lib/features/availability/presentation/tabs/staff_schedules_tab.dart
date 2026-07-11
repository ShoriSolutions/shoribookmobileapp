import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry_view.dart';
import '../../../staff/application/staff_providers.dart';
import '../staff_schedule_editor_screen.dart';

/// Lists the business's staff; tapping one opens their weekly
/// availability editor.
class StaffSchedulesTab extends ConsumerWidget {
  const StaffSchedulesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffListProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetryView(
        message: AppException.from(e).message,
        onRetry: () => ref.invalidate(staffListProvider),
      ),
      data: (staff) {
        if (staff.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No staff yet. Add team members from the Staff menu to set '
                'their schedules.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final s in staff)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.sageLight,
                    foregroundColor: AppColors.sageDark,
                    child: Text(
                      s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                    ),
                  ),
                  title: Text(s.name),
                  subtitle: Text(s.role ?? 'Staff'),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.muted,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StaffScheduleEditorScreen(
                        staffId: s.id,
                        staffName: s.name,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
