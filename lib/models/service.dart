class Service {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final String? category;
  final int durationMinutes;
  final double price;
  final String currency;
  final bool depositRequired;
  final double? depositAmount;
  final String depositType; // 'FIXED' | 'PERCENTAGE'
  final double? depositPercentage;
  final int bufferBeforeMinutes;
  final int bufferAfterMinutes;
  final String? imageUrl;
  final bool isActive;
  final bool isFeatured;
  final int sortOrder;

  const Service({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    this.category,
    required this.durationMinutes,
    required this.price,
    required this.currency,
    required this.depositRequired,
    this.depositAmount,
    required this.depositType,
    this.depositPercentage,
    required this.bufferBeforeMinutes,
    required this.bufferAfterMinutes,
    this.imageUrl,
    required this.isActive,
    required this.isFeatured,
    required this.sortOrder,
  });

  /// Effective deposit amount for a booking of this service — mirrors
  /// the web's api/book/route.ts computation (PERCENTAGE derives from
  /// price, FIXED uses deposit_amount directly).
  double? get effectiveDepositAmount {
    if (!depositRequired) return null;
    if (depositType == 'PERCENTAGE' && depositPercentage != null) {
      return (price * depositPercentage! / 100 * 100).round() / 100;
    }
    return depositAmount;
  }

  factory Service.fromJson(Map<String, dynamic> json) => Service(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    category: json['category'] as String?,
    durationMinutes: json['duration_minutes'] as int? ?? 60,
    price: (json['price'] as num?)?.toDouble() ?? 0,
    currency: json['currency'] as String? ?? 'BBD',
    depositRequired: json['deposit_required'] as bool? ?? false,
    depositAmount: (json['deposit_amount'] as num?)?.toDouble(),
    depositType: json['deposit_type'] as String? ?? 'FIXED',
    depositPercentage: (json['deposit_percentage'] as num?)?.toDouble(),
    bufferBeforeMinutes: json['buffer_before_minutes'] as int? ?? 0,
    bufferAfterMinutes: json['buffer_after_minutes'] as int? ?? 0,
    imageUrl: json['image_url'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    isFeatured: json['is_featured'] as bool? ?? false,
    sortOrder: json['sort_order'] as int? ?? 0,
  );

  Map<String, dynamic> toInsertJson(String businessId) => {
    'business_id': businessId,
    'name': name,
    'description': description,
    'category': category,
    'duration_minutes': durationMinutes,
    'price': price,
    'currency': currency,
    'deposit_required': depositRequired,
    'deposit_amount': depositAmount,
    'deposit_type': depositType,
    'deposit_percentage': depositPercentage,
    'buffer_before_minutes': bufferBeforeMinutes,
    'buffer_after_minutes': bufferAfterMinutes,
    'is_featured': isFeatured,
  };
}
