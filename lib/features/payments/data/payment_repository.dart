import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/payment_profile.dart';

class PaymentRepository {
  final SupabaseClient _client;

  PaymentRepository(this._client);

  /// The business's profile for a provider (RLS: OWNER/ADMIN only), or null.
  Future<PaymentProfile?> fetchProfile(
    String businessId, {
    String provider = PaymentProvider.firstpay,
  }) async {
    try {
      final data = await _client
          .from('payment_profiles')
          .select('provider, details, deposit_instructions, payment_notes')
          .eq('business_id', businessId)
          .eq('provider', provider)
          .maybeSingle();
      return data == null ? null : PaymentProfile.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Saves (upserts) a payment profile. Returns the resulting status string
  /// ('ready' | 'setup_required').
  Future<String> save({
    required String businessId,
    String provider = PaymentProvider.firstpay,
    required Map<String, dynamic> details,
    String? depositInstructions,
    String? paymentNotes,
  }) async {
    try {
      final res = await _client.rpc('save_payment_profile', params: {
        'p_business_id': businessId,
        'p_provider': provider,
        'p_details': details,
        'p_deposit_instructions': depositInstructions,
        'p_payment_notes': paymentNotes,
      });
      final map = (res as Map).cast<String, dynamic>();
      return map['status'] as String? ?? 'setup_required';
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Whether the business has any fully-configured payment method (so deposits
  /// can be enabled). Mirrors the server-side prerequisite.
  Future<bool> hasReadyPaymentMethod(String businessId) async {
    try {
      final res = await _client.rpc('business_has_ready_payment_method',
          params: {'p_business_id': businessId});
      return res as bool? ?? false;
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
