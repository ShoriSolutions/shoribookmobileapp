import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/notification_settings.dart';

/// Reads/writes vendor notification settings, customer preferences, and
/// reminder history. Reminder scheduling itself is entirely server-side.
class NotificationsRepository {
  final SupabaseClient _client;

  NotificationsRepository(this._client);

  Future<NotificationSettings> getSettings(String businessId) async {
    try {
      final data = await _client
          .from('notification_settings')
          .select()
          .eq('business_id', businessId)
          .maybeSingle();
      return data == null
          ? NotificationSettings.defaults
          : NotificationSettings.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> saveSettings(
    String businessId,
    NotificationSettings s,
  ) async {
    try {
      await _client.rpc('save_notification_settings', params: {
        'p_business_id': businessId,
        'p_push': s.pushEnabled,
        'p_email': s.emailEnabled,
        'p_whatsapp': s.whatsappEnabled,
        'p_sms': s.smsEnabled,
        'p_offsets': s.reminderOffsets,
        'p_template': s.reminderTemplate,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Recent reminder-queue rows for a business (delivery history).
  Future<List<Map<String, dynamic>>> getHistory(
    String businessId, {
    int limit = 50,
  }) async {
    try {
      final data = await _client
          .from('reminder_queue')
          .select('channel, scheduled_for, status, sent_at, retry_count, error_message')
          .eq('business_id', businessId)
          .order('scheduled_for', ascending: false)
          .limit(limit);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  // ── Customer preferences ────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getMyPreferences() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return null;
      return await _client
          .from('customer_notification_preferences')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> savePreferences({
    required bool push,
    required bool whatsapp,
    required bool email,
    required bool promotionalOptOut,
  }) async {
    try {
      await _client.rpc('save_notification_preferences', params: {
        'p_push': push,
        'p_whatsapp': whatsapp,
        'p_email': email,
        'p_promo_opt_out': promotionalOptOut,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
