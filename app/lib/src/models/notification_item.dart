class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.studioId,
    required this.userId,
    required this.kind,
    required this.title,
    required this.body,
    required this.isImportant,
    required this.isRead,
    required this.relatedEntityType,
    required this.relatedEntityId,
    required this.readAt,
    required this.createdAt,
  });

  final String id;
  final String studioId;
  final String userId;
  final String kind;
  final String title;
  final String body;
  final bool isImportant;
  final bool isRead;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotificationItem copyWith({
    String? id,
    String? studioId,
    String? userId,
    String? kind,
    String? title,
    String? body,
    bool? isImportant,
    bool? isRead,
    String? relatedEntityType,
    String? relatedEntityId,
    DateTime? readAt,
    bool clearReadAt = false,
    DateTime? createdAt,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      studioId: studioId ?? this.studioId,
      userId: userId ?? this.userId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      body: body ?? this.body,
      isImportant: isImportant ?? this.isImportant,
      isRead: isRead ?? this.isRead,
      relatedEntityType: relatedEntityType ?? this.relatedEntityType,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AppNotificationItem.fromMap(Map<String, dynamic> map) {
    return AppNotificationItem(
      id: map['id'] as String,
      studioId: map['studio_id'] as String,
      userId: map['user_id'] as String,
      kind: map['kind'] as String? ?? 'general',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      isImportant: map['is_important'] as bool? ?? false,
      isRead: map['is_read'] as bool? ?? false,
      relatedEntityType: map['related_entity_type'] as String?,
      relatedEntityId: map['related_entity_id'] as String?,
      readAt: _parseDate(map['read_at']),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.parse(value as String);
}
