import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/customer.dart';

enum CustomerBookingStatus { created, conflict, phoneConflict, notAcceptingBookings }

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
