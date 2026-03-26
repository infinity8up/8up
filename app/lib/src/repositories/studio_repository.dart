import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/studio.dart';
import '../models/content_item.dart';

class StudioRepository {
  StudioRepository(this._client);

  final SupabaseClient _client;

  Future<List<StudioMembership>> fetchMemberships() async {
    final userId = _client.auth.currentUser!.id;
    final response = await _client
        .from('studio_user_memberships')
        .select(
          'id, studio_id, membership_status, joined_at, '
          'studio:studios(id, name, image_url, contact_phone, address, status)',
        )
        .eq('user_id', userId)
        .order('membership_status')
        .order('joined_at');

    return response
        .map<StudioMembership>((row) => StudioMembership.fromMap(row))
        .toList(growable: false);
  }

  Future<void> updateOwnMembershipStatus({
    required String membershipId,
    required String status,
  }) async {
    await _client.rpc(
      'set_own_membership_status',
      params: {'p_membership_id': membershipId, 'p_membership_status': status},
    );
  }

  Future<StudioFeed> fetchStudioFeed(String studioId) async {
    final noticesResponse = await _client
        .from('notices')
        .select()
        .eq('studio_id', studioId)
        .eq('is_published', true)
        .order('is_important', ascending: false)
        .order('created_at', ascending: false);

    final eventsResponse = await _client
        .from('events')
        .select()
        .eq('studio_id', studioId)
        .eq('is_published', true)
        .order('created_at', ascending: false);

    final now = DateTime.now();

    final notices = noticesResponse
        .map<NoticeItem>((row) => NoticeItem.fromMap(row))
        .where((item) => item.isVisibleAt(now))
        .toList(growable: false);

    final events = eventsResponse
        .map<EventItem>((row) => EventItem.fromMap(row))
        .where((item) => item.isVisibleAt(now))
        .toList(growable: false);

    return StudioFeed(notices: notices, events: events);
  }
}
