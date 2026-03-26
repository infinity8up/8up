class Studio {
  const Studio({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.contactPhone,
    required this.address,
    required this.status,
  });

  final String id;
  final String name;
  final String? imageUrl;
  final String? contactPhone;
  final String? address;
  final String status;

  factory Studio.fromMap(Map<String, dynamic> map) {
    return Studio(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      contactPhone: map['contact_phone'] as String?,
      address: map['address'] as String?,
      status: map['status'] as String? ?? 'inactive',
    );
  }
}

class StudioMembership {
  const StudioMembership({
    required this.id,
    required this.studioId,
    required this.status,
    required this.joinedAt,
    required this.studio,
  });

  final String id;
  final String studioId;
  final String status;
  final DateTime joinedAt;
  final Studio studio;
  bool get isActive => status == 'active';

  factory StudioMembership.fromMap(Map<String, dynamic> map) {
    final studioId = map['studio_id'] as String;
    final studioMap = map['studio'] as Map<String, dynamic>?;
    return StudioMembership(
      id: map['id'] as String,
      studioId: studioId,
      status: map['membership_status'] as String? ?? 'inactive',
      joinedAt: DateTime.parse(map['joined_at'] as String),
      studio: Studio.fromMap(
        studioMap ??
            {
              'id': studioId,
              'name': '스튜디오',
              'image_url': null,
              'contact_phone': null,
              'address': null,
              'status': 'inactive',
            },
      ),
    );
  }
}
