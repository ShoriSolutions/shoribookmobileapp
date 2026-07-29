import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/deposit_payment_details.dart';

class DepositFlowRepository {
  final SupabaseClient _client;

  DepositFlowRepository(this._client);

  /// The business's FirstPay details + deposit summary for a pending-deposit
  /// booking. [guestPhone] is the number a guest booked with (null when authed).
  Future<DepositPaymentDetails> getPaymentDetails(
    String appointmentId, {
    String? guestPhone,
  }) async {
    try {
      final res = await _client.rpc('get_deposit_payment_details', params: {
        'p_appointment_id': appointmentId,
        'p_phone': guestPhone,
      });
      return DepositPaymentDetails.fromJson((res as Map).cast<String, dynamic>());
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Submits proof of payment. Authed customers upload to storage directly and
  /// record via the submit_deposit RPC; guests (no session) go through the
  /// submit-deposit-proof Edge Function. Returns the server status
  /// ('submitted' | 'not_pending' | ...).
  Future<String> submitProof({
    required String appointmentId,
    required String businessId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
    String? reference,
    String? notes,
    String? guestPhone,
  }) async {
    try {
      if (guestPhone != null && guestPhone.isNotEmpty) {
        final res = await _client.functions.invoke(
          'submit-deposit-proof',
          body: {
            'appointment_id': appointmentId,
            'phone': guestPhone,
            'image_base64': base64Encode(bytes),
            'content_type': contentType,
            'reference': reference,
            'notes': notes,
          },
        );
        final data = (res.data as Map?)?.cast<String, dynamic>();
        return data?['status'] as String? ?? 'error';
      }

      // Authed: upload to the private bucket, then record the submission.
      final ext = contentType == 'image/png'
          ? 'png'
          : contentType == 'image/webp'
              ? 'webp'
              : 'jpg';
      final path =
          '$businessId/$appointmentId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage.from('deposit-proofs').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      final res = await _client.rpc('submit_deposit', params: {
        'p_appointment_id': appointmentId,
        'p_proof_path': path,
        'p_reference': reference,
        'p_notes': notes,
      });
      return (res as Map)['status'] as String? ?? 'error';
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
