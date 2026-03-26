import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsRepository {
  static const _inAppNotificationsEnabledKey =
      'settings.in_app_notifications_enabled';
  static const _pushNotificationsEnabledKey =
      'settings.push_notifications_enabled';
  static const _pushInstallationIdKey = 'settings.push_installation_id';
  static const _selectedStudioKeyPrefix = 'settings.selected_studio';

  Future<bool> getInAppNotificationsEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_inAppNotificationsEnabledKey) ?? true;
  }

  Future<void> setInAppNotificationsEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_inAppNotificationsEnabledKey, value);
  }

  Future<bool> getPushNotificationsEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_pushNotificationsEnabledKey) ?? false;
  }

  Future<void> setPushNotificationsEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_pushNotificationsEnabledKey, value);
  }

  Future<String?> getPushInstallationId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_pushInstallationIdKey);
  }

  Future<void> setPushInstallationId(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pushInstallationIdKey, value);
  }

  Future<String?> getSelectedStudioId(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_selectedStudioKey(userId));
  }

  Future<void> setSelectedStudioId(String userId, String studioId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_selectedStudioKey(userId), studioId);
  }

  Future<void> clearSelectedStudioId(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_selectedStudioKey(userId));
  }

  String _selectedStudioKey(String userId) {
    return '$_selectedStudioKeyPrefix.$userId';
  }
}
