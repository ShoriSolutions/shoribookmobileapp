import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/review.dart';

class ReviewsRepository {
  final SupabaseClient _client;

  ReviewsRepository(this._client);

  /// Reviews for a business. [publishedOnly] for the public profile (visible =
  /// is_published AND status published); the vendor passes false to also see
  /// reported/flagged ones (RLS permitting). Reviewer name is the denormalized
  /// customer_name on the row.
  Future<List<Review>> fetchForBusiness(
    String businessId, {
    bool publishedOnly = true,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from('reviews')
          .select(reviewSelectColumns)
          .eq('business_id', businessId);
      if (publishedOnly) {
        query = query.eq('is_published', true).eq('status', 'published');
      }
      final rows = (await query
          .order('created_at', ascending: false)
          .limit(limit)) as List;
      return rows
          .map((r) => Review.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// The customer's review for an appointment, if any (for the "already
  /// reviewed / edit" state). One review per appointment, and RLS lets the
  /// appointment's owner read it.
  Future<Review?> fetchMineForAppointment(String appointmentId) async {
    try {
      final data = await _client
          .from('reviews')
          .select(reviewSelectColumns)
          .eq('appointment_id', appointmentId)
          .maybeSingle();
      return data == null ? null : Review.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
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
