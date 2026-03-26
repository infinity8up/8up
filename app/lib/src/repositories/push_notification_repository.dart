import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationRepository {
  PushNotificationRepository(this._client);

  final SupabaseClient _client;

  Future<void> upsertDevice({
    required String installationId,
    required String token,
    required String platform,
  }) async {
    await _client.rpc(
      'upsert_push_notification_device',
      params: {
        'p_installation_id': installationId,
        'p_token': token,
        'p_platform': platform,
      },
    );
  }

  Future<void> disableDevice({required String installationId}) async {
    await _client.rpc(
      'disable_push_notification_device',
      params: {'p_installation_id': installationId},
    );
  }
}
