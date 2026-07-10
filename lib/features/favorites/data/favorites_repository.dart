import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/business.dart';

class FavoritesRepository {
  final SupabaseClient _client;

  FavoritesRepository(this._client);

  Future<List<Business>> fetchFavoriteBusinesses(String userId) async {
    try {
      final data = await _client
          .from('customer_favorites')
          .select('business_id, businesses(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => e as Map<String, dynamic>)
          .where((e) => e['businesses'] != null)
          .map((e) => Business.fromJson(e['businesses'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Cheap heart-state lookup across many businesses at once — avoids an
  /// N+1 query per business card on Discover.
  Future<Set<String>> fetchFavoriteBusinessIds(String userId) async {
    try {
      final data = await _client
          .from('customer_favorites')
          .select('business_id')
          .eq('user_id', userId);
      return (data as List)
          .map((e) => (e as Map<String, dynamic>)['business_id'] as String)
          .toSet();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> addFavorite({
    required String userId,
    required String businessId,
  }) async {
    try {
      await _client.from('customer_favorites').insert({
        'user_id': userId,
        'business_id': businessId,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> removeFavorite({
    required String userId,
    required String businessId,
  }) async {
    try {
      await _client
          .from('customer_favorites')
          .delete()
          .eq('user_id', userId)
          .eq('business_id', businessId);
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
