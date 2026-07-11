import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/error_retry_view.dart';
import '../../../../models/availability_models.dart';
import '../../../business_context/application/active_business_provider.dart';
import '../../../business_context/application/permissions.dart';
import '../../application/availability_providers.dart';

/// One-off date overrides — a closure (holiday) or custom hours for a
/// specific date. These override the regular weekly hours.
class SpecialDaysTab extends ConsumerWidget {
  const SpecialDaysTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final canManage =
        membership != null && can(membership.role, Permission.manageSettings);
    final async = ref.watch(specialDaysProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetryView(
        message: AppException.from(e).message,
        onRetry: () => ref.invalidate(specialDaysProvider),
      ),
      data: (days) {
        if (membership == null) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (canManage)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showAdd(context, ref, membership.business.id),
                  icon: const Icon(Icons.add),
                  label: const Text('Add special day'),
                ),
              ),
            if (days.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No special days.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                ),
              )
            else
              for (final d in days)
                _SpecialDayCard(
                  day: d,
                  canDelete: canManage,
                  onDelete: () => _delete(context, ref, d.id),
                ),
          ],
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(availabilityRepositoryProvider).deleteSpecialDay(id);
      ref.invalidate(specialDaysProvider);
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
  ) async {
    DateTime date = DateTime.now();
    bool isClosed = true;
    TimeOfDay open = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay close = const TimeOfDay(hour: 17, minute: 0);
    final note = TextEditingController();
    bool saving = false;

    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            Future<void> submit() async {
              if (!isClosed) {
                final o = open.hour * 60 + open.minute;
                final c = close.hour * 60 + close.minute;
                if (c <= o) {
                  showAppSnackBar(
                    sheetContext,
                    message: 'Close time must be after open time',
                    isError: true,
                  );
                  return;
                }
              }
              setSheet(() => saving = true);
              try {
                await ref.read(availabilityRepositoryProvider).addSpecialDay(
                      businessId: businessId,
                      date: DateFormat('yyyy-MM-dd').format(date),
                      isClosed: isClosed,
                      customOpenTime: isClosed ? null : fmt(open),
                      customCloseTime: isClosed ? null : fmt(close),
                      note: note.text,
                    );
                ref.invalidate(specialDaysProvider);
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
                    'Add special day',
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Closed all day'),
                    value: isClosed,
                    onChanged: (v) => setSheet(() => isClosed = v),
                  ),
                  if (!isClosed)
                    Row(
                      children: [
                        Expanded(
                          child: _TimeField(
                            label: 'Open',
                            time: open,
                            onTap: () async {
                              final p = await showTimePicker(
                                context: sheetContext,
                                initialTime: open,
                              );
                              if (p != null) setSheet(() => open = p);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeField(
                            label: 'Close',
                            time: close,
                            onTap: () async {
                              final p = await showTimePicker(
                                context: sheetContext,
                                initialTime: close,
                              );
                              if (p != null) setSheet(() => close = p);
                            },
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
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
    note.dispose();
  }
}

class _SpecialDayCard extends StatelessWidget {
  const _SpecialDayCard({
    required this.day,
    required this.canDelete,
    required this.onDelete,
  });

  final SpecialBusinessDay day;
  final bool canDelete;
  final VoidCallback onDelete;

  String _label(String? hhmmss) {
    if (hhmmss == null) return '';
    final parts = hhmmss.split(':');
    if (parts.length < 2) return hhmmss;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final dt = DateTime(2000, 1, 1, h, m);
    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    DateTime? parsed = DateTime.tryParse(day.date);
    final dateStr = parsed != null
        ? DateFormat('EEE, MMM d, y').format(parsed)
        : day.date;
    final status = day.isClosed
        ? 'Closed'
        : '${_label(day.customOpenTime)} – ${_label(day.customCloseTime)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(dateStr),
        subtitle: Text(day.note == null ? status : '$status\n${day.note}'),
        isThreeLine: day.note != null,
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
