class UserProfile {
  const UserProfile({
    required this.id,
    required this.memberCode,
    required this.imageUrl,
    required this.phone,
    required this.email,
    required this.name,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String memberCode;
  final String? imageUrl;
  final String? phone;
  final String? email;
  final String? name;
  final String status;
  final DateTime createdAt;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      memberCode: map['member_code'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      name: map['name'] as String?,
      status: map['status'] as String? ?? 'inactive',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
