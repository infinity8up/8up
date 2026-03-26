import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/class_models.dart';

class ReservationRepository {
  ReservationRepository(this._client);

  final SupabaseClient _client;

  Future<bool> hasAnyReservationHistory() async {
    final response = await _client
        .from('v_user_reservation_details')
        .select('id')
        .limit(1);

    return response.isNotEmpty;
  }

  Future<List<ReservationItem>> fetchReservations(String studioId) async {
    final response = await _client
        .from('v_user_reservation_details')
        .select()
        .eq('studio_id', studioId)
        .order('start_at');

    return response
        .map<ReservationItem>((row) => ReservationItem.fromMap(row))
        .toList(growable: false);
  }
}
