class Business {
  final String id;
  final String ownerId;
  final String name;
  final String slug;
  final String? category;
  final String? description;
  final String? logoUrl;
  final String? coverImageUrl;
  final String? phone;
  final String? email;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String timezone;
  final String currency;
  final String? whatsappNumber;
  final String? googleMapsUrl;
  final String? instagramUrl;
  final String? facebookUrl;
  final String? tiktokUrl;
  final bool bookingEnabled;
  final bool messagingEnabled;
  final bool preBookingMessagingEnabled;
  final bool messagingRestrictAfterHours;
  final bool isPublished;
  final bool isMarketplaceListed;
  final bool featuredRequested;
  final int bufferMinutes; // buffer before/after each appointment
  final int? maxBookingsPerDay; // null = no limit
  final int? maxBookingsPerHour;
  final int? maxSimultaneousBookings;
  // Booking confirmation window: when on, online no-deposit bookings must be
  // confirmed within [confirmationWindowMinutes] or they auto-cancel.
  final bool requireConfirmation;
  final int confirmationWindowMinutes;
  final bool waitlistEnabled; // reserved for Phase 2 (waitlist notifications)
  // 'none' | 'trialing' | 'trial_pending' | 'active' | 'past_due' | 'canceled'
  final String subscriptionStatus;
  final DateTime? trialEndsAt;
  final bool autoRenew;
  final String billingPeriod; // 'monthly' | 'yearly'
  final DateTime? currentPeriodEnd;
  final String? subscriptionPackageId; // the active paid plan (null on trial)
  final String? countryCode; // ISO 3166-1 alpha-2, for price display currency
  final DateTime? nameCategoryLockedUntil;
  final String status;
  final List<String> badges;
  final List<String> galleryUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Business({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.slug,
    this.category,
    this.description,
    this.logoUrl,
    this.coverImageUrl,
    this.phone,
    this.email,
    this.address,
    this.latitude,
    this.longitude,
    required this.timezone,
    required this.currency,
    this.whatsappNumber,
    this.googleMapsUrl,
    this.instagramUrl,
    this.facebookUrl,
    this.tiktokUrl,
    required this.bookingEnabled,
    this.messagingEnabled = true,
    this.preBookingMessagingEnabled = true,
    this.messagingRestrictAfterHours = true,
    this.isPublished = true,
    this.isMarketplaceListed = true,
    this.featuredRequested = false,
    this.bufferMinutes = 0,
    this.maxBookingsPerDay,
    this.maxBookingsPerHour,
    this.maxSimultaneousBookings,
    this.requireConfirmation = false,
    this.confirmationWindowMinutes = 120,
    this.waitlistEnabled = false,
    this.subscriptionStatus = 'none',
    this.trialEndsAt,
    this.autoRenew = true,
    this.billingPeriod = 'monthly',
    this.currentPeriodEnd,
    this.subscriptionPackageId,
    this.countryCode,
    this.nameCategoryLockedUntil,
    required this.status,
    required this.badges,
    this.galleryUrls = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether the business can use the paid app right now: an active paid
  /// subscription, or a trial that hasn't expired yet. 'none' (never
  /// trialed) and an expired trial both count as no access.
  bool get hasActiveAccess {
    if (subscriptionStatus == 'active') return true;
    if (subscriptionStatus == 'trialing') {
      final ends = trialEndsAt;
      return ends != null && ends.isAfter(DateTime.now());
    }
    return false;
  }

  /// True once a trial was started but has now run out (and not converted).
  bool get trialExpired =>
      subscriptionStatus == 'trialing' &&
      trialEndsAt != null &&
      !trialEndsAt!.isAfter(DateTime.now());

  factory Business.fromJson(Map<String, dynamic> json) => Business(
    id: json['id'] as String,
    ownerId: json['owner_id'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String,
    category: json['category'] as String?,
    description: json['description'] as String?,
    logoUrl: json['logo_url'] as String?,
    coverImageUrl: json['cover_image_url'] as String?,
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    address: json['address'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    timezone: json['timezone'] as String? ?? 'America/Barbados',
    currency: json['currency'] as String? ?? 'BBD',
    whatsappNumber: json['whatsapp_number'] as String?,
    googleMapsUrl: json['google_maps_url'] as String?,
    instagramUrl: json['instagram_url'] as String?,
    facebookUrl: json['facebook_url'] as String?,
    tiktokUrl: json['tiktok_url'] as String?,
    bookingEnabled: json['booking_enabled'] as bool? ?? true,
    messagingEnabled: json['messaging_enabled'] as bool? ?? true,
    preBookingMessagingEnabled:
        json['pre_booking_messaging_enabled'] as bool? ?? true,
    messagingRestrictAfterHours:
        json['messaging_restrict_after_hours'] as bool? ?? true,
    isPublished: json['is_published'] as bool? ?? true,
    isMarketplaceListed: json['is_marketplace_listed'] as bool? ?? true,
    featuredRequested: json['featured_requested'] as bool? ?? false,
    bufferMinutes: json['buffer_minutes'] as int? ?? 0,
    maxBookingsPerDay: json['max_bookings_per_day'] as int?,
    maxBookingsPerHour: json['max_bookings_per_hour'] as int?,
    maxSimultaneousBookings: json['max_simultaneous_bookings'] as int?,
    requireConfirmation: json['require_confirmation'] as bool? ?? false,
    confirmationWindowMinutes:
        json['confirmation_window_minutes'] as int? ?? 120,
    waitlistEnabled: json['waitlist_enabled'] as bool? ?? false,
    subscriptionStatus: json['subscription_status'] as String? ?? 'none',
    trialEndsAt: json['trial_ends_at'] == null
        ? null
        : DateTime.parse(json['trial_ends_at'] as String),
    autoRenew: json['auto_renew'] as bool? ?? true,
    billingPeriod: json['billing_period'] as String? ?? 'monthly',
    currentPeriodEnd: json['current_period_end'] == null
        ? null
        : DateTime.parse(json['current_period_end'] as String),
    subscriptionPackageId: json['subscription_package_id'] as String?,
    countryCode: json['country_code'] as String?,
    nameCategoryLockedUntil: json['name_category_locked_until'] == null
        ? null
        : DateTime.parse(json['name_category_locked_until'] as String),
    status: json['status'] as String? ?? 'accepting_bookings',
    badges:
        (json['badges'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        const [],
    galleryUrls:
        (json['gallery_urls'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const [],
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_id': ownerId,
    'name': name,
    'slug': slug,
    'category': category,
    'description': description,
    'logo_url': logoUrl,
    'cover_image_url': coverImageUrl,
    'phone': phone,
    'email': email,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'currency': currency,
    'whatsapp_number': whatsappNumber,
    'google_maps_url': googleMapsUrl,
    'instagram_url': instagramUrl,
    'facebook_url': facebookUrl,
    'tiktok_url': tiktokUrl,
    'booking_enabled': bookingEnabled,
    'messaging_enabled': messagingEnabled,
    'pre_booking_messaging_enabled': preBookingMessagingEnabled,
    'messaging_restrict_after_hours': messagingRestrictAfterHours,
    'is_published': isPublished,
    'is_marketplace_listed': isMarketplaceListed,
    'featured_requested': featuredRequested,
    'buffer_minutes': bufferMinutes,
    'max_bookings_per_day': maxBookingsPerDay,
    'max_bookings_per_hour': maxBookingsPerHour,
    'max_simultaneous_bookings': maxSimultaneousBookings,
    'require_confirmation': requireConfirmation,
    'confirmation_window_minutes': confirmationWindowMinutes,
    'waitlist_enabled': waitlistEnabled,
    'subscription_status': subscriptionStatus,
    'trial_ends_at': trialEndsAt?.toIso8601String(),
    'auto_renew': autoRenew,
    'billing_period': billingPeriod,
    'current_period_end': currentPeriodEnd?.toIso8601String(),
    'subscription_package_id': subscriptionPackageId,
    'country_code': countryCode,
    'name_category_locked_until': nameCategoryLockedUntil?.toIso8601String(),
    'status': status,
    'badges': badges,
    'gallery_urls': galleryUrls,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// Explicit column list for public/marketplace business reads. It's every
/// field the [Business] model needs, but deliberately excludes the sensitive
/// store columns (subscription_token, subscription_store, subscription_period_end)
/// which the anon role isn't granted — so guest browsing never exposes them.
const String businessMarketplaceColumns = '''
  id, owner_id, name, slug, category, description, logo_url, cover_image_url,
  phone, email, address, latitude, longitude, timezone, currency,
  whatsapp_number, google_maps_url, instagram_url, facebook_url, tiktok_url,
  booking_enabled, messaging_enabled, pre_booking_messaging_enabled,
  messaging_restrict_after_hours, is_published, is_marketplace_listed,
  featured_requested, buffer_minutes, max_bookings_per_day,
  max_bookings_per_hour, max_simultaneous_bookings, subscription_status,
  trial_ends_at, auto_renew, billing_period, current_period_end,
  subscription_package_id, country_code, name_category_locked_until, status,
  badges, gallery_urls, created_at, updated_at
''';

/// The service-category taxonomy, matching the web app's entrepreneur
/// registration form exactly (src/app/(auth)/register/entrepreneur/
/// page.tsx CATEGORIES) — used both there for a business to pick its own
/// category and here for the marketplace's category filter chips.
class BusinessCategory {
  final String value;
  final String label;
  final String emoji;

  const BusinessCategory(this.value, this.label, this.emoji);

  static const all = [
    BusinessCategory('barber', 'Barber / Barbershop', '✂️'),
    BusinessCategory('nail_tech', 'Nail Technician', '💅'),
    BusinessCategory('lash_artist', 'Lash Artist', '👁'),
    BusinessCategory('personal_trainer', 'Personal Trainer', '💪'),
    BusinessCategory('esthetician', 'Esthetician', '🌿'),
    BusinessCategory('brow_artist', 'Brow Artist', '✨'),
    BusinessCategory('hair_stylist', 'Hair Stylist', '💇'),
    BusinessCategory('other', 'Other', '➕'),
  ];

  static String labelFor(String? value) {
    if (value == null) return 'Other';
    return all
        .firstWhere(
          (c) => c.value == value,
          orElse: () => const BusinessCategory('other', 'Other', '➕'),
        )
        .label;
  }
}
