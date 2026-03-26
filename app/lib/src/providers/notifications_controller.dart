import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/error_text.dart';
import '../models/notification_item.dart';
import '../repositories/notification_repository.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController(this._repository);

  final NotificationRepository _repository;

  StreamSubscription<List<AppNotificationItem>>? _subscription;
  List<AppNotificationItem> _notifications = const [];
  String? _userId;
  String? _studioId;
  bool _enabled = true;
  bool _loading = false;
  String? _error;

  List<AppNotificationItem> get notifications => _notifications;
  List<AppNotificationItem> get unreadNotifications =>
      _notifications.where((item) => !item.isRead).toList(growable: false);
  bool get isLoading => _loading;
  String? get error => _error;
  int get unreadCount => unreadNotifications.length;
  bool get hasUnread => unreadCount > 0;
  bool get hasImportantUnread =>
      _notifications.any((item) => !item.isRead && item.isImportant);

  void bind({
    required String? userId,
    required String? studioId,
    required bool enabled,
  }) {
    if (_userId == userId && _studioId == studioId && _enabled == enabled) {
      return;
    }

    _userId = userId;
    _studioId = studioId;
    _enabled = enabled;
    Future<void>.microtask(refresh);
  }

  Future<void> refresh() async {
    await _subscription?.cancel();
    _subscription = null;

    if (!_enabled || _userId == null || _studioId == null) {
      _notifications = const [];
      _loading = false;
      _error = null;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    _subscription = _repository
        .watchNotifications(studioId: _studioId!)
        .listen(
          (items) {
            _notifications = items;
            _loading = false;
            _error = null;
            notifyListeners();
          },
          onError: (error) {
            _loading = false;
            _error = ErrorText.format(error);
            notifyListeners();
          },
        );
  }

  Future<void> markAllRead() async {
    final studioId = _studioId;
    if (!_enabled || studioId == null || !hasUnread) {
      return;
    }

    final previous = _notifications;
    final readAt = DateTime.now().toUtc();
    _notifications = [
      for (final item in _notifications)
        item.isRead ? item : item.copyWith(isRead: true, readAt: readAt),
    ];
    notifyListeners();

    try {
      await _repository.markAllRead(studioId: studioId);
    } catch (error) {
      _notifications = previous;
      _error = ErrorText.format(error);
      notifyListeners();
    }
  }

  Future<void> markRead(String notificationId) async {
    if (!_enabled || notificationId.isEmpty) {
      return;
    }

    final index = _notifications.indexWhere((item) => item.id == notificationId);
    if (index < 0 || _notifications[index].isRead) {
      return;
    }

    final previous = _notifications;
    final readAt = DateTime.now().toUtc();
    _notifications = [
      for (final item in _notifications)
        item.id == notificationId
            ? item.copyWith(isRead: true, readAt: readAt)
            : item,
    ];
    notifyListeners();

    try {
      await _repository.markRead(notificationId: notificationId);
    } catch (error) {
      _notifications = previous;
      _error = ErrorText.format(error);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
