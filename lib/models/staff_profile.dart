class StaffProfile {
  final String id;
  final String businessId;
  final String? memberId;
  final String name;
  final String? role;
  final String? bio;
  final String? profileImageUrl;
  final String? email;
  final String? phone;
  final String? instagramUrl;
  final bool isActive;
  final bool isBookable;
  final int displayOrder;

  const StaffProfile({
    required this.id,
    required this.businessId,
    this.memberId,
    required this.name,
    this.role,
    this.bio,
    this.profileImageUrl,
    this.email,
    this.phone,
    this.instagramUrl,
    required this.isActive,
    required this.isBookable,
    required this.displayOrder,
  });

  factory StaffProfile.fromJson(Map<String, dynamic> json) => StaffProfile(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    memberId: json['member_id'] as String?,
    name: json['name'] as String,
    role: json['role'] as String?,
    bio: json['bio'] as String?,
    profileImageUrl: json['profile_image_url'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    instagramUrl: json['instagram_url'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    isBookable: json['is_bookable'] as bool? ?? true,
    displayOrder: json['display_order'] as int? ?? 0,
  );

  Map<String, dynamic> toInsertJson(String businessId) => {
    'business_id': businessId,
    'name': name,
    'role': role,
    'bio': bio,
    'profile_image_url': profileImageUrl,
    'email': email,
    'phone': phone,
    'instagram_url': instagramUrl,
    'is_active': isActive,
    'is_bookable': isBookable,
  };
}
