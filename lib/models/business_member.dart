import 'business_role.dart';

class BusinessMember {
  final String id;
  final String businessId;
  final String userId;
  final BusinessRole role;
  final String status; // 'ACTIVE' | 'INVITED'
  final DateTime createdAt;

  const BusinessMember({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  factory BusinessMember.fromJson(Map<String, dynamic> json) => BusinessMember(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    userId: json['user_id'] as String,
    role: BusinessRole.fromString(json['role'] as String),
    // Older rows (pre mobile-app migration) won't have `status` selected
    // if the client is pointed at a project that hasn't applied it yet;
    // default to ACTIVE rather than failing to parse.
    status: json['status'] as String? ?? 'ACTIVE',
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
