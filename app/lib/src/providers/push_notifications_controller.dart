import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/error_text.dart';
import '../core/push_notifications.dart';
import '../repositories/app_settings_repository.dart';
import '../repositories/push_notification_repository.dart';

class PushNotificationsController extends ChangeNotifier {
  PushNotificationsController(this._repository, this._settingsRepository);

  final PushNotificationRepository _repository;
  final AppSettingsRepository _settingsRepository;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  String? _userId;
  bool _enabled = false;
  bool _initialized = false;
  bool _isBusy = false;
  bool _isSyncing = false;
  String? _error;
  AuthorizationStatus _authorizationStatus = AuthorizationStatus.notDetermined;

  bool get isSupported => !kIsWeb;
  bool get isBusy => _isBusy;
  String? get error => _error;
  bool get isEnabled => _enabled;
  bool get isAuthorized => _isAuthorized(_authorizationStatus);
  AuthorizationStatus get authorizationStatus => _authorizationStatus;

  void bind({required String? userId, required bool enabled}) {
    if (_userId == userId && _enabled == enabled) {
      return;
    }

    _userId = userId;
    _enabled = enabled;
    Future<void>.microtask(_syncState);
  }

  Future<bool> prepareForEnable() async {
    if (!isSupported) {
      _error = '푸쉬 알림은 모바일 앱에서만 지원합니다.';
      notifyListeners();
      return false;
    }

    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final initialized = await _ensureInitialized();
      if (!initialized) {
        return false;
      }

      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _authorizationStatus = settings.authorizationStatus;

      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImplementation?.requestNotificationsPermission();

      if (!_isAuthorized(_authorizationStatus)) {
        _error = '시스템 푸쉬 알림 권한이 허용되지 않았습니다.';
        notifyListeners();
        return false;
      }

      if (_userId != null) {
        await _registerCurrentDevice();
      }

      _error = null;
      notifyListeners();
      return true;
    } catch (error) {
      _error = ErrorText.format(error);
      notifyListeners();
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> disableForCurrentInstallation() async {
    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      await _disableRemoteDelivery();
    } catch (error) {
      _error = ErrorText.format(error);
      notifyListeners();
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _syncState() async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;
    try {
      if (!_enabled) {
        await _disableRemoteDelivery();
        return;
      }

      final initialized = await _ensureInitialized();
      if (!initialized) {
        return;
      }

      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);

      final settings = await messaging.getNotificationSettings();
      _authorizationStatus = settings.authorizationStatus;

      if (!_isAuthorized(_authorizationStatus)) {
        _error = '시스템 푸쉬 권한이 꺼져 있어 앱 푸쉬를 보낼 수 없습니다.';
        notifyListeners();
        return;
      }

      if (_userId == null) {
        await _disableRemoteDelivery();
        return;
      }

      await _registerCurrentDevice();
    } catch (error) {
      _error = ErrorText.format(error);
      notifyListeners();
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) {
      return true;
    }

    try {
      await Firebase.initializeApp();
    } catch (error) {
      if (!_looksLikeDuplicateFirebaseInit(error)) {
        _error =
            'Firebase 푸쉬 설정을 초기화하지 못했습니다. Firebase 설정 파일과 네이티브 설정을 확인해 주세요.';
        notifyListeners();
        return false;
      }
    }

    await ensureAndroidLocalNotificationsInitialized(_localNotifications);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: (error) {
        _error = ErrorText.format(error);
        notifyListeners();
      },
    );

    _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh
        .listen(
          (token) async {
            if (!_enabled || _userId == null || token.isEmpty) {
              return;
            }
            try {
              await _registerDeviceToken(token);
            } catch (error) {
              _error = ErrorText.format(error);
              notifyListeners();
            }
          },
          onError: (error) {
            _error = ErrorText.format(error);
            notifyListeners();
          },
        );

    _initialized = true;
    return true;
  }

  Future<void> _registerCurrentDevice() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _waitForApnsToken();
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('푸쉬 토큰을 가져오지 못했습니다.');
    }

    await _registerDeviceToken(token);
  }

  Future<void> _registerDeviceToken(String token) async {
    final installationId = await _installationId();

    await _repository.upsertDevice(
      installationId: installationId,
      token: token,
      platform: _platformName(),
    );

    _error = null;
    notifyListeners();
  }

  Future<void> _disableRemoteDelivery() async {
    final installationId = await _settingsRepository.getPushInstallationId();
    if (installationId == null || installationId.isEmpty) {
      return;
    }

    try {
      await _repository.disableDevice(installationId: installationId);
      if (_initialized) {
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
      }
      _error = null;
      notifyListeners();
    } catch (error) {
      _error = ErrorText.format(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!_enabled || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await showAndroidPushNotification(_localNotifications, message);
  }

  Future<void> _waitForApnsToken() async {
    for (var index = 0; index < 10; index++) {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<String> _installationId() async {
    final existing = await _settingsRepository.getPushInstallationId();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    final installationId = base64UrlEncode(bytes).replaceAll('=', '');
    await _settingsRepository.setPushInstallationId(installationId);
    return installationId;
  }

  bool _isAuthorized(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  bool _looksLikeDuplicateFirebaseInit(Object error) {
    return error.toString().contains('duplicate-app');
  }

  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'unsupported';
    }
  }

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    super.dispose();
  }
}
