import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/customer.dart';

enum CustomerBookingStatus {
  created,
  conflict,
  phoneConflict,
  notAcceptingBookings,
  rateLimited,
}

class CustomerBookingResult {
  final CustomerBookingStatus status;
  final String? appointmentId;
  final List<Map<String, dynamic>> conflicts;

  const CustomerBookingResult({
    required this.status,
    this.appointmentId,
    this.conflicts = const [],
  });
}

class CustomerBookingRepository {
  final SupabaseClient _client;

  CustomerBookingRepository(this._client);

  /// The logged-in customer's own existing contact record for this
  /// business, if any — used to prefill the wizard's details step
  /// instead of asking them to retype everything on a repeat booking.
  /// Relies on the customers_self_select RLS policy.
  Future<Customer?> fetchMyExistingCustomerRecord({
    required String businessId,
    required String userId,
  }) async {
    try {
      final data = await _client
          .from('customers')
          .select()
          .eq('business_id', businessId)
          .eq('user_id', userId)
          .maybeSingle();
      return data == null ? null : Customer.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Server-side smart-scheduling guard. Returns (available, reason) from
  /// the check_slot_available RPC, which enforces open hours, closures,
  /// manual blocks, buffer/overlap, and booking limits — the authoritative
  /// recheck before we attempt to create the appointment.
  /// Records the customer's IANA time zone on a just-created appointment
  /// (write-once, server-side). Best-effort — a failure never blocks the
  /// booking, which is already saved.
  Future<void> setAppointmentCustomerTimezone(
    String appointmentId,
    String timezone,
  ) async {
    try {
      await _client.rpc('set_appointment_customer_timezone', params: {
        'p_appointment_id': appointmentId,
        'p_timezone': timezone,
      });
    } catch (_) {
      // non-fatal
    }
  }

  /// Whether this phone is blocked from booking with the business — a
  /// polite pre-check before attempting to create the appointment (the DB
  /// also enforces it via a trigger).
  Future<bool> checkCustomerBlocked({
    required String businessId,
    required String phone,
  }) async {
    try {
      final res = await _client.rpc('check_customer_blocked', params: {
        'p_business_id': businessId,
        'p_phone': phone,
      });
      return res as bool? ?? false;
    } catch (_) {
      // Never let a pre-check failure block a legitimate booking; the DB
      // trigger remains the authoritative guard.
      return false;
    }
  }

  Future<({bool available, String? reason})> checkSlotAvailable({
    required String businessId,
    required String serviceId,
    String? staffProfileId,
    required DateTime startTime,
  }) async {
    try {
      final result = await _client.rpc('check_slot_available', params: {
        'p_business_id': businessId,
        'p_service_id': serviceId,
        'p_staff_profile_id': staffProfileId,
        'p_start_time': startTime.toIso8601String(),
      });
      final map = (result as Map).cast<String, dynamic>();
      return (
        available: map['available'] as bool? ?? false,
        reason: map['reason'] as String?,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<CustomerBookingResult> createAppointment({
    required String businessId,
    required String serviceId,
    String? staffProfileId,
    required DateTime startTime,
    required String firstName,
    String? lastName,
    required String phone,
    String? whatsapp,
    String? email,
    String? notes,
    required bool cancellationPolicyAccepted,
  }) async {
    try {
      final result = await _client.rpc(
        'create_customer_appointment_safe',
        params: {
          'p_business_id': businessId,
          'p_service_id': serviceId,
          'p_start_time': startTime.toIso8601String(),
          'p_customer_first_name': firstName,
          'p_customer_phone': phone,
          'p_staff_profile_id': staffProfileId,
          'p_customer_last_name': lastName,
          'p_customer_whatsapp': whatsapp,
          'p_customer_email': email,
          'p_notes': notes,
          'p_cancellation_policy_accepted': cancellationPolicyAccepted,
        },
      );

      final map = result as Map<String, dynamic>;
      switch (map['status']) {
        case 'conflict':
          return CustomerBookingResult(
            status: CustomerBookingStatus.conflict,
            conflicts: (map['conflicts'] as List).cast<Map<String, dynamic>>(),
          );
        case 'phone_conflict':
          return const CustomerBookingResult(
            status: CustomerBookingStatus.phoneConflict,
          );
        case 'not_accepting_bookings':
          return const CustomerBookingResult(
            status: CustomerBookingStatus.notAcceptingBookings,
          );
        case 'rate_limited':
          return const CustomerBookingResult(
            status: CustomerBookingStatus.rateLimited,
          );
        default:
          return CustomerBookingResult(
            status: CustomerBookingStatus.created,
            appointmentId: map['appointment_id'] as String,
          );
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
