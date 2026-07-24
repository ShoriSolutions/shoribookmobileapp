import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/appointment.dart';
import '../../../models/conversation.dart';
import '../../../models/message.dart';

/// One place for everything messaging-related: reading conversations and
/// messages (live via Supabase Realtime) and driving the write RPCs. UI
/// never touches Supabase directly.
class MessagingRepository {
  final SupabaseClient _client;
  MessagingRepository(this._client);

  static const _conversationCols = '''
    id, business_id, customer_id, customer_user_id, customer_display_name,
    appointment_id, type, last_message_at, last_message_preview,
    last_message_sender, vendor_archived, customer_archived, vendor_muted,
    customer_muted, vendor_last_read_at, customer_last_read_at,
    blocked_by_vendor, created_at, updated_at,
    businesses ( name, logo_url )
  ''';

  // Cache of businessId -> (name, logoUrl) so the customer's realtime list
  // (which streams join-less rows) can still show business names.
  final Map<String, ({String? name, String? logo})> _bizCache = {};

  // ── Live message thread ─────────────────────────────────────────────────
  Stream<List<Message>> watchMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows.map(Message.fromJson).toList());
  }

  // ── Live conversation list ──────────────────────────────────────────────
  /// [businessId] is required for the vendor side (scopes to that business);
  /// for the customer side pass their auth user id as [customerUserId].
  Stream<List<Conversation>> watchConversations({
    required bool asVendor,
    String? businessId,
    String? customerUserId,
  }) {
    final base = _client.from('conversations').stream(primaryKey: ['id']);
    final filtered = asVendor
        ? base.eq('business_id', businessId ?? '')
        : base.eq('customer_user_id', customerUserId ?? '');
    return filtered.order('last_message_at', ascending: false).asyncMap(
          (rows) => _enrich(rows, asVendor: asVendor),
        );
  }

  Future<List<Conversation>> _enrich(
    List<Map<String, dynamic>> rows, {
    required bool asVendor,
  }) async {
    // Vendor side shows customer names (already denormalised) — no join.
    if (asVendor) {
      return rows.map(Conversation.fromJson).toList();
    }
    // Customer side: attach business name/logo (fetch any uncached ids once).
    final ids = rows
        .map((r) => r['business_id'] as String)
        .where((id) => !_bizCache.containsKey(id))
        .toSet();
    if (ids.isNotEmpty) {
      final data = await _client
          .from('businesses')
          .select('id, name, logo_url')
          .inFilter('id', ids.toList());
      for (final b in (data as List)) {
        final m = b as Map<String, dynamic>;
        _bizCache[m['id'] as String] =
            (name: m['name'] as String?, logo: m['logo_url'] as String?);
      }
    }
    return rows.map((r) {
      final biz = _bizCache[r['business_id']];
      return Conversation.fromJson({
        ...r,
        'businesses': {'name': biz?.name, 'logo_url': biz?.logo},
      });
    }).toList();
  }

  /// One-shot joined fetch (used on first paint / pull-to-refresh).
  Future<List<Conversation>> fetchConversations({
    required bool asVendor,
    String? businessId,
  }) async {
    try {
      var q = _client.from('conversations').select(_conversationCols);
      if (asVendor && businessId != null) {
        q = q.eq('business_id', businessId);
      }
      final data = await q.order('last_message_at', ascending: false);
      return (data as List)
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Appointment?> fetchAppointment(String id) async {
    try {
      final data = await _client
          .from('appointments')
          .select(customerAppointmentSelectColumns)
          .eq('id', id)
          .maybeSingle();
      return data == null ? null : Appointment.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  // ── Write RPCs ───────────────────────────────────────────────────────────
  Future<String> getOrCreateConversation({
    required String businessId,
    String? appointmentId,
  }) async {
    try {
      final res = await _client.rpc('get_or_create_conversation', params: {
        'p_business_id': businessId,
        'p_appointment_id': appointmentId,
      });
      return res as String;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> sendMessage(
    String conversationId,
    String body, {
    String type = 'text',
    String? attachmentUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_conversation_id': conversationId,
        'p_body': body,
        'p_message_type': type,
      };
      // Only sent when present so text messages still work if the attachments
      // migration hasn't been applied yet.
      if (attachmentUrl != null) params['p_attachment_url'] = attachmentUrl;
      if (metadata != null) params['p_metadata'] = metadata;
      await _client.rpc('send_message', params: params);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Uploads a chat image to the private message-attachments bucket under
  /// the conversation's folder. Returns the storage PATH (not a URL) to
  /// store in messages.attachment_url; display via [signedAttachmentUrl].
  Future<String> uploadAttachment(
    String conversationId,
    Uint8List bytes, {
    String ext = 'jpg',
  }) async {
    try {
      final path =
          '$conversationId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage.from('message-attachments').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
              upsert: false,
            ),
          );
      return path;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// A short-lived signed URL for a private attachment path.
  Future<String> signedAttachmentUrl(String path) {
    return _client.storage
        .from('message-attachments')
        .createSignedUrl(path, 3600);
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _client.rpc('mark_conversation_read',
          params: {'p_conversation_id': conversationId});
    } catch (_) {
      // Non-fatal: read receipts are best-effort.
    }
  }

  Future<void> setFlag(String conversationId,
      {bool? mute, bool? archive}) async {
    try {
      await _client.rpc('set_conversation_flag', params: {
        'p_conversation_id': conversationId,
        'p_mute': mute,
        'p_archive': archive,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> setBlocked(String conversationId, bool blocked) async {
    try {
      await _client.rpc('set_conversation_blocked', params: {
        'p_conversation_id': conversationId,
        'p_blocked': blocked,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> report(String conversationId, String reason,
      {String? details}) async {
    try {
      await _client.rpc('report_conversation', params: {
        'p_conversation_id': conversationId,
        'p_reason': reason,
        'p_details': details,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> setBusinessMessagingSettings(
    String businessId, {
    bool? enabled,
    bool? preBooking,
  }) async {
    try {
      await _client.rpc('set_business_messaging_settings', params: {
        'p_business_id': businessId,
        'p_enabled': enabled,
        'p_pre_booking': preBooking,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<int> unreadCount() async {
    try {
      final res = await _client.rpc('unread_conversation_count');
      return (res as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Typing indicator via a Realtime broadcast channel (no DB write). Both
  /// sides join the same per-conversation channel.
  RealtimeChannel typingChannel(String conversationId) =>
      _client.channel('typing:$conversationId');
}
