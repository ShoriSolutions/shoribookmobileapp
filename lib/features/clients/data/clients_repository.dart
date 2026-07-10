import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/appointment.dart';
import '../../../models/customer.dart';

class CustomerStats {
  final int totalAppointments;
  final int completedAppointments;
  final int cancelledAppointments;
  final int noShowAppointments;
  final double totalSpent;
  final DateTime? lastVisitDate;
  final DateTime? upcomingAppointmentDate;

  const CustomerStats({
    required this.totalAppointments,
    required this.completedAppointments,
    required this.cancelledAppointments,
    required this.noShowAppointments,
    required this.totalSpent,
    this.lastVisitDate,
    this.upcomingAppointmentDate,
  });

  static const zero = CustomerStats(
    totalAppointments: 0,
    completedAppointments: 0,
    cancelledAppointments: 0,
    noShowAppointments: 0,
    totalSpent: 0,
  );
}

class ClientsRepository {
  final SupabaseClient _client;

  ClientsRepository(this._client);

  Future<List<Customer>> fetchAll(String businessId) async {
    try {
      final data = await _client
          .from('customers')
          .select()
          .eq('business_id', businessId)
          .order('first_name', ascending: true);
      return (data as List)
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Customer> fetchById(String id) async {
    try {
      final data = await _client.from('customers').select().eq('id', id).single();
      return Customer.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Mirrors the web's clients/actions.ts `computeStats`: revenue only
  /// counts completed appointments, "upcoming" is the nearest future
  /// pending/confirmed appointment.
  Future<CustomerStats> fetchStats(String customerId) async {
    try {
      final data = await _client
          .from('appointments')
          .select('status, price, start_time')
          .eq('customer_id', customerId);

      final rows = (data as List).cast<Map<String, dynamic>>();
      final nowIso = DateTime.now().toUtc().toIso8601String();

      int total = 0, completed = 0, cancelled = 0, noShow = 0;
      double spent = 0;
      DateTime? lastVisit;
      DateTime? upcoming;

      for (final row in rows) {
        total++;
        final status = row['status'] as String;
        final startTime = row['start_time'] as String;
        if (status == AppointmentStatus.completed) {
          completed++;
          final price = (row['price'] as num?)?.toDouble();
          if (price != null) spent += price;
          final start = DateTime.parse(startTime);
          if (lastVisit == null || start.isAfter(lastVisit)) lastVisit = start;
        }
        if (status == AppointmentStatus.cancelled) cancelled++;
        if (status == AppointmentStatus.noShow) noShow++;
        if ((status == AppointmentStatus.confirmed ||
                status == AppointmentStatus.pending) &&
            startTime.compareTo(nowIso) > 0) {
          final start = DateTime.parse(startTime);
          if (upcoming == null || start.isBefore(upcoming)) upcoming = start;
        }
      }

      return CustomerStats(
        totalAppointments: total,
        completedAppointments: completed,
        cancelledAppointments: cancelled,
        noShowAppointments: noShow,
        totalSpent: spent,
        lastVisitDate: lastVisit,
        upcomingAppointmentDate: upcoming,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Appointment>> fetchHistory(String customerId) async {
    try {
      final data = await _client
          .from('appointments')
          .select(appointmentSelectColumns)
          .eq('customer_id', customerId)
          .order('start_time', ascending: false);
      return (data as List)
          .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Finds an existing customer by phone, or creates one — mirrors the
  /// web's upsert-by-phone behavior in appointments/actions.ts and
  /// api/book/route.ts (customers are unique per business+phone).
  Future<Customer> findOrCreateByPhone({
    required String businessId,
    required String firstName,
    String? lastName,
    required String phone,
    String? whatsappNumber,
    String? email,
  }) async {
    try {
      final existing = await _client
          .from('customers')
          .select()
          .eq('business_id', businessId)
          .eq('phone', phone.trim())
          .maybeSingle();

      if (existing != null) {
        final updated = await _client
            .from('customers')
            .update({
              'first_name': firstName.trim(),
              'last_name': lastName?.trim(),
              'whatsapp_number': whatsappNumber?.trim(),
              'email': email?.trim(),
            })
            .eq('id', existing['id'])
            .select()
            .single();
        return Customer.fromJson(updated);
      }

      final created = await _client
          .from('customers')
          .insert({
            'business_id': businessId,
            'first_name': firstName.trim(),
            'last_name': lastName?.trim(),
            'phone': phone.trim(),
            'whatsapp_number': whatsappNumber?.trim(),
            'email': email?.trim(),
          })
          .select()
          .single();
      return Customer.fromJson(created);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Customer>> search(String businessId, String query) async {
    try {
      final data = await _client
          .from('customers')
          .select()
          .eq('business_id', businessId)
          .or(
            'first_name.ilike.%$query%,last_name.ilike.%$query%,phone.ilike.%$query%,email.ilike.%$query%',
          )
          .order('first_name', ascending: true)
          .limit(30);
      return (data as List)
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> update(String id, Customer customer) async {
    try {
      await _client
          .from('customers')
          .update(customer.toUpdateJson())
          .eq('id', id);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> appendNote(String id, String note) async {
    try {
      final row = await _client
          .from('customers')
          .select('notes')
          .eq('id', id)
          .single();
      final existing = (row['notes'] as String?)?.trim() ?? '';
      final now = DateTime.now();
      final timestamp =
          '${_monthName(now.month)} ${now.day}, ${now.year}';
      final entry = '[$timestamp] ${note.trim()}';
      final updated = existing.isEmpty ? entry : '$existing\n\n$entry';
      await _client.from('customers').update({'notes': updated}).eq('id', id);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  String _monthName(int month) => const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][month - 1];
}
