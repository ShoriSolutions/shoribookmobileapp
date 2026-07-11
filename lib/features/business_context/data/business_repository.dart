import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/business.dart';
import '../../../models/business_role.dart';
import 'active_membership.dart';

class BusinessRepository {
  final SupabaseClient _client;

  BusinessRepository(this._client);

  /// Mirrors the web's getActiveMembership: the first ACTIVE membership
  /// by created_at. The web app has no multi-business switcher either
  /// (it just takes the first row), so this matches it for parity —
  /// only ACTIVE (not INVITED) memberships resolve to a usable context.
  Future<ActiveMembership?> getActiveMembership(String userId) async {
    try {
      final data = await _client
          .from('business_members')
          .select('id, role, status, businesses(*)')
          .eq('user_id', userId)
          .eq('status', 'ACTIVE')
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;

      final businessJson = data['businesses'] as Map<String, dynamic>?;
      if (businessJson == null) return null;

      final membershipId = data['id'] as String;
      final role = BusinessRole.fromString(data['role'] as String);
      final business = Business.fromJson(businessJson);

      final staffProfileId = await _findLinkedStaffProfileId(
        businessId: business.id,
        memberId: membershipId,
      );

      return ActiveMembership(
        membershipId: membershipId,
        role: role,
        business: business,
        staffProfileId: staffProfileId,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// All ACTIVE memberships for this user — used only for a future
  /// multi-business switcher; the MVP always uses the first one.
  Future<List<Map<String, dynamic>>> getAllMemberships(String userId) async {
    try {
      final data = await _client
          .from('business_members')
          .select('id, role, status, businesses(*)')
          .eq('user_id', userId)
          .eq('status', 'ACTIVE')
          .order('created_at', ascending: true);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Updates the business's public-visibility flags (Profile &
  /// Marketplace screen). Only the flags passed are changed. RLS scopes
  /// this to OWNER/ADMIN of the business, same as the web dashboard.
  Future<void> updateVisibility(
    String businessId, {
    bool? isPublished,
    bool? isMarketplaceListed,
    bool? bookingEnabled,
  }) async {
    try {
      final patch = <String, dynamic>{};
      if (isPublished != null) patch['is_published'] = isPublished;
      if (isMarketplaceListed != null) {
        patch['is_marketplace_listed'] = isMarketplaceListed;
      }
      if (bookingEnabled != null) patch['booking_enabled'] = bookingEnabled;
      if (patch.isEmpty) return;
      patch['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _client.from('businesses').update(patch).eq('id', businessId);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Updates all editable profile fields via the update_business_profile
  /// RPC (which enforces the 90-day name/category lock server-side).
  /// Returns the RPC result — its 'status' is 'locked' if a name/category
  /// change was rejected by the cooldown.
  Future<Map<String, dynamic>?> updateBusinessProfile({
    required String businessId,
    required String name,
    String? category,
    String? description,
    String? phone,
    String? email,
    String? address,
    String? whatsappNumber,
    String? instagramUrl,
    String? facebookUrl,
    String? tiktokUrl,
    String? googleMapsUrl,
    List<String>? badges,
    bool? featuredRequested,
  }) async {
    try {
      final result = await _client.rpc('update_business_profile', params: {
        'p_business_id': businessId,
        'p_name': name,
        'p_category': category,
        'p_description': description,
        'p_phone': phone,
        'p_email': email,
        'p_address': address,
        'p_whatsapp_number': whatsappNumber,
        'p_instagram_url': instagramUrl,
        'p_facebook_url': facebookUrl,
        'p_tiktok_url': tiktokUrl,
        'p_google_maps_url': googleMapsUrl,
        'p_badges': badges,
        'p_featured_requested': featuredRequested,
      });
      return (result as Map?)?.cast<String, dynamic>();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Uploads a logo or cover image to the public business-images bucket
  /// (path is the business id, then "logo"/"cover" plus the extension)
  /// and stores the resulting URL on the business. A cache-busting query
  /// keeps the same-path upload from serving a stale cached image.
  /// Returns the new URL.
  Future<String> uploadBusinessImage({
    required String businessId,
    required bool isCover,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    try {
      final ext = fileExtension.toLowerCase() == 'png' ? 'png' : 'jpg';
      final path = '$businessId/${isCover ? 'cover' : 'logo'}.$ext';
      await _client.storage.from('business-images').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
            ),
          );
      final url =
          '${_client.storage.from('business-images').getPublicUrl(path)}'
          '?v=${DateTime.now().millisecondsSinceEpoch}';
      await _client.from('businesses').update({
        (isCover ? 'cover_image_url' : 'logo_url'): url,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', businessId);
      return url;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<String?> _findLinkedStaffProfileId({
    required String businessId,
    required String memberId,
  }) async {
    final row = await _client
        .from('staff_profiles')
        .select('id')
        .eq('business_id', businessId)
        .eq('member_id', memberId)
        .maybeSingle();
    return row?['id'] as String?;
  }
}
