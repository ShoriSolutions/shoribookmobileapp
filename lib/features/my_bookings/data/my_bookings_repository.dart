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

  /// Guest bookings: look up appointments made on this device by their
  /// ids, validated server-side against the phone used. [refs] is a list of
  /// {id, phone} maps from the on-device store.
  Future<List<Appointment>> fetchGuestBookings(
      List<Map<String, String>> refs) async {
    try {
      // Group ids by the phone they were booked with (usually just one).
      final byPhone = <String, List<String>>{};
      for (final r in refs) {
        final id = r['id'];
        final phone = r['phone'];
        if (id == null || phone == null || phone.isEmpty) continue;
        byPhone.putIfAbsent(phone, () => []).add(id);
      }
      final out = <Appointment>[];
      for (final entry in byPhone.entries) {
        final data = await _client.rpc('get_guest_appointments', params: {
          'p_ids': entry.value,
          'p_phone': entry.key,
        });
        for (final e in (data as List)) {
          out.add(Appointment.fromJson(e as Map<String, dynamic>));
        }
      }
      out.sort((a, b) => b.startTime.compareTo(a.startTime));
      return out;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Appointment> fetchGuestById(String id, String phone) async {
    try {
      final data = await _client.rpc('get_guest_appointments', params: {
        'p_ids': [id],
        'p_phone': phone,
      });
      final list = data as List;
      if (list.isEmpty) {
        throw const AppException('Booking not found.');
      }
      return Appointment.fromJson(list.first as Map<String, dynamic>);
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
