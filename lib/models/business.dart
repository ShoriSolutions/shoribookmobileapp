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
  final String timezone;
  final String currency;
  final String? whatsappNumber;
  final String? googleMapsUrl;
  final String? instagramUrl;
  final String? facebookUrl;
  final String? tiktokUrl;
  final bool bookingEnabled;
  final bool isPublished;
  final bool isMarketplaceListed;
  final bool featuredRequested;
  final DateTime? nameCategoryLockedUntil;
  final String status;
  final List<String> badges;
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
    required this.timezone,
    required this.currency,
    this.whatsappNumber,
    this.googleMapsUrl,
    this.instagramUrl,
    this.facebookUrl,
    this.tiktokUrl,
    required this.bookingEnabled,
    this.isPublished = true,
    this.isMarketplaceListed = true,
    this.featuredRequested = false,
    this.nameCategoryLockedUntil,
    required this.status,
    required this.badges,
    required this.createdAt,
    required this.updatedAt,
  });

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
    timezone: json['timezone'] as String? ?? 'America/Barbados',
    currency: json['currency'] as String? ?? 'BBD',
    whatsappNumber: json['whatsapp_number'] as String?,
    googleMapsUrl: json['google_maps_url'] as String?,
    instagramUrl: json['instagram_url'] as String?,
    facebookUrl: json['facebook_url'] as String?,
    tiktokUrl: json['tiktok_url'] as String?,
    bookingEnabled: json['booking_enabled'] as bool? ?? true,
    isPublished: json['is_published'] as bool? ?? true,
    isMarketplaceListed: json['is_marketplace_listed'] as bool? ?? true,
    featuredRequested: json['featured_requested'] as bool? ?? false,
    nameCategoryLockedUntil: json['name_category_locked_until'] == null
        ? null
        : DateTime.parse(json['name_category_locked_until'] as String),
    status: json['status'] as String? ?? 'accepting_bookings',
    badges:
        (json['badges'] as List<dynamic>?)?.map((e) => e as String).toList() ??
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
    'timezone': timezone,
    'currency': currency,
    'whatsapp_number': whatsappNumber,
    'google_maps_url': googleMapsUrl,
    'instagram_url': instagramUrl,
    'facebook_url': facebookUrl,
    'tiktok_url': tiktokUrl,
    'booking_enabled': bookingEnabled,
    'is_published': isPublished,
    'is_marketplace_listed': isMarketplaceListed,
    'featured_requested': featuredRequested,
    'name_category_locked_until': nameCategoryLockedUntil?.toIso8601String(),
    'status': status,
    'badges': badges,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

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
