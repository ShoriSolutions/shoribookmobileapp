import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import 'report_summary.dart';

class ReportsRepository {
  final SupabaseClient _client;

  ReportsRepository(this._client);

  /// Calls the get_business_report_summary RPC (backend/supabase/
  /// migrations/20260710000000_...sql), which itself enforces
  /// OWNER/ADMIN-only access server-side — see that file's comments for
  /// why the check has to live in SQL, not just the Dart UI layer.
  Future<ReportSummary> fetchSummary({
    required String businessId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final result = await _client.rpc(
        'get_business_report_summary',
        params: {
          'p_business_id': businessId,
          'p_start_date': _isoDate(startDate),
          'p_end_date': _isoDate(endDate),
        },
      );
      return ReportSummary.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
