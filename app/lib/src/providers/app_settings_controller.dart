import 'package:flutter/foundation.dart';

import '../repositories/app_settings_repository.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController(this._repository);

  final AppSettingsRepository _repository;

  bool _isLoading = false;
  bool _isInitialized = false;
  bool _inAppNotificationsEnabled = true;
  bool _pushNotificationsEnabled = false;

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get inAppNotificationsEnabled => _inAppNotificationsEnabled;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;

  Future<void> load() async {
    if (_isInitialized || _isLoading) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _inAppNotificationsEnabled = true;
      _pushNotificationsEnabled = await _repository
          .getPushNotificationsEnabled();
      _isInitialized = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setInAppNotificationsEnabled(bool value) async {
    _inAppNotificationsEnabled = true;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setPushNotificationsEnabled(bool value) async {
    if (_pushNotificationsEnabled == value) {
      return;
    }

    final previousValue = _pushNotificationsEnabled;
    _pushNotificationsEnabled = value;
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.setPushNotificationsEnabled(value);
    } catch (_) {
      _pushNotificationsEnabled = previousValue;
      rethrow;
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }
}
