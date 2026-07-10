class Customer {
  final String id;
  final String businessId;
  final String firstName;
  final String? lastName;
  final String phone;
  final String? whatsappNumber;
  final String? email;
  final String? notes;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({
    required this.id,
    required this.businessId,
    required this.firstName,
    this.lastName,
    required this.phone,
    this.whatsappNumber,
    this.email,
    this.notes,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName =>
      [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    firstName: json['first_name'] as String,
    lastName: json['last_name'] as String?,
    phone: json['phone'] as String,
    whatsappNumber: json['whatsapp_number'] as String?,
    email: json['email'] as String?,
    notes: json['notes'] as String?,
    tags:
        (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        const [],
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toInsertJson(String businessId) => {
    'business_id': businessId,
    'first_name': firstName,
    'last_name': lastName,
    'phone': phone,
    'whatsapp_number': whatsappNumber,
    'email': email,
  };

  Map<String, dynamic> toUpdateJson() => {
    'first_name': firstName,
    'last_name': lastName,
    'phone': phone,
    'whatsapp_number': whatsappNumber,
    'email': email,
    'notes': notes,
    'tags': tags,
  };
}
