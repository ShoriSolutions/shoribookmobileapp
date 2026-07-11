import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/error_retry_view.dart';
import '../../../../models/availability_models.dart';
import '../../../business_context/application/active_business_provider.dart';
import '../../../business_context/application/permissions.dart';
import '../../application/availability_providers.dart';

/// Weekly business-hours editor (Availability → Hours). OWNER/ADMIN can
/// edit; others see it read-only.
class HoursTab extends ConsumerStatefulWidget {
  const HoursTab({super.key});

  @override
  ConsumerState<HoursTab> createState() => _HoursTabState();
}

class _DayState {
  bool isOpen;
  TimeOfDay open;
  TimeOfDay close;
  _DayState({required this.isOpen, required this.open, required this.close});
}

class _HoursTabState extends ConsumerState<HoursTab> {
  List<_DayState>? _days;
  bool _saving = false;

  static const _defaultOpen = TimeOfDay(hour: 9, minute: 0);
  static const _defaultClose = TimeOfDay(hour: 17, minute: 0);

  List<_DayState> _seed(List<BusinessHours> hours) {
    final byDay = {for (final h in hours) h.dayOfWeek: h};
    return List.generate(7, (i) {
      final row = byDay[i];
      if (row == null) {
        final weekday = i >= 1 && i <= 5;
        return _DayState(
          isOpen: weekday,
          open: _defaultOpen,
          close: _defaultClose,
        );
      }
      return _DayState(
        isOpen: !row.isClosed,
        open: _parse(row.openTime, _defaultOpen),
        close: _parse(row.closeTime, _defaultClose),
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

  Future<void> _pickTime({required int dayIndex, required bool isOpenTime}) async {
    final current = isOpenTime ? _days![dayIndex].open : _days![dayIndex].close;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    setState(() {
      if (isOpenTime) {
        _days![dayIndex].open = picked;
      } else {
        _days![dayIndex].close = picked;
      }
    });
  }

  Future<void> _save(String businessId) async {
    setState(() => _saving = true);
    final rows = [
      for (var i = 0; i < 7; i++)
        {
          'business_id': businessId,
          'day_of_week': i,
          'is_closed': !_days![i].isOpen,
          'open_time': _days![i].isOpen ? _fmt(_days![i].open) : null,
          'close_time': _days![i].isOpen ? _fmt(_days![i].close) : null,
        },
    ];
    try {
      await ref
          .read(availabilityRepositoryProvider)
          .saveBusinessHours(businessId, rows);
      ref.invalidate(businessHoursProvider);
      if (mounted) showAppSnackBar(context, message: 'Hours saved');
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
    final hoursAsync = ref.watch(businessHoursProvider);

    return hoursAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetryView(
        message: AppException.from(e).message,
        onRetry: () => ref.invalidate(businessHoursProvider),
      ),
      data: (hours) {
        _days ??= _seed(hours);
        if (membership == null) return const SizedBox.shrink();
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    canManage
                        ? 'Set your regular weekly opening hours.'
                        : 'Only an owner or admin can change these hours.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < 7; i++)
                    _DayRow(
                      label: weekdayLabels[i],
                      state: _days![i],
                      enabled: canManage,
                      onToggle: (v) => setState(() => _days![i].isOpen = v),
                      onPickOpen: () => _pickTime(dayIndex: i, isOpenTime: true),
                      onPickClose: () =>
                          _pickTime(dayIndex: i, isOpenTime: false),
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
                      onPressed:
                          _saving ? null : () => _save(membership.business.id),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save hours'),
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

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.label,
    required this.state,
    required this.enabled,
    required this.onToggle,
    required this.onPickOpen,
    required this.onPickClose,
  });

  final String label;
  final _DayState state;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickOpen;
  final VoidCallback onPickClose;

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
            Switch(value: state.isOpen, onChanged: enabled ? onToggle : null),
            Expanded(
              child: state.isOpen
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _TimeChip(
                          time: state.open,
                          enabled: enabled,
                          onTap: onPickOpen,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('to'),
                        ),
                        _TimeChip(
                          time: state.close,
                          enabled: enabled,
                          onTap: onPickClose,
                        ),
                      ],
                    )
                  : const Align(
                      alignment: Alignment.centerRight,
                      child: Text('Closed', style: TextStyle(color: AppColors.muted)),
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
