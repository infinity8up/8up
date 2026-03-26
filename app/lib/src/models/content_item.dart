class NoticeItem {
  const NoticeItem({
    required this.id,
    required this.title,
    required this.body,
    required this.isImportant,
    required this.isPublished,
    required this.visibleFrom,
    required this.visibleUntil,
  });

  final String id;
  final String title;
  final String body;
  final bool isImportant;
  final bool isPublished;
  final DateTime? visibleFrom;
  final DateTime? visibleUntil;

  bool isVisibleAt(DateTime now) {
    if (!isPublished) {
      return false;
    }
    final afterStart = visibleFrom == null || !now.isBefore(visibleFrom!);
    final beforeEnd = visibleUntil == null || !now.isAfter(visibleUntil!);
    return afterStart && beforeEnd;
  }

  factory NoticeItem.fromMap(Map<String, dynamic> map) {
    return NoticeItem(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      isImportant: map['is_important'] as bool? ?? false,
      isPublished: map['is_published'] as bool? ?? true,
      visibleFrom: _parseDateTime(map['visible_from']),
      visibleUntil: _parseDateTime(map['visible_until']),
    );
  }
}

class EventItem {
  const EventItem({
    required this.id,
    required this.title,
    required this.body,
    required this.isImportant,
    required this.isPublished,
    required this.visibleFrom,
    required this.visibleUntil,
  });

  final String id;
  final String title;
  final String body;
  final bool isImportant;
  final bool isPublished;
  final DateTime? visibleFrom;
  final DateTime? visibleUntil;

  bool isVisibleAt(DateTime now) {
    if (!isPublished) {
      return false;
    }
    final afterStart = visibleFrom == null || !now.isBefore(visibleFrom!);
    final beforeEnd = visibleUntil == null || !now.isAfter(visibleUntil!);
    return afterStart && beforeEnd;
  }

  factory EventItem.fromMap(Map<String, dynamic> map) {
    return EventItem(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      isImportant: map['is_important'] as bool? ?? false,
      isPublished: map['is_published'] as bool? ?? true,
      visibleFrom: _parseDateTime(map['visible_from']),
      visibleUntil: _parseDateTime(map['visible_until']),
    );
  }
}

class StudioFeed {
  const StudioFeed({required this.notices, required this.events});

  final List<NoticeItem> notices;
  final List<EventItem> events;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.parse(value as String);
}
