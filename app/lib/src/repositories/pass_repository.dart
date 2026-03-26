import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/reservation_bucket_rules.dart';
import '../models/pass_models.dart';

class PassRepository {
  PassRepository(this._client);

  final SupabaseClient _client;

  Future<bool> hasBlockingPassForAccountDeletion() async {
    final response = await _client
        .from('v_user_pass_summaries')
        .select('valid_until, remaining_count')
        .limit(100);

    final now = DateTime.now();
    for (final row in response) {
      final validUntilRaw = row['valid_until'] as String?;
      final validUntil = validUntilRaw == null
          ? null
          : DateTime.tryParse(validUntilRaw);
      final remainingCount = (row['remaining_count'] as num?)?.toInt() ?? 0;
      final isNotExpired = validUntil != null && !validUntil.isBefore(now);
      if (isNotExpired || remainingCount > 0) {
        return true;
      }
    }

    return false;
  }

  Future<List<UserPassSummary>> fetchPasses(String studioId) async {
    final response = await _client
        .from('v_user_pass_summaries')
        .select()
        .eq('studio_id', studioId)
        .order('valid_until');

    final passes = response
        .map<UserPassSummary>((row) => UserPassSummary.fromMap(row))
        .toList(growable: false);

    if (passes.isEmpty) {
      return passes;
    }

    final reservationRows = await _client
        .from('v_user_reservation_details')
        .select('user_pass_id, status, start_at')
        .eq('studio_id', studioId)
        .not('user_pass_id', 'is', null);
    final visibleTemplateNamesById = await _fetchVisibleTemplateNamesById(
      passes.expand((pass) => pass.allowedTemplateIds),
    );

    final now = DateTime.now();
    final plannedCounts = <String, int>{};
    final completedCounts = <String, int>{};

    for (final row in reservationRows) {
      final userPassId = row['user_pass_id'] as String?;
      final startAtRaw = row['start_at'] as String?;
      if (userPassId == null || startAtRaw == null) {
        continue;
      }

      final status = row['status'] as String?;
      final startAt = DateTime.tryParse(startAtRaw);
      if (startAt == null) {
        continue;
      }

      if (isReservationUpcomingStatus(status, startAt, now)) {
        plannedCounts[userPassId] = (plannedCounts[userPassId] ?? 0) + 1;
        continue;
      }

      if (isReservationCompletedStatus(status, startAt, now)) {
        completedCounts[userPassId] = (completedCounts[userPassId] ?? 0) + 1;
      }
    }

    return passes
        .map((pass) {
          final plannedCount = plannedCounts[pass.id] ?? 0;
          final completedCount = completedCounts[pass.id] ?? 0;
          final remainingCount =
              (pass.totalCount - plannedCount - completedCount).clamp(
                0,
                pass.totalCount,
              );
          final visibleTemplateNames = pass.allowedTemplateIds
              .map((id) => visibleTemplateNamesById[id])
              .whereType<String>()
              .toList(growable: false);
          return pass.copyWith(
            plannedCount: plannedCount,
            completedCount: completedCount,
            remainingCount: remainingCount,
            allowedTemplateNames: visibleTemplateNames,
          );
        })
        .toList(growable: false);
  }

  Future<List<PassUsageEntry>> fetchUsageEntries(String userPassId) async {
    final response = await _client
        .from('v_user_pass_usage_entries')
        .select()
        .eq('user_pass_id', userPassId)
        .order('session_start_at', ascending: false);

    return response
        .map<PassUsageEntry>((row) => PassUsageEntry.fromMap(row))
        .toList(growable: false);
  }

  Future<Map<String, String>> _fetchVisibleTemplateNamesById(
    Iterable<String> templateIds,
  ) async {
    final ids = templateIds.toSet().toList(growable: false);
    if (ids.isEmpty) {
      return const {};
    }

    final response = await _client
        .from('class_templates')
        .select('id, name, category')
        .inFilter('id', ids)
        .neq('category', '일회성');

    final visibleTemplateNamesById = <String, String>{};
    for (final row in response) {
      final id = row['id'] as String?;
      final name = row['name'] as String?;
      if (id == null || name == null) {
        continue;
      }
      visibleTemplateNamesById[id] = name;
    }
    return visibleTemplateNamesById;
  }
}
