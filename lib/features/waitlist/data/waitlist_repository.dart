import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/waitlist_entry.dart';

class JoinWaitlistResult {
  final String status; // 'joined' | 'exists' | 'disabled'
  final String? entryId;
  const JoinWaitlistResult(this.status, this.entryId);
}

class WaitlistRepository {
  final SupabaseClient _client;

  WaitlistRepository(this._client);

  Future<JoinWaitlistResult> join({
    required String businessId,
    String? serviceId,
    String? staffProfileId,
    required String firstName,
    required String phone,
    String? email,
    DateTime? preferredDate,
    String? preferredTime,
    String? timeStart,
    String? timeEnd,
  }) async {
    try {
      final res = await _client.rpc('join_waitlist', params: {
        'p_business_id': businessId,
        'p_service_id': serviceId,
        'p_staff_profile_id': staffProfileId,
        'p_first_name': firstName,
        'p_phone': phone,
        'p_email': email,
        'p_preferred_date': preferredDate == null
            ? null
            : '${preferredDate.year.toString().padLeft(4, '0')}-'
                '${preferredDate.month.toString().padLeft(2, '0')}-'
                '${preferredDate.day.toString().padLeft(2, '0')}',
        'p_preferred_time': preferredTime,
        'p_time_start': timeStart,
        'p_time_end': timeEnd,
      });
      final map = (res as Map).cast<String, dynamic>();
      return JoinWaitlistResult(
        map['status'] as String? ?? 'unknown',
        map['entry_id'] as String?,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Leaves a waitlist entry. Guests pass [guestPhone] (the number they joined
  /// with). Returns true if the entry was cancelled.
  Future<bool> leave(String entryId, {String? guestPhone}) async {
    try {
      final res = await _client.rpc('leave_waitlist', params: {
        'p_entry_id': entryId,
        'p_phone': guestPhone,
      });
      final map = (res as Map).cast<String, dynamic>();
      return map['status'] == 'left';
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// The signed-in customer's own waitlist entries (RLS returns only theirs).
  Future<List<WaitlistEntry>> fetchMine(String userId) async {
    try {
      final data = await _client
          .from('waitlist_entries')
          .select(waitlistSelectColumns)
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => WaitlistEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// The business's waitlist (vendor view). Defaults to active entries only.
  Future<List<WaitlistEntry>> fetchForBusiness(
    String businessId, {
    bool activeOnly = true,
  }) async {
    try {
      var query = _client
          .from('waitlist_entries')
          .select(waitlistSelectColumns)
          .eq('business_id', businessId);
      if (activeOnly) query = query.eq('status', WaitlistStatus.active);
      final data = await query.order('created_at', ascending: true);
      return (data as List)
          .map((e) => WaitlistEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Guest waitlist: look up entries made on this device by id + phone.
  Future<List<WaitlistEntry>> fetchGuest(List<Map<String, String>> refs) async {
    try {
      final byPhone = <String, List<String>>{};
      for (final r in refs) {
        final id = r['id'];
        final phone = r['phone'];
        if (id == null || phone == null || phone.isEmpty) continue;
        byPhone.putIfAbsent(phone, () => []).add(id);
      }
      final out = <WaitlistEntry>[];
      for (final entry in byPhone.entries) {
        final data = await _client.rpc('get_guest_waitlist', params: {
          'p_ids': entry.value,
          'p_phone': entry.key,
        });
        for (final e in (data as List)) {
          out.add(WaitlistEntry.fromJson(e as Map<String, dynamic>));
        }
      }
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return out;
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
