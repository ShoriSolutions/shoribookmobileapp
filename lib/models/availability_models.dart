// Small, tightly-related models backing the "staff schedule" views —
// grouped in one file since each is a handful of fields with no
// independent lifecycle of its own.

class BusinessHours {
  final String id;
  final String businessId;
  final int dayOfWeek; // 0=Sunday..6=Saturday, matches Dart's convention below
  final String? openTime; // "HH:MM:SS"
  final String? closeTime;
  final bool isClosed;

  const BusinessHours({
    required this.id,
    required this.businessId,
    required this.dayOfWeek,
    this.openTime,
    this.closeTime,
    required this.isClosed,
  });

  factory BusinessHours.fromJson(Map<String, dynamic> json) => BusinessHours(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    dayOfWeek: json['day_of_week'] as int,
    openTime: json['open_time'] as String?,
    closeTime: json['close_time'] as String?,
    isClosed: json['is_closed'] as bool? ?? false,
  );
}

class StaffAvailability {
  final String id;
  final String staffId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isAvailable;

  const StaffAvailability({
    required this.id,
    required this.staffId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
  });

  factory StaffAvailability.fromJson(Map<String, dynamic> json) =>
      StaffAvailability(
        id: json['id'] as String,
        staffId: json['staff_id'] as String,
        dayOfWeek: json['day_of_week'] as int,
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        isAvailable: json['is_available'] as bool? ?? true,
      );
}

class StaffBreak {
  final String id;
  final String staffId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String? label;

  const StaffBreak({
    required this.id,
    required this.staffId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.label,
  });

  factory StaffBreak.fromJson(Map<String, dynamic> json) => StaffBreak(
    id: json['id'] as String,
    staffId: json['staff_id'] as String,
    dayOfWeek: json['day_of_week'] as int,
    startTime: json['start_time'] as String,
    endTime: json['end_time'] as String,
    label: json['label'] as String?,
  );
}

class BlockedTime {
  final String id;
  final String businessId;
  final String? staffProfileId;
  final DateTime startDatetime;
  final DateTime endDatetime;
  final String? reason;
  final String blockType;

  const BlockedTime({
    required this.id,
    required this.businessId,
    this.staffProfileId,
    required this.startDatetime,
    required this.endDatetime,
    this.reason,
    required this.blockType,
  });

  factory BlockedTime.fromJson(Map<String, dynamic> json) => BlockedTime(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    staffProfileId: json['staff_profile_id'] as String?,
    startDatetime: DateTime.parse(json['start_datetime'] as String),
    endDatetime: DateTime.parse(json['end_datetime'] as String),
    reason: json['reason'] as String?,
    blockType: json['block_type'] as String? ?? 'MANUAL',
  );
}

class SpecialBusinessDay {
  final String id;
  final String businessId;
  final String date; // "YYYY-MM-DD"
  final bool isClosed;
  final String? customOpenTime;
  final String? customCloseTime;
  final String? note;

  const SpecialBusinessDay({
    required this.id,
    required this.businessId,
    required this.date,
    required this.isClosed,
    this.customOpenTime,
    this.customCloseTime,
    this.note,
  });

  factory SpecialBusinessDay.fromJson(Map<String, dynamic> json) =>
      SpecialBusinessDay(
        id: json['id'] as String,
        businessId: json['business_id'] as String,
        date: json['date'] as String,
        isClosed: json['is_closed'] as bool? ?? false,
        customOpenTime: json['custom_open_time'] as String?,
        customCloseTime: json['custom_close_time'] as String?,
        note: json['note'] as String?,
      );
}

/// A busy time range for one staff member, as returned by the
/// get_booked_appointment_ranges RPC — deliberately minimal (no
/// customer PII, matching what that privileged function returns).
class BookedRange {
  final String? staffProfileId;
  final DateTime startTime;
  final DateTime endTime;

  const BookedRange({
    this.staffProfileId,
    required this.startTime,
    required this.endTime,
  });

  factory BookedRange.fromJson(Map<String, dynamic> json) => BookedRange(
    staffProfileId: json['staff_profile_id'] as String?,
    startTime: DateTime.parse(json['start_time'] as String),
    endTime: DateTime.parse(json['end_time'] as String),
  );
}

/// A blocked time range, as returned by the get_blocked_time_ranges RPC
/// — deliberately omits the free-text `reason` field that function
/// doesn't return.
class BlockedRange {
  final String? staffProfileId;
  final DateTime startDatetime;
  final DateTime endDatetime;
  final String blockType;

  const BlockedRange({
    this.staffProfileId,
    required this.startDatetime,
    required this.endDatetime,
    required this.blockType,
  });

  factory BlockedRange.fromJson(Map<String, dynamic> json) => BlockedRange(
    staffProfileId: json['staff_profile_id'] as String?,
    startDatetime: DateTime.parse(json['start_datetime'] as String),
    endDatetime: DateTime.parse(json['end_datetime'] as String),
    blockType: json['block_type'] as String? ?? 'MANUAL',
  );
}

const List<String> weekdayLabels = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];
