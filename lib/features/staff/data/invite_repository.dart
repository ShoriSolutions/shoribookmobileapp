import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';

/// Calls the invite-staff Edge Function (backend/supabase/functions/
/// invite-staff) — the only place OWNER/ADMIN can grant a teammate app
/// access. Never touches the service-role key; the function itself
/// re-verifies the caller's OWNER/ADMIN membership server-side before
/// doing anything privileged.
class InviteRepository {
  final SupabaseClient _client;

  InviteRepository(this._client);

  Future<void> inviteStaff({
    required String businessId,
    required String email,
    required String role, // 'ADMIN' | 'STAFF'
  }) async {
    try {
      final response = await _client.functions.invoke(
        'invite-staff',
        body: {'business_id': businessId, 'email': email, 'role': role},
      );

      if (response.status != 200) {
        final data = response.data;
        final message = (data is Map && data['message'] != null)
            ? data['message'] as String
            : 'Could not send invite (status ${response.status})';
        throw AppException(message);
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
