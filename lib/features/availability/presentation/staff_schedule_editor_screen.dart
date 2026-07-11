import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/availability_models.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import '../application/availability_providers.dart';

/// Weekly availability editor for one staff member. Pushed from the
/// Availability → Staff Schedules tab.
class StaffScheduleEditorScreen extends ConsumerStatefulWidget {
  const StaffScheduleEditorScreen({
    super.key,
    required this.staffId,
    required this.staffName,
  });

  final String staffId;
  final String staffName;

  @override
  ConsumerState<StaffScheduleEditorScreen> createState() =>
      _StaffScheduleEditorScreenState();
}

class _DayState {
  bool isAvailable;
  TimeOfDay start;
  TimeOfDay end;
  _DayState({
    required this.isAvailable,
    required this.start,
    required this.end,
  });
}

class _StaffScheduleEditorScreenState
    extends ConsumerState<StaffScheduleEditorScreen> {
  List<_DayState>? _days;
  bool _saving = false;

  static const _defaultStart = TimeOfDay(hour: 9, minute: 0);
  static const _defaultEnd = TimeOfDay(hour: 17, minute: 0);

  List<_DayState> _seed(List<StaffAvailability> avail) {
    // Keep the first available row per day (the editor models one window
    // per day, matching business hours).
    final byDay = <int, StaffAvailability>{};
    for (final a in avail) {
      byDay.putIfAbsent(a.dayOfWeek, () => a);
    }
    return List.generate(7, (i) {
      final row = byDay[i];
      if (row == null) {
        final weekday = i >= 1 && i <= 5;
        return _DayState(
          isAvailable: weekday,
          start: _defaultStart,
          end: _defaultEnd,
        );
      }
      return _DayState(
        isAvailable: row.isAvailable,
        start: _parse(row.startTime, _defaultStart),
        end: _parse(row.endTime, _defaultEnd),
      );
    });
  }

  TimeOfDay _parse(String? hhmmss, TimeOfDay fallback) {
    if (hhmmss == null) return fallback;
    final parts = hhmmss.split(':');
    if (parts.length < 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return fallback;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime({required int dayIndex, required bool isStart}) async {
    final current = isStart ? _days![dayIndex].start : _days![dayIndex].end;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _days![dayIndex].start = picked;
      } else {
        _days![dayIndex].end = picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final rows = [
      for (var i = 0; i < 7; i++)
        {
          'staff_id': widget.staffId,
          'day_of_week': i,
          'start_time': _fmt(_days![i].start),
          'end_time': _fmt(_days![i].end),
          'is_available': _days![i].isAvailable,
        },
    ];
    try {
      await ref
          .read(availabilityRepositoryProvider)
          .saveStaffAvailability(widget.staffId, rows);
      ref.invalidate(staffAvailabilityProvider(widget.staffId));
      if (mounted) {
        showAppSnackBar(context, message: 'Schedule saved');
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: AppException.from(e).message,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final canManage =
        membership != null && can(membership.role, Permission.manageSettings);
    final async = ref.watch(staffAvailabilityProvider(widget.staffId));

    return Scaffold(
      appBar: AppBar(title: Text(widget.staffName)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          message: AppException.from(e).message,
          onRetry: () =>
              ref.invalidate(staffAvailabilityProvider(widget.staffId)),
        ),
        data: (avail) {
          _days ??= _seed(avail);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      canManage
                          ? 'Set the days and hours ${widget.staffName} is '
                              'available for bookings.'
                          : 'Only an owner or admin can change this schedule.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < 7; i++)
                      _DayRow(
                        label: weekdayLabels[i],
                        state: _days![i],
                        enabled: canManage,
                        onToggle: (v) =>
                            setState(() => _days![i].isAvailable = v),
                        onPickStart: () =>
                            _pickTime(dayIndex: i, isStart: true),
                        onPickEnd: () => _pickTime(dayIndex: i, isStart: false),
                      ),
                  ],
                ),
              ),
              if (canManage)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save schedule'),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.label,
    required this.state,
    required this.enabled,
    required this.onToggle,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final String label;
  final _DayState state;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Switch(value: state.isAvailable, onChanged: enabled ? onToggle : null),
            Expanded(
              child: state.isAvailable
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _TimeChip(
                          time: state.start,
                          enabled: enabled,
                          onTap: onPickStart,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('to'),
                        ),
                        _TimeChip(
                          time: state.end,
                          enabled: enabled,
                          onTap: onPickEnd,
                        ),
                      ],
                    )
                  : const Align(
                      alignment: Alignment.centerRight,
                      child: Text('Off', style: TextStyle(color: AppColors.muted)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.time,
    required this.enabled,
    required this.onTap,
  });

  final TimeOfDay time;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(time.format(context)),
    );
  }
}
