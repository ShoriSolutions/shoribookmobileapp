import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_formatters.dart';
import '../../../core/utils/timezone_offsets.dart';
import '../../../models/availability_models.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../routing/route_paths.dart';
import '../../appointments/presentation/widgets/appointment_card.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import '../application/calendar_providers.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _showMonthGrid = false;

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedCalendarDateProvider);
    final apptsAsync = ref.watch(calendarAppointmentsProvider);
    final blocks = ref.watch(calendarBlockedTimesProvider).valueOrNull ??
        const <BlockedTime>[];
    final membership = ref.watch(activeMembershipProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: Icon(_showMonthGrid ? Icons.view_agenda_outlined : Icons.calendar_month_outlined),
            onPressed: () => setState(() => _showMonthGrid = !_showMonthGrid),
          ),
        ],
      ),
      floatingActionButton:
          membership != null && canCreateOrEditBooking(membership.role)
          ? FloatingActionButton(
              backgroundColor: AppColors.terracotta,
              onPressed: () => context.push(RoutePaths.bookingNew),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          if (_showMonthGrid)
            TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: selectedDate,
              selectedDayPredicate: (day) => isSameDay(day, selectedDate),
              onDaySelected: (selected, focused) {
                ref.read(selectedCalendarDateProvider.notifier).state = selected;
              },
              calendarStyle: const CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: AppColors.sage,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.sageLight,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(color: AppColors.ink),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            )
          else
            _DateStrip(
              selectedDate: selectedDate,
              timezone: membership?.business.timezone ?? 'America/Barbados',
              onChanged: (d) =>
                  ref.read(selectedCalendarDateProvider.notifier).state = d,
            ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(calendarAppointmentsProvider.future),
              child: apptsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, st) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    ErrorRetryView(
                      message: 'Could not load appointments.',
                      onRetry: () =>
                          ref.invalidate(calendarAppointmentsProvider),
                    ),
                  ],
                ),
                data: (appts) {
                  final tz =
                      membership?.business.timezone ?? 'America/Barbados';
                  if (appts.isEmpty && blocks.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 60),
                        EmptyState(
                          icon: '📅',
                          title: 'Nothing this day',
                          message: 'No appointments or blocked time. '
                              'Pick another date, or add a booking.',
                        ),
                      ],
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final b in blocks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _BlockedCard(block: b, timezone: tz),
                        ),
                      for (final a in appts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppointmentCard(
                            appointment: a,
                            timezone: tz,
                            onTap: () => context.push(
                              RoutePaths.appointmentDetailPath(a.id),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
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
        title: const Text(
          'Blocked',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          block.reason == null ? timeStr : '$timeStr · ${block.reason}',
        ),
      ),
    );
  }
}

class _DateStrip extends StatelessWidget {
  final DateTime selectedDate;
  final String timezone;
  final ValueChanged<DateTime> onChanged;

  const _DateStrip({
    required this.selectedDate,
    required this.timezone,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                onChanged(selectedDate.subtract(const Duration(days: 1))),
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) onChanged(picked);
              },
              child: Center(
                child: Text(
                  DateTimeFormatters.relativeDayLabel(
                    '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                    timezone,
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(selectedDate.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }
}
