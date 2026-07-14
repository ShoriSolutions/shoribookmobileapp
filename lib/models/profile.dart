import 'address.dart';

class Profile {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final String role; // platform-wide role: 'admin' | 'entrepreneur' | 'user'
  final Address address; // may be empty (Address.isEmpty)

  const Profile({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    required this.role,
    this.address = const Address(),
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    email: json['email'] as String,
    fullName: json['full_name'] as String? ?? '',
    phone: json['phone'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    role: json['role'] as String? ?? 'user',
    address: Address.fromJson(json),
  );
}
