import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/appointment.dart';

enum ManageBookingStatus { ok, conflict, unchanged }

class ManageBookingResult {
  final ManageBookingStatus status;
  final List<Map<String, dynamic>> conflicts;

  const ManageBookingResult({required this.status, this.conflicts = const []});
}

class MyBookingsRepository {
  final SupabaseClient _client;

  MyBookingsRepository(this._client);

  /// Relies entirely on the appointments_customer_self_select RLS policy
  /// (not an explicit .eq('customer_id', ...) filter) — a customer may
  /// have a different customers.id per business, so there's no single id
  /// to filter by client-side.
  Future<List<Appointment>> fetchMyBookings() async {
    try {
      final data = await _client
          .from('appointments')
          .select(customerAppointmentSelectColumns)
          .order('start_time', ascending: false);
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
          .select(customerAppointmentSelectColumns)
          .eq('id', id)
          .single();
      return Appointment.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<ManageBookingResult> cancel(String id) async {
    try {
      final result = await _client.rpc(
        'cancel_own_appointment',
        params: {'p_appointment_id': id},
      );
      final map = result as Map<String, dynamic>;
      return ManageBookingResult(
        status: map['status'] == 'unchanged'
            ? ManageBookingStatus.unchanged
            : ManageBookingStatus.ok,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<ManageBookingResult> reschedule(String id, DateTime newStart) async {
    try {
      final result = await _client.rpc(
        'reschedule_own_appointment',
        params: {
          'p_appointment_id': id,
          'p_new_start_time': newStart.toIso8601String(),
        },
      );
      final map = result as Map<String, dynamic>;
      switch (map['status']) {
        case 'conflict':
          return ManageBookingResult(
            status: ManageBookingStatus.conflict,
            conflicts: (map['conflicts'] as List).cast<Map<String, dynamic>>(),
          );
        case 'unchanged':
          return const ManageBookingResult(status: ManageBookingStatus.unchanged);
        default:
          return const ManageBookingResult(status: ManageBookingStatus.ok);
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
