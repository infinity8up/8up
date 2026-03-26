import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/class_models.dart';

class SessionRepository {
  SessionRepository(this._client);

  final SupabaseClient _client;
  static final DateFormat _date = DateFormat('yyyy-MM-dd');

  Future<List<ClassSessionItem>> fetchSessions({
    required String studioId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _client
        .from('v_class_session_feed')
        .select()
        .eq('studio_id', studioId)
        .gte('session_date', _date.format(startDate))
        .lte('session_date', _date.format(endDate))
        .order('start_at');

    return response
        .map<ClassSessionItem>((row) => ClassSessionItem.fromMap(row))
        .toList(growable: false);
  }

  Future<String> reserveSession({
    required String sessionId,
    required String userPassId,
  }) async {
    final response = await _client.rpc(
      'reserve_class_session',
      params: {'p_session_id': sessionId, 'p_user_pass_id': userPassId},
    );
    if (response is Map<String, dynamic>) {
      return response['status'] as String? ?? 'reserved';
    }
    return 'reserved';
  }

  Future<void> cancelReservation(String reservationId) async {
    await _client.rpc(
      'cancel_class_reservation',
      params: {'p_reservation_id': reservationId},
    );
  }

  Future<void> requestCancel({
    required String reservationId,
    required String reason,
  }) async {
    await _client.rpc(
      'request_class_reservation_cancel',
      params: {'p_reservation_id': reservationId, 'p_reason': reason},
    );
  }
}
