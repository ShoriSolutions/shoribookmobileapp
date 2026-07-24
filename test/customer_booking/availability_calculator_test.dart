import 'package:flutter_test/flutter_test.dart';
import 'package:shorivo/features/customer_booking/data/availability_calculator.dart';
import 'package:shorivo/models/availability_models.dart';
import 'package:shorivo/models/staff_profile.dart';

// A fixed future date so tests never hit the "isToday" past-time filter
// unintentionally. 'UTC' timezone (offset 0) keeps business-local time
// numerically identical to the UTC DateTimes used for ranges, so
// assertions don't need to account for any offset.
const _date = '2027-03-15';
final _dayOfWeek = DateTime(2027, 3, 15).weekday % 7;

StaffProfile _staff(String id, {bool isActive = true, bool isBookable = true}) {
  return StaffProfile(
    id: id,
    businessId: 'b1',
    name: 'Staff $id',
    isActive: isActive,
    isBookable: isBookable,
    displayOrder: 0,
  );
}

List<BusinessHours> _hours9to17() => [
  BusinessHours(
    id: 'h1',
    businessId: 'b1',
    dayOfWeek: _dayOfWeek,
    openTime: '09:00',
    closeTime: '17:00',
    isClosed: false,
  ),
];

void main() {
  group('calculateAvailableSlots — basic business hours', () {
    test('generates 15-min slots within business hours for a free staff', () {
      final slots = calculateAvailableSlots(
        date: _date,
        timezone: 'UTC',
        serviceDurationMinutes: 60,
        bufferBeforeMinutes: 0,
        bufferAfterMinutes: 0,
        staffList: [_staff('s1')],
        businessHours: _hours9to17(),
        staffAvailability: [],
        staffBreaks: [],
        blockedRanges: [],
        bookedRanges: [],
      );

      expect(slots.first.startTime, '09:00');
      expect(slots.last.startTime, '16:00'); // last slot that still fits a 60-min service before 17:00
      expect(slots.last.endTime, '17:00');
      expect(slots.first.availableStaffIds, ['s1']);
    });

    test('no business_hours row for the day returns no slots', () {
      final slots = calculateAvailableSlots(
        date: _date,
        timezone: 'UTC',
        serviceDurationMinutes: 60,
        bufferBeforeMinutes: 0,
        bufferAfterMinutes: 0,
        staffList: [_staff('s1')],
        businessHours: const [],
        staffAvailability: [],
        staffBreaks: [],
        blockedRanges: [],
        bookedRanges: [],
      );
      expect(slots, isEmpty);
    });

    test('is_closed business_hours row returns no slots', () {
      final slots = calculateAvailableSlots(
        date: _date,
        timezone: 'UTC',
        serviceDurationMinutes: 60,
        bufferBeforeMinutes: 0,
        bufferAfterMinutes: 0,
        staffList: [_staff('s1')],
        businessHours: [
          BusinessHours(
            id: 'h1',
            businessId: 'b1',
            dayOfWeek: _dayOfWeek,
            isClosed: true,
          ),
        ],
        staffAvailability: [],
        staffBreaks: [],
        blockedRanges: [],
        bookedRanges: [],
      );
      expect(slots, isEmpty);
    });
  });

  group('calculateAvailableSlots — special days', () {
    test('special day marked closed overrides business hours entirely', () {
      final slots = calculateAvailableSlots(
        date: _date,
        timezone: 'UTC',
        serviceDurationMinutes: 60,
        bufferBeforeMinutes: 0,
        bufferAfterMinutes: 0,
        staffList: [_staff('s1')],
        businessHours: _hours9to17(),
        specialDay: SpecialBusinessDay(
          id: 'sd1',
          businessId: 'b1',
          date: _date,
          isClosed: true,
        ),
        staffAvailability: [],
        staffBreaks: [],
        blockedRanges: [],
        bookedRanges: [],
      );
      expect(slots, isEmpty);
    });

    test('special day custom hours override regular business hours', () {
      final slots = calculateAvailableSlots(
        date: _date,
        timezone: 'UTC',
        serviceDurationMinutes: 60,
        bufferBeforeMinutes: 0,
        bufferAfterMinutes: 0,
        staffList: [_staff('s1')],
        businessHours: _hours9to17(),
        specialDay: SpecialBusinessDay(
          id: 'sd1',
          businessId: 'b1',
          date: _date,
          isClosed: false,
          customOpenTime: '12:00',
          customCloseTime: '14:00',
        ),
        staffAvailability: [],
        staffBreaks: [],
        blockedRanges: [],
        bookedRanges: [],
      );
      expect(slots.first.startTime, '12:00');
      expect(slots.last.startTime, '13:00');
    });
  });

  group('calculateAvailableSlots — staff availability override', () {
    test('staff-specific hours intersect with business hours', () {
      final slots = calculateAvailableSlots(
        date: _date,
        timezone: 'UTC',
        serviceDurationMinutes: 60,
        bufferBeforeMinutes: 0,
        bufferAfterMinutes: 0,
        staffList: [_staff('s1')],
        businessHours: _hours9to17(),
        staffAvailability: [
          StaffAvailability(
            id: 'a1',
            staffId: 's1',
            dayOfWeek: _dayOfWeek,
            startTime: '10:00',
            endTime: '14:00',
            isAvailable: true,
          ),
        ],
        staffBreaks: [],
        blockedRanges: [],
        bookedRanges: [],
      );
      expect(slots.first.startTime, '10:00');
      expect(slots.last.startTime, '13:00');
    });

    test('is_available=false for the day excludes that staff entirely', () {
      final slots = calculateAvailableSlots(
        date: _date,
        timezone: 'UTC',
        serviceDurationMinutes: 60,
        bufferBeforeMinutes: 0,
        bufferAfterMinutes: 0,
        staffList: [_staff('s1')],
        businessHours: _hours9to17(),
        staffAvailability: [
          StaffAvailability(
            id: 'a1',
            staffId: 's1',
            dayOfWeek: _dayOfWeek,
            startTime: '09:00',
            endTime: '17:00',
            isAvailable: false,
          ),
        ],
        staffBreaks: [],
        blockedRanges: [],
        bookedRanges: [],
      );
      expect(slots, isEmpty);
    });
  });

  group('calculateAvailableSlots — breaks, bookings, blocks', () {
    test('a staff break removes only that window', () {
      final slots = calculateAvailableSlots(
        date: _date,
        timezone: 'UTC',
        serviceDurationMinutes: 60,
        bufferBeforeMinutes: 0,
        bufferAfterMinutes: 0,
        staffList: [_staff('s1')],
        businessHours: _hours9to17(),
        staffAvailability: [],
        staffBreaks: [
          StaffBreak(
            id: 'br1',
            staffId: 's1',
            dayOfWeek: _dayOfWeek,
            startTime: '12:00',
            endTime: '13:00',
            label: 'Lunch',
          ),
        ],
        blockedRanges: [],
        bookedRanges: [],
      );
      // A 60-min service starting at 12:00 would run into the break —
      // the last valid start before it is 11:00, and slots resume only
      // once a full post-break window exists again.
      expect(slots.map((s) => s.startTime), isNot(contains('12:00')));
      expect(slots.map((s) => s.startTime), contains('11:00'));
      expect(slots.map((s) => s.startTime), contains('13:00'));
    });

    test('an existing booking on the target date blocks that staff only', () {
      final slots = calculateAvailableSlots(
        date: _date,
        timezone: 'UTC',
        serviceDurationMinutes: 60,
        bufferBeforeMinutes: 0,
        bufferAfterMinutes: 0,
        staffList: [_staff('s1'), _staff('s2')],
        businessHours: _hours9to17(),
        staffAvailability: [],
        staffBreaks: [],
        blockedRanges: [],
        bookedRanges: [
          BookedRange(
            staffProfileId: 's1',
            startTime: DateTime.utc(2027, 3, 15, 10, 0),
            endTime: DateTime.utc(2027, 3, 15, 11, 0),
          ),
        ],
      );
      final tenAm = slots.firstWhere((s) => s.startTime == '10:00');
      expect(tenAm.availableStaffIds, ['s2']);
      final nineAm = slots.firstWhere((s) => s.startTime == '09:00');
      expect(nineAm.availableStaffIds, containsAll(['s1', 's2']));
    });

    test('a booking on a different date does not block this date', () {
      final slots = calculateAvailableSlots(
        date: _date,
        timezone: 'UTC',
        serviceDurationMinutes: 60,
        bufferBeforeMinutes: 0,
        bufferAfterMinutes: 0,
        staffList: [_staff('s1')],
        businessHours: _hours9to17(),
        staffAvailability: [],
        staffBreaks: [],
        blockedRanges: [],
        bookedRanges: [
          BookedRange(
            staffProfileId: 's1',
            startTime: DateTime.utc(2027, 3, 16, 10, 0),
            endTime: DateTime.utc(2027, 3, 16, 11, 0),
          ),
        ],
      );
      final tenAm = slots.firstWhere((s) => s.startTime == '10:00');
      expect(tenAm.availableStaffIds, ['s1']);
    });

    test('a business-wide blocked time (staffProfileId null) blocks all staff', () {
      final slots = calculateAvailableSlots(
        date: _date,
        timezone: 'UTC',
        serviceDurationMinutes: 60,
        bufferBeforeMinutes: 0,
        bufferAfterMinutes: 0,
        staffList: [_staff('s1'), _staff('s2')],
        businessHours: _hours9to17(),
        staffAvailability: [],
        staffBreaks: [],
        blockedRanges: [
          BlockedRange(
            staffProfileId: null,
            startDatetime: DateTime.utc(2027, 3, 15, 12, 0),
            endDatetime: DateTime.utc(2027, 3, 15, 13, 0),
            blockType: 'HOLIDAY',
          ),
        ],
        bookedRanges: [],
      );
      expect(slots.map((s) => s.startTime), isNot(contains('12:00')));
    });

    test('a staff-specific blocked time only blocks that staff', () {
      final slots = calculateAvailableSlots(
        date: _date,
        timezone: 'UTC',
        serviceDurationMinutes: 60,
        bufferBeforeMinutes: 0,
        bufferAfterMinutes: 0,
        staffList: [_staff('s1'), _staff('s2')],
        businessHours: _hours9to17(),
        staffAvailability: [],
        staffBreaks: [],
        blockedRanges: [
          BlockedRange(
            staffProfileId: 's1',
            startDatetime: DateTime.utc(2027, 3, 15, 12, 0),
            endDatetime: DateTime.utc(2027, 3, 15, 13, 0),
            blockType: 'VACATION',
          ),
        ],
        bookedRanges: [],
      );
      final noon = slots.firstWhere((s) => s.startTime == '12:00');
      expect(noon.availableStaffIds, ['s2']);
    });
  });

  group('calculateAvailableSlots — staff eligibility filtering', () {
    test('inactive or non-bookable staff never produce slots', () {
      final slots = calculateAvailableSlots(
        date: _date,
        timezone: 'UTC',
        serviceDurationMinutes: 60,
        bufferBeforeMinutes: 0,
        bufferAfterMinutes: 0,
        staffList: [
          _staff('s1', isActive: false),
          _staff('s2', isBookable: false),
        ],
        businessHours: _hours9to17(),
        staffAvailability: [],
        staffBreaks: [],
        blockedRanges: [],
        bookedRanges: [],
      );
      expect(slots, isEmpty);
    });
  });

  group('calculateAvailableSlots — buffers', () {
    test('buffer before/after shrinks the effective bookable window', () {
      final slots = calculateAvailableSlots(
        date: _date,
        timezone: 'UTC',
        serviceDurationMinutes: 30,
        bufferBeforeMinutes: 15,
        bufferAfterMinutes: 15,
        staffList: [_staff('s1')],
        businessHours: _hours9to17(),
        staffAvailability: [],
        staffBreaks: [],
        blockedRanges: [],
        bookedRanges: [],
      );
      // First slot can't start before 09:15 (buffer before eats into the
      // 09:00 window open), and must leave 15 min after a 30-min service
      // before 17:00, so the last slot start is 16:15.
      expect(slots.first.startTime, '09:15');
      expect(slots.last.startTime, '16:15');
    });
  });
}
