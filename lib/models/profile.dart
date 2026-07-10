class Profile {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String role; // platform-wide role: 'admin' | 'entrepreneur' | 'user'

  const Profile({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    required this.role,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    email: json['email'] as String,
    fullName: json['full_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    role: json['role'] as String? ?? 'user',
  );
}
