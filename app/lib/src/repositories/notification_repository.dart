import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_item.dart';

class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  Stream<List<AppNotificationItem>> watchNotifications({
    required String studioId,
  }) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('studio_id', studioId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map<AppNotificationItem>(
                (row) => AppNotificationItem.fromMap(row),
              )
              .toList(growable: false),
        );
  }

  Future<void> markAllRead({required String studioId}) async {
    await _client
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('studio_id', studioId)
        .eq('is_read', false);
  }

  Future<void> markRead({required String notificationId}) async {
    await _client
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', notificationId)
        .eq('is_read', false);
  }
}
