import 'package:eightup_user_app/src/models/content_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NoticeItem hides unpublished content even in visible window', () {
    final now = DateTime(2026, 3, 11, 10);
    const notice = NoticeItem(
      id: 'notice-id',
      title: '숨김 공지',
      body: '표시되면 안 됩니다.',
      isImportant: false,
      isPublished: false,
      visibleFrom: null,
      visibleUntil: null,
    );

    expect(notice.isVisibleAt(now), isFalse);
  });

  test('EventItem shows published content inside visible window', () {
    final now = DateTime(2026, 3, 11, 10);
    final event = EventItem(
      id: 'event-id',
      title: '공개 이벤트',
      body: '표시되어야 합니다.',
      isImportant: false,
      isPublished: true,
      visibleFrom: now.subtract(const Duration(days: 1)),
      visibleUntil: now.add(const Duration(days: 1)),
    );

    expect(event.isVisibleAt(now), isTrue);
  });
}
