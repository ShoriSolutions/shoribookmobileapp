import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/payment_provider_info.dart';

/// Central authority for payment-provider availability, country validation, and
/// region filtering. All provider eligibility flows through here -- no hardcoded
/// country checks elsewhere. Backed by the payment_providers registry so new
/// providers/countries need no app update.
class PaymentProviderService {
  final SupabaseClient _client;

  PaymentProviderService(this._client);

  Future<List<PaymentProviderInfo>> fetchProviders() async {
    try {
      final data = await _client
          .from('payment_providers')
          .select(
              'id, name, logo_asset, supported_countries, status, required_fields, sort_order')
          .order('sort_order', ascending: true);
      return (data as List)
          .map((e) => PaymentProviderInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// The platform default country (used when a business hasn't set its own).
  Future<String> defaultCountry() async {
    try {
      final row = await _client
          .from('app_config')
          .select('text_value')
          .eq('key', 'default_country_code')
          .maybeSingle();
      final v = (row?['text_value'] as String?)?.trim();
      return (v == null || v.isEmpty) ? 'BB' : v.toUpperCase();
    } catch (_) {
      return 'BB';
    }
  }

  Future<void> setBusinessCountry(String businessId, String code) async {
    try {
      await _client.rpc('set_business_country',
          params: {'p_business_id': businessId, 'p_country': code});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Providers configurable in [country] (active + supported).
  List<PaymentProviderInfo> availableIn(
          List<PaymentProviderInfo> all, String country) =>
      all
          .where((p) =>
              p.availabilityFor(country) == ProviderAvailability.available)
          .toList();
}
