import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/availability_models.dart';

/// Reads/writes the weekly business_hours rows behind the Availability
/// screen. Writes are replace-all (delete the business's rows, insert the
/// new set) — simpler and safe here since business_hours is leaf data
/// nothing references by id, and a settings save is a single-owner action.
class AvailabilityRepository {
  final SupabaseClient _client;

  AvailabilityRepository(this._client);

  Future<List<BusinessHours>> getBusinessHours(String businessId) async {
    try {
      final data = await _client
          .from('business_hours')
          .select()
          .eq('business_id', businessId)
          .order('day_of_week');
      return (data as List)
          .map((e) => BusinessHours.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> saveBusinessHours(
    String businessId,
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      await _client.from('business_hours').delete().eq('business_id', businessId);
      if (rows.isNotEmpty) {
        await _client.from('business_hours').insert(rows);
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }

  // ── Blocked time ──────────────────────────────────────────────────────────

  Future<List<BlockedTime>> getBlockedTimes(String businessId) async {
    try {
      final data = await _client
          .from('blocked_times')
          .select()
          .eq('business_id', businessId)
          .order('start_datetime');
      return (data as List)
          .map((e) => BlockedTime.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> addBlockedTime({
    required String businessId,
    required DateTime start,
    required DateTime end,
    String? reason,
  }) async {
    try {
      await _client.from('blocked_times').insert({
        'business_id': businessId,
        'staff_profile_id': null, // business-wide block
        'start_datetime': start.toUtc().toIso8601String(),
        'end_datetime': end.toUtc().toIso8601String(),
        'reason': (reason != null && reason.trim().isNotEmpty)
            ? reason.trim()
            : null,
        'block_type': 'MANUAL',
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> deleteBlockedTime(String id) async {
    try {
      await _client.from('blocked_times').delete().eq('id', id);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  // ── Special days ──────────────────────────────────────────────────────────

  Future<List<SpecialBusinessDay>> getSpecialDays(String businessId) async {
    try {
      final data = await _client
          .from('special_business_days')
          .select()
          .eq('business_id', businessId)
          .order('date');
      return (data as List)
          .map((e) => SpecialBusinessDay.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Upserts one special day. Replaces any existing row for the same
  /// (business, date) first, since that pair is unique.
  Future<void> addSpecialDay({
    required String businessId,
    required String date, // "YYYY-MM-DD"
    required bool isClosed,
    String? customOpenTime, // "HH:MM:SS"
    String? customCloseTime,
    String? note,
  }) async {
    try {
      await _client
          .from('special_business_days')
          .delete()
          .eq('business_id', businessId)
          .eq('date', date);
      await _client.from('special_business_days').insert({
        'business_id': businessId,
        'date': date,
        'is_closed': isClosed,
        'custom_open_time': isClosed ? null : customOpenTime,
        'custom_close_time': isClosed ? null : customCloseTime,
        'note': (note != null && note.trim().isNotEmpty) ? note.trim() : null,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> deleteSpecialDay(String id) async {
    try {
      await _client.from('special_business_days').delete().eq('id', id);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  // ── Staff weekly availability ─────────────────────────────────────────────

  Future<List<StaffAvailability>> getStaffAvailability(String staffId) async {
    try {
      final data = await _client
          .from('staff_availability')
          .select()
          .eq('staff_id', staffId)
          .order('day_of_week');
      return (data as List)
          .map((e) => StaffAvailability.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Replace-all save of a staff member's weekly availability (delete
  /// their rows, insert the new set). [rows] holds all 7 days, each with
  /// staff_id / day_of_week / start_time / end_time / is_available.
  Future<void> saveStaffAvailability(
    String staffId,
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      await _client.from('staff_availability').delete().eq('staff_id', staffId);
      if (rows.isNotEmpty) {
        await _client.from('staff_availability').insert(rows);
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
