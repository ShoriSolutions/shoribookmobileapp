import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/deposit_submission.dart';

class DepositVerificationRepository {
  final SupabaseClient _client;

  DepositVerificationRepository(this._client);

  /// Deposits awaiting review for the business (RLS scopes to OWNER/ADMIN).
  Future<List<DepositSubmission>> fetchPending(String businessId) async {
    try {
      final data = await _client
          .from('deposit_submissions')
          .select('id, appointment_id, amount, currency, proof_path, '
              'reference_number, customer_notes, status, created_at, '
              'appointments!inner ( customer_name, start_time, '
              'services ( name ) )')
          .eq('business_id', businessId)
          .eq('status', 'submitted')
          .order('created_at', ascending: true);
      return (data as List)
          .map((e) => DepositSubmission.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// The most recent proof-of-payment submission for a single appointment, or
  /// null if none. RLS scopes this to the owning business (OWNER/ADMIN), the
  /// submitting customer, or a Shorivo admin -- so it is safe to call from both
  /// the vendor and customer booking screens.
  Future<DepositSubmission?> fetchLatestForAppointment(
      String appointmentId) async {
    try {
      final data = await _client
          .from('deposit_submissions')
          .select('id, appointment_id, amount, currency, proof_path, '
              'reference_number, customer_notes, status, reject_reason, '
              'reject_notes, created_at')
          .eq('appointment_id', appointmentId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;
      return DepositSubmission.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// A short-lived signed URL for a private proof image path.
  Future<String> signedProofUrl(String path) {
    return _client.storage.from('deposit-proofs').createSignedUrl(path, 3600);
  }

  Future<bool> approve(String submissionId) async {
    try {
      final res = await _client
          .rpc('approve_deposit', params: {'p_submission_id': submissionId});
      return (res as Map)['status'] == 'approved';
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<bool> reject(String submissionId, String reason, String? notes) async {
    try {
      final res = await _client.rpc('reject_deposit', params: {
        'p_submission_id': submissionId,
        'p_reason': reason,
        'p_notes': notes,
      });
      return (res as Map)['status'] == 'rejected';
    } catch (e) {
      throw AppException.from(e);
    }
  }

}
