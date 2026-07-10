import '../../../core/utils/timezone_offsets.dart';
import '../../../models/availability_models.dart';
import '../../../models/staff_profile.dart';

/// A bookable time slot on a given date, with the set of staff who are
/// free to take it.
class AvailableSlot {
  final String startTime; // "HH:MM" business-local
  final String endTime;
  final List<String> availableStaffIds;

  const AvailableSlot({
    required this.startTime,
    required this.endTime,
    required this.availableStaffIds,
  });
}

const int _slotIntervalMinutes = 15;

int _toMin(String t) {
  final parts = t.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

String _fromMin(int m) {
  final h = (m ~/ 60).toString().padLeft(2, '0');
  final min = (m % 60).toString().padLeft(2, '0');
  return '$h:$min';
}

/// Subtracts a list of blocked [start, end) periods (in minutes from
/// midnight) from a free window, returning the remaining free sub-windows.
List<(int, int)> _subtractPeriods(
  (int, int) window,
  List<(int, int)> blocked,
) {
  var free = [window];
  for (final (blockStart, blockEnd) in blocked) {
    final next = <(int, int)>[];
    for (final (windowStart, windowEnd) in free) {
      if (windowStart < blockStart) {
        next.add((windowStart, blockStart < windowEnd ? blockStart : windowEnd));
      }
      if (windowEnd > blockEnd) {
        next.add((blockEnd > windowStart ? blockEnd : windowStart, windowEnd));
      }
    }
    free = next;
  }
  return free;
}

/// Pure port of the web's src/lib/availability.ts `getAvailableSlots` —
/// no I/O, takes every input already fetched by the caller (see
/// MarketplaceRepository) and returns the same {startTime, endTime,
/// availableStaffIds} shape. Kept pure specifically so this logic is
/// unit-testable without a live Supabase project.
///
/// [date] is a business-local "YYYY-MM-DD" (not UTC) — its weekday is
/// computed directly, no timezone conversion needed for that part since
/// it's already expressed in business-local calendar terms.
List<AvailableSlot> calculateAvailableSlots({
  required String date,
  required String timezone,
  required int serviceDurationMinutes,
  required int bufferBeforeMinutes,
  required int bufferAfterMinutes,
  required List<StaffProfile> staffList,
  required List<BusinessHours> businessHours,
  SpecialBusinessDay? specialDay,
  required List<StaffAvailability> staffAvailability,
  required List<StaffBreak> staffBreaks,
  required List<BlockedRange> blockedRanges,
  required List<BookedRange> bookedRanges,
}) {
  if (specialDay?.isClosed == true) return [];

  final dateParts = date.split('-').map(int.parse).toList();
  final dayOfWeek = DateTime(dateParts[0], dateParts[1], dateParts[2]).weekday % 7;

  int bizOpen;
  int bizClose;
  if (specialDay?.customOpenTime != null && specialDay?.customCloseTime != null) {
    bizOpen = _toMin(specialDay!.customOpenTime!);
    bizClose = _toMin(specialDay.customCloseTime!);
  } else {
    final todayHours = businessHours.where((h) => h.dayOfWeek == dayOfWeek);
    if (todayHours.isEmpty) return [];
    final bh = todayHours.first;
    if (bh.isClosed || bh.openTime == null || bh.closeTime == null) return [];
    bizOpen = _toMin(bh.openTime!);
    bizClose = _toMin(bh.closeTime!);
  }

  final nowUtc = DateTime.now().toUtc();
  final todayDate = businessLocalDateString(nowUtc, timezone);
  final isToday = todayDate == date;
  final nowMin = isToday
      ? () {
          final local = utcToBusinessLocal(nowUtc, timezone);
          return local.hour * 60 + local.minute;
        }()
      : 0;

  final slotMap = <String, Set<String>>{};

  for (final staff in staffList) {
    // Callers (e.g. the "Meet the Team" section) may legitimately pass
    // non-bookable staff for display purposes — filter here so this
    // function's output is always correct regardless of what's passed in,
    // matching the web's query-level `.eq('is_bookable', true)` filter.
    if (!staff.isActive || !staff.isBookable) continue;

    final avail = staffAvailability.where(
      (a) => a.staffId == staff.id && a.dayOfWeek == dayOfWeek,
    );

    int staffOpen;
    int staffClose;
    if (avail.isNotEmpty) {
      final a = avail.first;
      if (!a.isAvailable) continue;
      staffOpen = _toMin(a.startTime);
      staffClose = _toMin(a.endTime);
    } else {
      staffOpen = bizOpen;
      staffClose = bizClose;
    }

    final winStart = staffOpen > bizOpen ? staffOpen : bizOpen;
    final winEnd = staffClose < bizClose ? staffClose : bizClose;
    if (winStart >= winEnd) continue;

    final blocked = <(int, int)>[];

    for (final b in staffBreaks) {
      if (b.staffId != staff.id || b.dayOfWeek != dayOfWeek) continue;
      blocked.add((_toMin(b.startTime), _toMin(b.endTime)));
    }

    for (final appt in bookedRanges) {
      if (appt.staffProfileId != staff.id) continue;
      final apptLocalDate = businessLocalDateString(appt.startTime, timezone);
      if (apptLocalDate != date) continue;
      final start = utcToBusinessLocal(appt.startTime, timezone);
      final end = utcToBusinessLocal(appt.endTime, timezone);
      blocked.add((start.hour * 60 + start.minute, end.hour * 60 + end.minute));
    }

    for (final block in blockedRanges) {
      if (block.staffProfileId != null && block.staffProfileId != staff.id) {
        continue;
      }
      final blockStartDate = businessLocalDateString(
        block.startDatetime,
        timezone,
      );
      final blockEndDate = businessLocalDateString(block.endDatetime, timezone);
      if (blockStartDate.compareTo(date) > 0 ||
          blockEndDate.compareTo(date) < 0) {
        continue;
      }
      final blockStartMin = blockStartDate == date
          ? () {
              final l = utcToBusinessLocal(block.startDatetime, timezone);
              return l.hour * 60 + l.minute;
            }()
          : 0;
      final blockEndMin = blockEndDate == date
          ? () {
              final l = utcToBusinessLocal(block.endDatetime, timezone);
              return l.hour * 60 + l.minute;
            }()
          : 24 * 60;
      blocked.add((blockStartMin, blockEndMin));
    }

    final freeWindows = _subtractPeriods((winStart, winEnd), blocked);

    for (final (freeStart, freeEnd) in freeWindows) {
      final minStart = freeStart + bufferBeforeMinutes;
      final maxStart = freeEnd - serviceDurationMinutes - bufferAfterMinutes;
      if (minStart > maxStart) continue;

      final firstSlot =
          ((minStart + _slotIntervalMinutes - 1) ~/ _slotIntervalMinutes) *
          _slotIntervalMinutes;

      for (
        var t = firstSlot;
        t <= maxStart;
        t += _slotIntervalMinutes
      ) {
        if (isToday && t < nowMin) continue;
        final key = _fromMin(t);
        (slotMap[key] ??= {}).add(staff.id);
      }
    }
  }

  final entries = slotMap.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  return entries
      .map(
        (e) => AvailableSlot(
          startTime: e.key,
          endTime: _fromMin(_toMin(e.key) + serviceDurationMinutes),
          availableStaffIds: e.value.toList(),
        ),
      )
      .toList();
}
