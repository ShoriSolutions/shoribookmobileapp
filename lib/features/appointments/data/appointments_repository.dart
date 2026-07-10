import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/timezone_offsets.dart';
import '../../../models/appointment.dart';

/// Result of a create_appointment_safe RPC call — see backend/supabase/
/// migrations/20260710000000_mobile_app_support.sql for the SQL side.
class CreateAppointmentResult {
  final bool isConflict;
  final String? appointmentId;
  final List<Map<String, dynamic>> conflicts;

  const CreateAppointmentResult({
    required this.isConflict,
    this.appointmentId,
    this.conflicts = const [],
  });
}

class AppointmentsRepository {
  final SupabaseClient _client;

  AppointmentsRepository(this._client);

  Future<List<Appointment>> fetchForDateRange({
    required String businessId,
    required String fromDate, // "YYYY-MM-DD" business-local, inclusive
    required String toDate,
    required String timezone,
    String? staffProfileId,
    String? status,
  }) async {
    try {
      final fromUtc = businessLocalToUtc(
        date: fromDate,
        time: '00:00',
        timezone: timezone,
      );
      final toUtc = businessLocalToUtc(
        date: toDate,
        time: '23:59',
        timezone: timezone,
      );

      var query = _client
          .from('appointments')
          .select(appointmentSelectColumns)
          .eq('business_id', businessId)
          .gte('start_time', fromUtc.toIso8601String())
          .lte('start_time', toUtc.toIso8601String());

      if (staffProfileId != null) {
        query = query.eq('staff_profile_id', staffProfileId);
      }
      if (status != null) {
        query = query.eq('status', status);
      }

      final data = await query.order('start_time', ascending: true);
      return (data as List)
          .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Appointment> fetchById(String id) async {
    try {
      final data = await _client
          .from('appointments')
          .select(appointmentSelectColumns)
          .eq('id', id)
          .single();
      return Appointment.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> updateStatus(String id, String status) async {
    try {
      await _client.from('appointments').update({'status': status}).eq(
        'id',
        id,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> markDepositPaid(
    String id, {
    required String paymentMethod,
    String? paymentReference,
    required bool autoConfirmIfPending,
  }) async {
    try {
      final updates = <String, dynamic>{
        'deposit_status': 'PAID',
        'deposit_paid': true,
        'payment_method': paymentMethod,
        'payment_reference': paymentReference?.trim().isEmpty == true
            ? null
            : paymentReference?.trim(),
        'deposit_paid_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (autoConfirmIfPending) {
        updates['status'] = AppointmentStatus.confirmed;
      }
      await _client.from('appointments').update(updates).eq('id', id);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> updateInternalNotes(String id, String appendedNote) async {
    try {
      final row = await _client
          .from('appointments')
          .select('internal_notes')
          .eq('id', id)
          .single();
      final existing = (row['internal_notes'] as String?)?.trim();
      final updated = (existing != null && existing.isNotEmpty)
          ? '$existing\n${appendedNote.trim()}'
          : appendedNote.trim();
      await _client
          .from('appointments')
          .update({'internal_notes': updated})
          .eq('id', id);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Reschedule / edit fields on an existing appointment. A lightweight
  /// pre-check (matching the web app's own behavior) is done by the
  /// caller before calling this — full atomic protection via
  /// create_appointment_safe is reserved for *new* bookings, where the
  /// race risk between two clients is highest.
  Future<void> updateFields(String id, Map<String, dynamic> updates) async {
    try {
      await _client.from('appointments').update(updates).eq('id', id);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Map<String, dynamic>>> checkConflicts({
    required String businessId,
    required String? staffProfileId,
    required DateTime startUtc,
    required DateTime endUtc,
    String? excludeAppointmentId,
  }) async {
    if (staffProfileId == null) return [];
    try {
      var query = _client
          .from('appointments')
          .select('id, customer_name, start_time, end_time')
          .eq('business_id', businessId)
          .eq('staff_profile_id', staffProfileId)
          .neq('status', AppointmentStatus.cancelled)
          .neq('status', AppointmentStatus.noShow)
          .lt('start_time', endUtc.toIso8601String())
          .gt('end_time', startUtc.toIso8601String());

      final data = await query as List;
      final rows = data.cast<Map<String, dynamic>>();
      if (excludeAppointmentId == null) return rows;
      return rows.where((r) => r['id'] != excludeAppointmentId).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Atomic, race-free booking creation via the create_appointment_safe
  /// Postgres RPC (backend/supabase/migrations/20260710000000_...sql).
  Future<CreateAppointmentResult> createAppointmentSafe({
    required String businessId,
    String? serviceId,
    String? staffProfileId,
    String? customerId,
    required DateTime startTime,
    required DateTime endTime,
    double? price,
    required String currency,
    required bool depositRequired,
    double? depositAmount,
    required String depositStatus,
    String? paymentMethod,
    String? paymentReference,
    required String status,
    required String bookingSource,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? notes,
    String? internalNotes,
    bool cancellationPolicyAccepted = false,
    bool forceOverride = false,
  }) async {
    try {
      final result = await _client.rpc(
        'create_appointment_safe',
        params: {
          'p_business_id': businessId,
          'p_service_id': serviceId,
          'p_staff_profile_id': staffProfileId,
          'p_customer_id': customerId,
          'p_start_time': startTime.toIso8601String(),
          'p_end_time': endTime.toIso8601String(),
          'p_price': price,
          'p_currency': currency,
          'p_deposit_required': depositRequired,
          'p_deposit_amount': depositAmount,
          'p_deposit_status': depositStatus,
          'p_payment_method': paymentMethod,
          'p_payment_reference': paymentReference,
          'p_status': status,
          'p_booking_source': bookingSource,
          'p_customer_name': customerName,
          'p_customer_phone': customerPhone,
          'p_customer_email': customerEmail,
          'p_notes': notes,
          'p_internal_notes': internalNotes,
          'p_cancellation_policy_accepted': cancellationPolicyAccepted,
          'p_force_override': forceOverride,
        },
      );

      final map = result as Map<String, dynamic>;
      if (map['status'] == 'conflict') {
        return CreateAppointmentResult(
          isConflict: true,
          conflicts: (map['conflicts'] as List)
              .cast<Map<String, dynamic>>(),
        );
      }
      return CreateAppointmentResult(
        isConflict: false,
        appointmentId: map['appointment_id'] as String,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
