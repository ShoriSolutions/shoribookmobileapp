import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/timezone_offsets.dart';
import '../../../models/appointment.dart';
import '../../../models/availability_models.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../routing/route_paths.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import '../../staff/application/staff_providers.dart';
import '../application/calendar_providers.dart';

/// V05 · Calendar — month grid + the selected day's agenda (colored left
/// bar per booking) with a terracotta FAB to add manually.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedCalendarDateProvider);
    final apptsAsync = ref.watch(calendarAppointmentsProvider);
    final blocks = ref.watch(calendarBlockedTimesProvider).valueOrNull ??
        const <BlockedTime>[];
    final specialDay = ref.watch(calendarSpecialDayProvider).valueOrNull;
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final tz = membership?.business.timezone ?? 'America/Barbados';
    final staffFilter = ref.watch(calendarStaffFilterProvider);
    final canFilterStaff =
        membership != null && membership.role.value != 'STAFF';

    void setDate(DateTime d) =>
        ref.read(selectedCalendarDateProvider.notifier).state = d;

    return Scaffold(
      floatingActionButton:
          membership != null && canCreateOrEditBooking(membership.role)
              ? FloatingActionButton(
                  backgroundColor: AppColors.terracotta,
                  foregroundColor: Colors.white,
                  onPressed: () => context.push(RoutePaths.bookingNew),
                  child: const Icon(Icons.add),
                )
              : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Calendar',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.ink)),
                  GestureDetector(
                    onTap: () => setDate(DateTime.now()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.sageLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Today',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.sageDark)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.parchment),
                ),
                child: TableCalendar<void>(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: selectedDate,
                  selectedDayPredicate: (d) => isSameDay(d, selectedDate),
                  onDaySelected: (selected, focused) => setDate(selected),
                  calendarStyle: const CalendarStyle(
                    selectedDecoration: BoxDecoration(
                        color: AppColors.sage, shape: BoxShape.circle),
                    todayDecoration: BoxDecoration(
                        color: AppColors.sageLight, shape: BoxShape.circle),
                    todayTextStyle: TextStyle(
                        color: AppColors.sageDark, fontWeight: FontWeight.w700),
                    weekendTextStyle: TextStyle(color: AppColors.ink),
                    outsideTextStyle: TextStyle(color: AppColors.faint),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink),
                  ),
                ),
              ),
            ),
            if (canFilterStaff) ...[
              const SizedBox(height: 12),
              _StaffFilterRow(selectedId: staffFilter),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: apptsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, st) => ErrorRetryView(
                  message: 'Could not load appointments.',
                  onRetry: () =>
                      ref.invalidate(calendarAppointmentsProvider),
                ),
                data: (allAppts) {
                  final appts = staffFilter == null
                      ? allAppts
                      : allAppts
                          .where((a) => a.staffProfileId == staffFilter)
                          .toList();
                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.refresh(calendarAppointmentsProvider.future),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        Text(
                          '${DateFormat('EEE, d MMM').format(selectedDate)} · '
                          '${appts.length} booking${appts.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink),
                        ),
                        const SizedBox(height: 12),
                        if (specialDay != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SpecialDayCard(day: specialDay),
                          ),
                        for (final b in blocks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _BlockedCard(block: b, timezone: tz),
                          ),
                        if (appts.isEmpty && blocks.isEmpty && specialDay == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: EmptyState(
                              icon: '📅',
                              title: 'Nothing this day',
                              message: 'No appointments or blocked time.',
                            ),
                          )
                        else
                          for (final a in appts)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AgendaRow(
                                appt: a,
                                tz: tz,
                                onTap: () => context.push(
                                    RoutePaths.appointmentDetailPath(a.id)),
                              ),
                            ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owner/admin filter to view one staff member's day (or All).
class _StaffFilterRow extends ConsumerWidget {
  const _StaffFilterRow({required this.selectedId});
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = (ref.watch(staffListProvider).valueOrNull ?? const [])
        .where((s) => s.isActive)
        .toList();
    if (staff.isEmpty) return const SizedBox.shrink();

    void set(String? id) =>
        ref.read(calendarStaffFilterProvider.notifier).state = id;

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _chip('All staff', selectedId == null, () => set(null)),
          const SizedBox(width: 8),
          for (final s in staff) ...[
            _chip(s.name, selectedId == s.id, () => set(s.id)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.sage : AppColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? AppColors.sage : AppColors.parchment),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.muted)),
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.appt, required this.tz, required this.onTap});
  final Appointment appt;
  final String tz;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final local = utcToBusinessLocal(appt.startTime, tz);
    final duration = appt.endTime.difference(appt.startTime).inMinutes;
    final depositDue = appt.depositRequired && !appt.depositPaid;
    final barColor = depositDue ? AppColors.terracotta : AppColors.sage;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.parchment),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('h:mm').format(local),
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink)),
                            Text('$duration min',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(appt.customerName ?? 'Client',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink)),
                              const SizedBox(height: 1),
                              Text(
                                [appt.serviceName, appt.staffName]
                                    .where((s) => s != null && s.isNotEmpty)
                                    .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _SpecialDayCard extends StatelessWidget {
  final SpecialBusinessDay day;

  const _SpecialDayCard({required this.day});

  String _time(String? hhmmss) {
    if (hhmmss == null) return '';
    final parts = hhmmss.split(':');
    if (parts.length < 2) return hhmmss;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
  }

  @override
  Widget build(BuildContext context) {
    final status = day.isClosed
        ? 'Closed all day'
        : 'Special hours: ${_time(day.customOpenTime)} – ${_time(day.customCloseTime)}';
    return Card(
      color: AppColors.sageLight,
      child: ListTile(
        leading: Icon(day.isClosed ? Icons.event_busy : Icons.event_available,
            color: AppColors.sageDark),
        title: const Text('Special day',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(day.note == null ? status : '$status · ${day.note}'),
      ),
    );
  }
}

class _BlockedCard extends StatelessWidget {
  final BlockedTime block;
  final String timezone;

  const _BlockedCard({required this.block, required this.timezone});

  @override
  Widget build(BuildContext context) {
    final start = utcToBusinessLocal(block.startDatetime, timezone);
    final end = utcToBusinessLocal(block.endDatetime, timezone);
    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    final timeStr = sameDay
        ? '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}'
        : '${DateFormat('MMM d, h:mm a').format(start)} – ${DateFormat('MMM d, h:mm a').format(end)}';
    return Card(
      color: AppColors.parchment,
      child: ListTile(
        leading: const Icon(Icons.block, color: AppColors.muted),
        title:
            const Text('Blocked', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            block.reason == null ? timeStr : '$timeStr · ${block.reason}'),
      ),
    );
  }
}
