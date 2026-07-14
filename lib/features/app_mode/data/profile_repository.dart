import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/profile.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  Future<Profile?> fetchMyProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return data == null ? null : Profile.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Updates the caller's own editable profile fields (name, phone, avatar)
  /// via the update_my_profile RPC. Email and role are never changed here —
  /// email changes go through support. A null [avatarUrl] removes the photo.
  Future<void> updateMyProfile({
    required String fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    try {
      await _client.rpc('update_my_profile', params: {
        'p_full_name': fullName,
        'p_phone': phone,
        'p_avatar_url': avatarUrl,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Uploads a new avatar to the public 'avatars' bucket at
  /// `<userId>/avatar.<ext>`, overwriting any previous one. A cache-busting
  /// query keeps the same-path upload from serving a stale image. Returns
  /// the public URL (store it with [updateMyProfile]).
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    try {
      final ext = fileExtension.toLowerCase() == 'png' ? 'png' : 'jpg';
      final path = '$userId/avatar.$ext';
      await _client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
            ),
          );
      return '${_client.storage.from('avatars').getPublicUrl(path)}'
          '?v=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
