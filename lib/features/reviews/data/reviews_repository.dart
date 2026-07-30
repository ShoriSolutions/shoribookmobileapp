import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/review.dart';

class ReviewsRepository {
  final SupabaseClient _client;

  ReviewsRepository(this._client);

  /// Reviews for a business. [publishedOnly] for the public profile; the vendor
  /// passes false to also see reported/flagged ones (RLS permitting). Reviewer
  /// first names are resolved from the public profiles table.
  Future<List<Review>> fetchForBusiness(
    String businessId, {
    bool publishedOnly = true,
    int limit = 50,
  }) async {
    try {
      var query =
          _client.from('reviews').select(reviewSelectColumns).eq('business_id', businessId);
      if (publishedOnly) query = query.eq('status', 'published');
      final rows = (await query.order('created_at', ascending: false).limit(limit))
          as List;
      return _withNames(rows.cast<Map<String, dynamic>>());
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// The signed-in customer's review for an appointment, if any (for the
  /// "already reviewed / edit" state).
  Future<Review?> fetchMineForAppointment(String appointmentId) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return null;
      final data = await _client
          .from('reviews')
          .select(reviewSelectColumns)
          .eq('appointment_id', appointmentId)
          .eq('user_id', uid)
          .maybeSingle();
      return data == null ? null : Review.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Review>> _withNames(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r['user_id'] as String).toSet().toList();
    final names = <String, String>{};
    try {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', ids) as List;
      for (final p in profiles) {
        final m = p as Map<String, dynamic>;
        final full = (m['full_name'] as String?)?.trim() ?? '';
        if (full.isNotEmpty) names[m['id'] as String] = full.split(' ').first;
      }
    } catch (_) {
      // Names are best-effort; fall back to "Customer".
    }
    return rows
        .map((r) => Review.fromJson(r, reviewerName: names[r['user_id']]))
        .toList();
  }

  /// Submit / edit / reply / report all go through the SECURITY DEFINER RPCs.
  /// Each returns the server 'status' string.
  Future<String> submit(String appointmentId, int rating, String? body) =>
      _rpc('submit_review', {
        'p_appointment_id': appointmentId,
        'p_rating': rating,
        'p_body': body,
      });

  Future<String> edit(String reviewId, int rating, String? body) =>
      _rpc('edit_review', {
        'p_review_id': reviewId,
        'p_rating': rating,
        'p_body': body,
      });

  Future<String> reply(String reviewId, String reply) =>
      _rpc('reply_to_review', {'p_review_id': reviewId, 'p_reply': reply});

  Future<String> reportOwn(String reviewId) =>
      _rpc('report_own_review', {'p_review_id': reviewId});

  Future<String> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      final res = await _client.rpc(fn, params: params);
      return (res as Map)['status'] as String? ?? 'error';
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
