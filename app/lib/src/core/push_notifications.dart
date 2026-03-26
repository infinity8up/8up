import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String kPushNotificationChannelId = 'eightup_notifications';
const String kPushNotificationChannelName = '8UP 알림';
const String kPushNotificationChannelDescription = '수업 및 공지 알림';
const String kPushNotificationSmallIcon = 'ic_notification';
const String kPushNotificationLargeIcon = 'ic_notification_large';
const Color kPushNotificationAccentColor = Color(0xFF6034D6);

final FlutterLocalNotificationsPlugin _backgroundLocalNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase native config가 아직 없는 개발 환경에서는 조용히 무시한다.
  }

  if (defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  await ensureAndroidLocalNotificationsInitialized(_backgroundLocalNotifications);
  await showAndroidPushNotification(
    _backgroundLocalNotifications,
    message,
  );
}

Future<void> ensureAndroidLocalNotificationsInitialized(
  FlutterLocalNotificationsPlugin plugin,
) async {
  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings(kPushNotificationSmallIcon),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );

  await plugin.initialize(initializationSettings);

  const androidChannel = AndroidNotificationChannel(
    kPushNotificationChannelId,
    kPushNotificationChannelName,
    description: kPushNotificationChannelDescription,
    importance: Importance.high,
  );

  final androidImplementation = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidImplementation?.createNotificationChannel(androidChannel);
}

Future<void> showAndroidPushNotification(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message,
) async {
  final notification = message.notification;
  final data = message.data;
  final title = notification?.title ?? data['title']?.toString() ?? '8UP 알림';
  final body =
      notification?.body ?? data['body']?.toString() ?? '새로운 알림이 도착했습니다.';

  await plugin.show(
    message.messageId.hashCode ^ message.sentTime.hashCode,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        kPushNotificationChannelId,
        kPushNotificationChannelName,
        channelDescription: kPushNotificationChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        color: kPushNotificationAccentColor,
        largeIcon: DrawableResourceAndroidBitmap(kPushNotificationLargeIcon),
      ),
    ),
  );
}
