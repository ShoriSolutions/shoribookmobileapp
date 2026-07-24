import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';

/// Registers this device's push token so the backend can deliver message
/// (and future booking) notifications. The token itself comes from
/// firebase_messaging once Firebase is configured for the app — call
/// [register] with `FirebaseMessaging.instance.getToken()` after login, and
/// [unregister] on sign-out. Until then these are safe no-op-friendly RPCs.
class PushTokensRepository {
  final SupabaseClient _client;
  PushTokensRepository(this._client);

  String get _platform => Platform.isIOS ? 'ios' : 'android';

  Future<void> register(String token) async {
    try {
      await _client.rpc('register_push_token',
          params: {'p_token': token, 'p_platform': _platform});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> unregister(String token) async {
    try {
      await _client.rpc('unregister_push_token', params: {'p_token': token});
    } catch (_) {
      // Best-effort on sign-out.
    }
  }
}
