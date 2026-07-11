import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/timezone_offsets.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/error_retry_view.dart';
import '../../../../models/availability_models.dart';
import '../../../business_context/application/active_business_provider.dart';
import '../../../business_context/application/permissions.dart';
import '../../application/availability_providers.dart';

/// One-off blocked-time ranges (holidays, appointments elsewhere, etc.)
/// that make the whole business unavailable for that window.
class BlockedTimeTab extends ConsumerWidget {
  const BlockedTimeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final canManage =
        membership != null && can(membership.role, Permission.manageSettings);
    final async = ref.watch(blockedTimesProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetryView(
        message: AppException.from(e).message,
        onRetry: () => ref.invalidate(blockedTimesProvider),
      ),
      data: (blocks) {
        if (membership == null) return const SizedBox.shrink();
        final tz = membership.business.timezone;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (canManage)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showAdd(context, ref, membership.business.id, tz),
                  icon: const Icon(Icons.add),
                  label: const Text('Add blocked time'),
                ),
              ),
            if (blocks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No blocked time.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                ),
              )
            else
              for (final b in blocks)
                _BlockCard(
                  block: b,
                  timezone: tz,
                  canDelete: canManage,
                  onDelete: () => _delete(context, ref, b.id),
                ),
          ],
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(availabilityRepositoryProvider).deleteBlockedTime(id);
      ref.invalidate(blockedTimesProvider);
      if (context.mounted) showAppSnackBar(context, message: 'Removed');
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

  Future<void> _showAdd(
    BuildContext context,
    WidgetRef ref,
    String businessId,
    String timezone,
  ) async {
    DateTime date = DateTime.now();
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 10, minute: 0);
    final reason = TextEditingController();
    bool saving = false;

    String hhmm(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            Future<void> submit() async {
              if (end.hour * 60 + end.minute <= start.hour * 60 + start.minute) {
                showAppSnackBar(
                  sheetContext,
                  message: 'End time must be after start time',
                  isError: true,
                );
                return;
              }
              // Interpret the picked date/time as BUSINESS-local (not the
              // device's zone) and convert to the UTC instant we store.
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              final startUtc = businessLocalToUtc(
                date: dateStr,
                time: hhmm(start),
                timezone: timezone,
              );
              final endUtc = businessLocalToUtc(
                date: dateStr,
                time: hhmm(end),
                timezone: timezone,
              );
              setSheet(() => saving = true);
              try {
                await ref.read(availabilityRepositoryProvider).addBlockedTime(
                      businessId: businessId,
                      start: startUtc,
                      end: endUtc,
                      reason: reason.text,
                    );
                ref.invalidate(blockedTimesProvider);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              } catch (e) {
                setSheet(() => saving = false);
                if (sheetContext.mounted) {
                  showAppSnackBar(
                    sheetContext,
                    message: AppException.from(e).message,
                    isError: true,
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add blocked time',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(DateFormat('EEE, MMM d, y').format(date)),
                    trailing: const Text('Change'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: date,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setSheet(() => date = picked);
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeField(
                          label: 'From',
                          time: start,
                          onTap: () async {
                            final p = await showTimePicker(
                              context: sheetContext,
                              initialTime: start,
                            );
                            if (p != null) setSheet(() => start = p);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeField(
                          label: 'To',
                          time: end,
                          onTap: () async {
                            final p = await showTimePicker(
                              context: sheetContext,
                              initialTime: end,
                            );
                            if (p != null) setSheet(() => end = p);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reason,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving ? null : submit,
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Add'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    reason.dispose();
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.block,
    required this.timezone,
    required this.canDelete,
    required this.onDelete,
  });

  final BlockedTime block;
  final String timezone;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // Display in the business's timezone, not the device's.
    final start = utcToBusinessLocal(block.startDatetime, timezone);
    final end = utcToBusinessLocal(block.endDatetime, timezone);
    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    final dateStr = DateFormat('EEE, MMM d, y').format(start);
    final timeStr = sameDay
        ? '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}'
        : '${DateFormat('MMM d, h:mm a').format(start)} – ${DateFormat('MMM d, h:mm a').format(end)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(dateStr),
        subtitle: Text(
          block.reason == null ? timeStr : '$timeStr\n${block.reason}',
        ),
        isThreeLine: block.reason != null,
        trailing: canDelete
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(time.format(context)),
        ),
      ),
    );
  }
}
