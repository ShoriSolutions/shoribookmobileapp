import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/customer_trust.dart';

/// Reads the signed-in customer's own trust snapshot and booking
/// eligibility. All trust logic is server-side; this only reads it.
class TrustRepository {
  final SupabaseClient _client;

  TrustRepository(this._client);

  Future<CustomerTrust?> fetchMyTrust() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return null;
      final data = await _client
          .from('profiles')
          .select(
            'trust_score, no_show_count, warning_count, deposit_required, '
            'suspension_until, permanent_ban',
          )
          .eq('id', uid)
          .maybeSingle();
      return data == null ? null : CustomerTrust.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Server-calculated eligibility for the current user. Returns the RPC's
  /// map: { status: ok|warn|deposit_required|manual_approval|suspended|banned,
  /// trust_score, reputation, suspension_until, deposit_required }.
  Future<Map<String, dynamic>> checkBookingEligibility() async {
    try {
      final result = await _client.rpc('check_booking_eligibility');
      return (result as Map).cast<String, dynamic>();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
