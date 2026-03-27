import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/class_models.dart';
import '../models/admin_models.dart';
import '../../repositories/image_storage_repository.dart';

class AdminRepository {
  AdminRepository(this._client, this._imageStorage);

  final SupabaseClient _client;
  final ImageStorageRepository _imageStorage;
  static final DateFormat _date = DateFormat('yyyy-MM-dd');

  Future<AdminProfile> fetchCurrentAdminProfile() async {
    final profile = await fetchCurrentAdminProfileOrNull();
    if (profile == null) {
      throw StateError('관리자 프로필을 찾을 수 없습니다.');
    }
    return profile;
  }

  Future<AdminProfile?> fetchCurrentAdminProfileOrNull() async {
    final userId = _client.auth.currentUser!.id;
    final response = await _client
        .from('admin_users')
        .select(
          'id, studio_id, login_id, name, email, phone, role, '
          'must_change_password, status, '
          'studio:studios('
          'id, name, image_url, contact_phone, address, '
          'cancel_policy_mode, cancel_policy_hours_before, '
          'cancel_policy_days_before, cancel_policy_cutoff_time, '
          'cancel_inquiry_enabled, status'
          ')',
        )
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return AdminProfile.fromMap(response);
  }

  Future<PlatformAdminProfile?> fetchCurrentPlatformAdminProfileOrNull() async {
    final userId = _client.auth.currentUser!.id;
    final response = await _client
        .from('platform_admin_users')
        .select('id, login_id, name, email, phone, status')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return PlatformAdminProfile.fromMap(response);
  }

  Future<AdminDashboardMetrics> fetchDashboardMetrics() async {
    final response = await _client
        .from('v_admin_dashboard_metrics')
        .select()
        .single();

    return AdminDashboardMetrics.fromMap(response);
  }

  Future<List<AdminMonthlyClassMetric>> fetchMonthlyClassMetrics() async {
    final response = await _client
        .from('v_admin_monthly_class_metrics')
        .select()
        .order('class_name');

    return response
        .map<AdminMonthlyClassMetric>(
          (row) => AdminMonthlyClassMetric.fromMap(row),
        )
        .toList(growable: false);
  }

  Future<List<AdminMonthlyFinancialMetric>>
  fetchMonthlyFinancialMetrics() async {
    final response = await _client
        .from('v_admin_monthly_financial_metrics')
        .select()
        .order('month_start');

    return response
        .map<AdminMonthlyFinancialMetric>(
          (row) => AdminMonthlyFinancialMetric.fromMap(row),
        )
        .toList(growable: false);
  }

  Future<List<AdminMonthlyReservationSummary>>
  fetchMonthlyReservationSummaries({
    required String studioId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _client
        .from('v_admin_session_reservation_summary')
        .select()
        .eq('studio_id', studioId)
        .gte('session_date', _date.format(startDate))
        .lte('session_date', _date.format(endDate))
        .order('start_at');

    return response
        .map<AdminMonthlyReservationSummary>(
          (row) => AdminMonthlyReservationSummary.fromMap(row),
        )
        .toList(growable: false);
  }

  Future<List<AdminClassTemplate>> fetchTemplates(String studioId) async {
    final response = await _client
        .from('class_templates')
        .select()
        .eq('studio_id', studioId)
        .order('start_time')
        .order('name');

    return response
        .map<AdminClassTemplate>((row) => AdminClassTemplate.fromMap(row))
        .toList(growable: false);
  }

  Future<List<AdminInstructor>> fetchInstructors(String studioId) async {
    final response = await _client
        .from('instructors')
        .select()
        .eq('studio_id', studioId)
        .order('name');

    return response
        .map<AdminInstructor>((row) => AdminInstructor.fromMap(row))
        .toList(growable: false);
  }

  Future<void> saveTemplate({
    String? id,
    required String studioId,
    required String name,
    required String category,
    required String? defaultInstructorId,
    required String description,
    required List<String> dayOfWeekMask,
    required String startTime,
    required String endTime,
    required int capacity,
    required String status,
  }) async {
    final payload = {
      'studio_id': studioId,
      'name': name,
      'category': category,
      'default_instructor_id': defaultInstructorId,
      'description': description,
      'day_of_week_mask': dayOfWeekMask,
      'start_time': _normalizeTime(startTime),
      'end_time': _normalizeTime(endTime),
      'capacity': capacity,
      'status': status,
    };

    if (id == null) {
      await _client.from('class_templates').insert(payload);
      return;
    }

    await _client.from('class_templates').update(payload).eq('id', id);
  }

  Future<void> saveInstructor({
    String? id,
    required String studioId,
    required String name,
    String? phone,
    AdminInstructor? previousInstructor,
    PickedImageFile? imageFile,
    bool removeImage = false,
  }) async {
    final trimmedName = name.trim();
    await _ensureInstructorNameAvailable(
      client: _client,
      studioId: studioId,
      name: trimmedName,
      excludeInstructorId: id,
    );

    final previousStoredPath = previousInstructor == null
        ? null
        : _imageStorage.tryExtractObjectPath(previousInstructor.imageUrl);
    final newStoredPath = _imageStorage.instructorObjectPath(
      studioId: studioId,
      instructorName: trimmedName,
    );
    String? resolvedImageUrl = previousInstructor?.imageUrl;
    var uploadedNewPath = false;
    String? pathToDeleteAfterSave;

    if (removeImage) {
      final removablePath =
          previousStoredPath ??
          (previousInstructor == null
              ? null
              : _imageStorage.instructorObjectPath(
                  studioId: previousInstructor.studioId,
                  instructorName: previousInstructor.name,
                ));
      pathToDeleteAfterSave = removablePath;
      resolvedImageUrl = null;
    } else if (imageFile != null) {
      resolvedImageUrl = await _imageStorage.uploadInstructorImage(
        studioId: studioId,
        instructorName: trimmedName,
        file: imageFile,
      );
      uploadedNewPath = true;
      if (previousStoredPath != null && previousStoredPath != newStoredPath) {
        pathToDeleteAfterSave = previousStoredPath;
      }
    } else if (previousInstructor != null &&
        previousStoredPath != null &&
        previousStoredPath != newStoredPath &&
        (previousInstructor.imageUrl?.isNotEmpty ?? false)) {
      final existingBytes = await _imageStorage.downloadObject(
        previousStoredPath,
      );
      resolvedImageUrl = await _imageStorage.uploadInstructorImage(
        studioId: studioId,
        instructorName: trimmedName,
        file: PickedImageFile(
          bytes: existingBytes,
          fileName: '$trimmedName.jpg',
        ),
      );
      uploadedNewPath = true;
      pathToDeleteAfterSave = previousStoredPath;
    }

    final payload = {
      'studio_id': studioId,
      'name': trimmedName,
      'phone': _nullIfBlank(phone),
      'image_url': _nullIfBlank(resolvedImageUrl),
    };

    try {
      if (id == null) {
        await _client.from('instructors').insert(payload);
      } else {
        await _client.from('instructors').update(payload).eq('id', id);
      }

      if (pathToDeleteAfterSave != null) {
        await _imageStorage.removeObject(pathToDeleteAfterSave);
      }
    } catch (_) {
      if (uploadedNewPath && newStoredPath != previousStoredPath) {
        await _imageStorage.removeObject(newStoredPath);
      }
      rethrow;
    }
  }

  Future<void> deleteInstructor({required AdminInstructor instructor}) async {
    await _client.from('instructors').delete().eq('id', instructor.id);
    final storedPath =
        _imageStorage.tryExtractObjectPath(instructor.imageUrl) ??
        _imageStorage.instructorObjectPath(
          studioId: instructor.studioId,
          instructorName: instructor.name,
        );
    await _imageStorage.removeObject(storedPath);
  }

  Future<void> deleteTemplate({required String templateId}) async {
    final sessions = await _client
        .from('class_sessions')
        .select('id')
        .eq('class_template_id', templateId)
        .limit(1);
    if (sessions.isNotEmpty) {
      throw StateError(
        '개설된 수업 회차가 있는 템플릿은 삭제할 수 없습니다. 회원 앱 노출과 조회를 위해 수업 회차가 템플릿에 연결된 상태여야 합니다.',
      );
    }

    await _client.from('class_templates').delete().eq('id', templateId);
  }

  Future<List<DateTime>> fetchTemplateSessionDatesInCurrentMonth({
    required String templateId,
  }) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final monthEnd = nextMonthStart.subtract(const Duration(days: 1));

    final response = await _client
        .from('class_sessions')
        .select('session_date')
        .eq('class_template_id', templateId)
        .neq('status', 'cancelled')
        .gte('session_date', _date.format(monthStart))
        .lte('session_date', _date.format(monthEnd))
        .order('session_date');

    final uniqueDates = <String>{};
    final dates = <DateTime>[];
    for (final row in response) {
      final raw = row['session_date'] as String?;
      if (raw == null || !uniqueDates.add(raw)) {
        continue;
      }
      dates.add(DateTime.parse(raw));
    }
    return dates;
  }

  Future<List<AdminPassProduct>> fetchPassProducts(String studioId) async {
    final response = await _client
        .from('v_admin_pass_product_details')
        .select()
        .eq('studio_id', studioId)
        .order('created_at', ascending: false);

    return response
        .map<AdminPassProduct>((row) => AdminPassProduct.fromMap(row))
        .toList(growable: false);
  }

  Future<Set<String>> fetchTemplatePassProductIds({
    required String classTemplateId,
  }) async {
    final response = await _client
        .from('pass_product_template_mappings')
        .select('pass_product_id')
        .eq('class_template_id', classTemplateId);

    return response
        .map<String?>((row) => row['pass_product_id'] as String?)
        .whereType<String>()
        .toSet();
  }

  Future<void> saveTemplatePassProductIds({
    required String studioId,
    required String classTemplateId,
    required List<String> passProductIds,
  }) async {
    final sanitizedPassProductIds = passProductIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (sanitizedPassProductIds.isEmpty) {
      throw StateError('수강권 상품을 한 개 이상 선택하세요.');
    }

    await _client
        .from('pass_product_template_mappings')
        .delete()
        .eq('class_template_id', classTemplateId);

    await _client
        .from('pass_product_template_mappings')
        .insert(
          sanitizedPassProductIds
              .map(
                (passProductId) => {
                  'studio_id': studioId,
                  'pass_product_id': passProductId,
                  'class_template_id': classTemplateId,
                },
              )
              .toList(growable: false),
        );
  }

  Future<List<AdminNotice>> fetchNotices(String studioId) async {
    final response = await _client
        .from('notices')
        .select()
        .eq('studio_id', studioId)
        .order('created_at', ascending: false);

    return response
        .map<AdminNotice>((row) => AdminNotice.fromMap(row))
        .toList(growable: false);
  }

  Future<void> saveNotice({
    String? id,
    required String studioId,
    required String title,
    required String body,
    required bool isImportant,
    required bool isPublished,
    required String status,
    required DateTime? visibleFrom,
    required DateTime? visibleUntil,
  }) async {
    final payload = {
      'studio_id': studioId,
      'title': title,
      'body': body,
      'is_important': isImportant,
      'is_published': isPublished,
      'status': status,
      'visible_from': visibleFrom?.toIso8601String(),
      'visible_until': visibleUntil?.toIso8601String(),
    };

    if (id == null) {
      await _client.from('notices').insert({
        ...payload,
        'created_by_admin_id': _client.auth.currentUser!.id,
      });
      return;
    }

    await _client.from('notices').update(payload).eq('id', id);
  }

  Future<void> deleteNotice({required String id}) async {
    await _client.from('notices').delete().eq('id', id);
  }

  Future<List<AdminEvent>> fetchEvents(String studioId) async {
    final response = await _client
        .from('events')
        .select()
        .eq('studio_id', studioId)
        .order('created_at', ascending: false);

    return response
        .map<AdminEvent>((row) => AdminEvent.fromMap(row))
        .toList(growable: false);
  }

  Future<void> saveEvent({
    String? id,
    required String studioId,
    required String title,
    required String body,
    required bool isImportant,
    required bool isPublished,
    required String status,
    required DateTime? visibleFrom,
    required DateTime? visibleUntil,
  }) async {
    final payload = {
      'studio_id': studioId,
      'title': title,
      'body': body,
      'is_important': isImportant,
      'is_published': isPublished,
      'status': status,
      'visible_from': visibleFrom?.toIso8601String(),
      'visible_until': visibleUntil?.toIso8601String(),
    };

    if (id == null) {
      await _client.from('events').insert({
        ...payload,
        'created_by_admin_id': _client.auth.currentUser!.id,
      });
      return;
    }

    await _client.from('events').update(payload).eq('id', id);
  }

  Future<void> deleteEvent({required String id}) async {
    await _client.from('events').delete().eq('id', id);
  }

  Future<void> updateStudioSettings({
    required AdminStudioSummary currentStudio,
    required String? contactPhone,
    required String? address,
    PickedImageFile? imageFile,
    bool removeImage = false,
    bool clearMustChangePassword = false,
  }) async {
    String? resolvedImageUrl = currentStudio.imageUrl;
    final studioImagePath = _imageStorage.studioObjectPath(currentStudio.id);
    var removeStoredImageAfterSave = false;

    if (removeImage) {
      resolvedImageUrl = null;
      removeStoredImageAfterSave = true;
    } else if (imageFile != null) {
      resolvedImageUrl = await _imageStorage.uploadStudioImage(
        studioId: currentStudio.id,
        file: imageFile,
      );
    }

    await _client
        .from('studios')
        .update({
          'contact_phone': _nullIfBlank(contactPhone),
          'address': _nullIfBlank(address),
          'image_url': _nullIfBlank(resolvedImageUrl),
        })
        .eq('id', currentStudio.id);

    if (removeStoredImageAfterSave) {
      await _imageStorage.removeObject(studioImagePath);
    }

    if (clearMustChangePassword) {
      await _client
          .from('admin_users')
          .update({'must_change_password': false})
          .eq('id', _client.auth.currentUser!.id);
    }
  }

  Future<void> updateStudioCancelPolicy({
    required String studioId,
    required String cancelPolicyMode,
    required int cancelPolicyHoursBefore,
    required int cancelPolicyDaysBefore,
    required String cancelPolicyCutoffTime,
    required bool cancelInquiryEnabled,
  }) async {
    await _client
        .from('studios')
        .update({
          'cancel_policy_mode': cancelPolicyMode,
          'cancel_policy_hours_before': cancelPolicyHoursBefore,
          'cancel_policy_days_before': cancelPolicyDaysBefore,
          'cancel_policy_cutoff_time': _normalizeTime(cancelPolicyCutoffTime),
          'cancel_inquiry_enabled': cancelInquiryEnabled,
        })
        .eq('id', studioId);
  }

  Future<void> savePassProduct({
    String? id,
    required String studioId,
    required String name,
    required int totalCount,
    required int validDays,
    required double priceAmount,
    required String description,
    required String status,
    required List<String> templateIds,
  }) async {
    final payload = {
      'studio_id': studioId,
      'name': name,
      'total_count': totalCount,
      'valid_days': validDays,
      'price_amount': priceAmount,
      'description': description,
      'status': status,
    };

    final productResponse = id == null
        ? await _client.from('pass_products').insert(payload).select().single()
        : await _client
              .from('pass_products')
              .update(payload)
              .eq('id', id)
              .select()
              .single();

    final productId = productResponse['id'] as String;
    await _client
        .from('pass_product_template_mappings')
        .delete()
        .eq('pass_product_id', productId);

    if (templateIds.isEmpty) {
      return;
    }

    await _client
        .from('pass_product_template_mappings')
        .insert(
          templateIds
              .map(
                (templateId) => {
                  'studio_id': studioId,
                  'pass_product_id': productId,
                  'class_template_id': templateId,
                },
              )
              .toList(growable: false),
        );
  }

  Future<List<AdminMember>> fetchMembers(String studioId) async {
    final response = await _client
        .from('v_admin_member_directory')
        .select()
        .eq('studio_id', studioId)
        .order('joined_at');

    return response
        .map<AdminMember>((row) => AdminMember.fromMap(row))
        .toList(growable: false);
  }

  Future<List<AdminMemberPassHistory>> fetchMemberPassHistories({
    required String studioId,
    required String userId,
  }) async {
    final response = await _client
        .from('v_admin_member_pass_histories')
        .select()
        .eq('studio_id', studioId)
        .eq('user_id', userId)
        .order('issued_at', ascending: false);

    return response
        .map<AdminMemberPassHistory>(
          (row) => AdminMemberPassHistory.fromMap(row),
        )
        .toList(growable: false);
  }

  Future<List<ReservationItem>> fetchMemberPassReservations({
    required String studioId,
    required String userId,
    required String userPassId,
  }) async {
    final response = await _client
        .from('v_user_reservation_details')
        .select()
        .eq('studio_id', studioId)
        .eq('user_id', userId)
        .eq('user_pass_id', userPassId)
        .order('start_at');

    return response
        .map<ReservationItem>((row) => ReservationItem.fromMap(row))
        .toList(growable: false);
  }

  Future<List<AdminMemberConsultNote>> fetchMemberConsultNotes({
    required String studioId,
    required String userId,
  }) async {
    final response = await _client
        .from('v_admin_member_consult_notes')
        .select()
        .eq('studio_id', studioId)
        .eq('user_id', userId)
        .order('consulted_on', ascending: false)
        .order('created_at', ascending: false);

    return response
        .map<AdminMemberConsultNote>(
          (row) => AdminMemberConsultNote.fromMap(row),
        )
        .toList(growable: false);
  }

  Future<AdminMemberLookupResult?> findMemberByCode(String memberCode) async {
    final normalized = memberCode.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    final response = await _client.rpc(
      'find_user_by_member_code',
      params: {'p_member_code': normalized},
    );

    if (response is List) {
      if (response.isEmpty) {
        return null;
      }
      return AdminMemberLookupResult.fromMap(
        response.first as Map<String, dynamic>,
      );
    }

    if (response is Map<String, dynamic>) {
      return AdminMemberLookupResult.fromMap(response);
    }

    return null;
  }

  Future<void> addMemberToStudio({required String userId}) async {
    await _client.rpc(
      'add_member_to_studio_admin',
      params: {'p_user_id': userId},
    );
  }

  Future<void> addMemberConsultNote({
    required String userId,
    required DateTime consultedOn,
    required String note,
  }) async {
    await _client.rpc(
      'create_member_consult_note_admin',
      params: {
        'p_user_id': userId,
        'p_consulted_on': _date.format(consultedOn),
        'p_note': note.trim(),
      },
    );
  }

  Future<void> deleteMemberConsultNote({required String noteId}) async {
    await _client.rpc(
      'delete_member_consult_note_admin',
      params: {'p_note_id': noteId},
    );
  }

  Future<void> issueUserPass({
    required String userId,
    required String passProductId,
    required DateTime validFrom,
    required double? paidAmount,
  }) async {
    await _client.rpc(
      'issue_user_pass_admin',
      params: {
        'p_user_id': userId,
        'p_pass_product_id': passProductId,
        'p_valid_from': _date.format(validFrom),
        'p_paid_amount': paidAmount,
      },
    );
  }

  Future<void> updateUserPass({
    required String userPassId,
    required int totalCount,
    required double paidAmount,
    required DateTime validFrom,
    required DateTime validUntil,
  }) async {
    await _client.rpc(
      'update_user_pass_admin',
      params: {
        'p_user_pass_id': userPassId,
        'p_total_count': totalCount,
        'p_paid_amount': paidAmount,
        'p_valid_from': _date.format(validFrom),
        'p_valid_until': _date.format(validUntil),
      },
    );
  }

  Future<void> refundUserPass({
    required String userPassId,
    required double refundAmount,
    String? refundReason,
  }) async {
    await _client.rpc(
      'refund_user_pass_admin',
      params: {
        'p_user_pass_id': userPassId,
        'p_refund_amount': refundAmount,
        'p_refund_reason': refundReason,
      },
    );
  }

  Future<void> holdUserPass({
    required String userPassId,
    required DateTime holdFrom,
    required DateTime holdUntil,
  }) async {
    await _client.rpc(
      'create_user_pass_hold_admin',
      params: {
        'p_user_pass_id': userPassId,
        'p_hold_from': _date.format(holdFrom),
        'p_hold_until': _date.format(holdUntil),
      },
    );
  }

  Future<void> cancelUserPassHold({required String userPassId}) async {
    await _client.rpc(
      'cancel_user_pass_hold_admin',
      params: {'p_user_pass_id': userPassId},
    );
  }

  Future<List<AdminDashboardPass>> fetchOperatingPasses() async {
    final response = await _client
        .from('v_admin_operating_pass_details')
        .select()
        .order('valid_until')
        .order('member_name');

    return response
        .map<AdminDashboardPass>((row) => AdminDashboardPass.fromMap(row))
        .toList(growable: false);
  }

  Future<List<AdminDashboardPass>> fetchExpiringPasses() async {
    final response = await _client
        .from('v_admin_expiring_pass_details')
        .select()
        .order('valid_until')
        .order('member_name');

    return response
        .map<AdminDashboardPass>((row) => AdminDashboardPass.fromMap(row))
        .toList(growable: false);
  }

  Future<List<StudioSignupRequest>> fetchPendingStudioSignupRequests() async {
    final response = await _client.rpc('fetch_pending_studio_signup_requests');
    return (response as List)
        .map<StudioSignupRequest>(
          (row) => StudioSignupRequest.fromMap(row as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<List<PlatformStudioOverview>> fetchPlatformStudioOverviews() async {
    final response = await _client.rpc('fetch_platform_studio_overview');
    return (response as List)
        .map<PlatformStudioOverview>(
          (row) => PlatformStudioOverview.fromMap(row as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<void> approveStudioSignupRequest(String requestId) async {
    await _client.rpc(
      'approve_studio_signup_request',
      params: {'p_request_id': requestId},
    );
  }

  Future<void> rejectStudioSignupRequest(
    String requestId, {
    String? reviewComment,
  }) async {
    await _client.rpc(
      'reject_studio_signup_request',
      params: {
        'p_request_id': requestId,
        'p_review_comment': _nullIfBlank(reviewComment),
      },
    );
  }

  Future<List<AdminSessionSchedule>> fetchSessions({
    required String studioId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _client
        .from('v_admin_class_session_feed')
        .select()
        .eq('studio_id', studioId)
        .gte('session_date', _date.format(startDate))
        .lte('session_date', _date.format(endDate))
        .order('start_at');

    return response
        .map<AdminSessionSchedule>((row) => AdminSessionSchedule.fromMap(row))
        .toList(growable: false);
  }

  Future<int> fetchPendingWaitlistRequestCount(String studioId) async {
    final response = await _client
        .from('v_admin_class_session_feed')
        .select('waitlist_count')
        .eq('studio_id', studioId)
        .eq('status', 'scheduled')
        .gt('waitlist_count', 0)
        .gt('end_at', DateTime.now().toUtc().toIso8601String());

    return response.fold<int>(
      0,
      (total, row) => total + ((row['waitlist_count'] as num?)?.toInt() ?? 0),
    );
  }

  Future<int> createSessionsFromTemplate({
    required String classTemplateId,
    required DateTime startDate,
    required DateTime endDate,
    int? capacity,
  }) async {
    try {
      final response = await _client.rpc(
        'create_class_sessions_from_template_admin',
        params: {
          'p_class_template_id': classTemplateId,
          'p_start_date': _date.format(startDate),
          'p_end_date': _date.format(endDate),
          'p_capacity': capacity,
        },
      );

      if (response is num) {
        return response.toInt();
      }
      return 0;
    } on PostgrestException catch (error) {
      if (_isMissingBulkCreateFunction(error)) {
        return _createSessionsFromTemplateLegacy(
          classTemplateId: classTemplateId,
          startDate: startDate,
          endDate: endDate,
          capacity: capacity,
        );
      }
      rethrow;
    }
  }

  Future<void> createOneOffSession({
    required String studioId,
    required String name,
    required String description,
    required DateTime sessionDate,
    required String startTime,
    required String endTime,
    required int capacity,
    required List<String> passProductIds,
    String? instructorId,
  }) async {
    try {
      await _client.rpc(
        'create_one_off_class_session_admin',
        params: {
          'p_name': name.trim(),
          'p_description': _nullIfBlank(description),
          'p_session_date': _date.format(sessionDate),
          'p_start_time': _normalizeTime(startTime),
          'p_end_time': _normalizeTime(endTime),
          'p_capacity': capacity,
          'p_pass_product_ids': passProductIds,
          'p_instructor_id': instructorId,
        },
      );
    } on PostgrestException catch (error) {
      if (_isMissingOneOffCreateFunction(error)) {
        await _createOneOffSessionLegacy(
          studioId: studioId,
          name: name,
          description: description,
          sessionDate: sessionDate,
          startTime: startTime,
          endTime: endTime,
          capacity: capacity,
          passProductIds: passProductIds,
          instructorId: instructorId,
        );
        return;
      }
      rethrow;
    }
  }

  Future<int> _createSessionsFromTemplateLegacy({
    required String classTemplateId,
    required DateTime startDate,
    required DateTime endDate,
    int? capacity,
  }) async {
    final templateResponse = await _client
        .from('class_templates')
        .select('day_of_week_mask')
        .eq('id', classTemplateId)
        .single();
    final dayOfWeekMask = _stringList(templateResponse['day_of_week_mask']);
    final allowedWeekdays = dayOfWeekMask
        .map(_weekdayCodeToIsoWeekday)
        .whereType<int>()
        .toSet();

    var createdCount = 0;
    for (
      var date = DateTime(startDate.year, startDate.month, startDate.day);
      !date.isAfter(DateTime(endDate.year, endDate.month, endDate.day));
      date = date.add(const Duration(days: 1))
    ) {
      if (!allowedWeekdays.contains(date.weekday)) {
        continue;
      }

      try {
        await _client.rpc(
          'create_class_session_from_template_admin',
          params: {
            'p_class_template_id': classTemplateId,
            'p_session_date': _date.format(date),
            'p_capacity': capacity,
          },
        );
        createdCount += 1;
      } on PostgrestException catch (error) {
        final message = error.message.toLowerCase();
        if (message.contains('session already exists')) {
          continue;
        }
        rethrow;
      }
    }

    return createdCount;
  }

  bool _isMissingBulkCreateFunction(PostgrestException error) {
    return error.code == 'PGRST202' &&
        error.message.contains('create_class_sessions_from_template_admin');
  }

  bool _isMissingOneOffCreateFunction(PostgrestException error) {
    return error.code == 'PGRST202' &&
        error.message.contains('create_one_off_class_session_admin');
  }

  Future<void> _createOneOffSessionLegacy({
    required String studioId,
    required String name,
    required String description,
    required DateTime sessionDate,
    required String startTime,
    required String endTime,
    required int capacity,
    required List<String> passProductIds,
    String? instructorId,
  }) async {
    final sanitizedPassProductIds = passProductIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (sanitizedPassProductIds.isEmpty) {
      throw StateError('수강권 상품을 한 개 이상 선택하세요.');
    }

    final template = await _client
        .from('class_templates')
        .insert({
          'studio_id': studioId,
          'name': name.trim(),
          'category': '일회성',
          'default_instructor_id': instructorId,
          'description': _nullIfBlank(description),
          'day_of_week_mask': [_weekdayCode(sessionDate)],
          'start_time': _normalizeTime(startTime),
          'end_time': _normalizeTime(endTime),
          'capacity': capacity,
          'status': 'active',
        })
        .select('id')
        .single();

    final templateId = template['id'] as String;

    await _client
        .from('pass_product_template_mappings')
        .insert(
          sanitizedPassProductIds
              .map(
                (passProductId) => {
                  'studio_id': studioId,
                  'pass_product_id': passProductId,
                  'class_template_id': templateId,
                },
              )
              .toList(growable: false),
        );

    await _client.from('class_sessions').insert({
      'studio_id': studioId,
      'class_template_id': templateId,
      'session_date': _date.format(sessionDate),
      'start_at':
          '${_date.format(sessionDate)}T${_normalizeTime(startTime)}+09:00',
      'end_at': '${_date.format(sessionDate)}T${_normalizeTime(endTime)}+09:00',
      'instructor_id': instructorId,
      'capacity': capacity,
      'status': 'scheduled',
      'created_by_admin_id': _client.auth.currentUser!.id,
    });
  }

  Future<void> assignInstructorToSession({
    required String sessionId,
    String? instructorId,
  }) async {
    await _client.rpc(
      'assign_session_instructor_admin',
      params: {'p_session_id': sessionId, 'p_instructor_id': instructorId},
    );
  }

  Future<void> updateSessionCapacity({
    required String sessionId,
    required int capacity,
  }) async {
    await _client
        .from('class_sessions')
        .update({'capacity': capacity})
        .eq('id', sessionId);
  }

  Future<void> deleteSession({required String sessionId}) async {
    try {
      await _client.rpc(
        'delete_class_session_admin',
        params: {'p_session_id': sessionId},
      );
    } on PostgrestException catch (error) {
      if (_isMissingDeleteSessionFunction(error)) {
        final session = await _client
            .from('class_sessions')
            .select('id, status, class_template_id')
            .eq('id', sessionId)
            .maybeSingle();
        if (session == null) {
          throw StateError('수업 정보를 찾을 수 없습니다.');
        }
        if (session['status'] == 'completed') {
          throw StateError('완료된 수업은 삭제할 수 없습니다.');
        }
        final reservations = await _client
            .from('reservations')
            .select('id')
            .eq('class_session_id', sessionId)
            .limit(1);
        if (reservations.isNotEmpty) {
          throw StateError('예약 내역이 있는 수업은 삭제할 수 없습니다.');
        }
        final templateId = session['class_template_id'] as String?;
        String? templateCategory;
        if (templateId != null) {
          final template = await _client
              .from('class_templates')
              .select('category')
              .eq('id', templateId)
              .maybeSingle();
          templateCategory = template?['category'] as String?;
        }
        await _client.from('class_sessions').delete().eq('id', sessionId);
        if (templateId != null && templateCategory == '일회성') {
          final remainingSessions = await _client
              .from('class_sessions')
              .select('id')
              .eq('class_template_id', templateId)
              .limit(1);
          if (remainingSessions.isEmpty) {
            await _client.from('class_templates').delete().eq('id', templateId);
          }
        }
        return;
      }
      rethrow;
    }
  }

  bool _isMissingDeleteSessionFunction(PostgrestException error) {
    return error.code == 'PGRST202' &&
        error.message.contains('delete_class_session_admin');
  }

  Future<List<AdminSessionAttendee>> fetchSessionAttendees({
    required String sessionId,
  }) async {
    final reservations = await _client
        .from('reservations')
        .select('id, user_id, status, created_at, waitlist_order')
        .eq('class_session_id', sessionId)
        .inFilter('status', ['reserved', 'cancel_requested', 'waitlisted'])
        .order('created_at');

    if (reservations.isEmpty) {
      return const [];
    }

    final userIds = reservations
        .map<String>((row) => row['user_id'] as String)
        .toSet()
        .toList(growable: false);
    final users = await _client
        .from('users')
        .select('id, member_code, name, phone, email')
        .inFilter('id', userIds);
    final userById = {for (final row in users) row['id'] as String: row};

    return reservations
        .map<AdminSessionAttendee>((row) {
          final userId = row['user_id'] as String;
          final user = userById[userId] ?? const <String, dynamic>{};
          return AdminSessionAttendee(
            reservationId: row['id'] as String,
            userId: userId,
            memberCode: user['member_code'] as String? ?? '',
            name: user['name'] as String?,
            memberPhone: user['phone'] as String?,
            memberEmail: user['email'] as String?,
            status: row['status'] as String? ?? 'reserved',
            waitlistOrder: (row['waitlist_order'] as num?)?.toInt(),
            createdAt: DateTime.parse(row['created_at'] as String),
          );
        })
        .toList(growable: false);
  }

  Future<String> addMemberToSession({
    required String sessionId,
    required String memberCode,
  }) async {
    final response = await _client.rpc(
      'add_member_to_session_admin',
      params: {'p_session_id': sessionId, 'p_member_code': memberCode.trim()},
    );

    if (response is Map<String, dynamic>) {
      return response['status'] as String? ?? 'reserved';
    }
    return 'reserved';
  }

  Future<void> removeMemberFromSession({
    required String reservationId,
    required String comment,
  }) async {
    await _client.rpc(
      'remove_member_from_session_admin',
      params: {'p_reservation_id': reservationId, 'p_comment': comment.trim()},
    );
  }

  Future<void> approveWaitlistedReservation({
    required String reservationId,
  }) async {
    await _client.rpc(
      'approve_waitlisted_reservation_admin',
      params: {'p_reservation_id': reservationId},
    );
  }

  Future<List<AdminCancelRequest>> fetchCancelRequests(String studioId) async {
    final response = await _client
        .from('v_admin_cancel_request_details')
        .select()
        .eq('studio_id', studioId)
        .order('requested_cancel_at', ascending: false);

    return response
        .map<AdminCancelRequest>((row) => AdminCancelRequest.fromMap(row))
        .toList(growable: false);
  }

  Future<List<AdminCancelRequest>> fetchPendingCancelRequests(
    String studioId,
  ) async {
    final response = await _client
        .from('v_admin_cancel_request_details')
        .select()
        .eq('studio_id', studioId)
        .eq('status', 'cancel_requested')
        .not('requested_cancel_at', 'is', null)
        .order('requested_cancel_at', ascending: false);

    return response
        .map<AdminCancelRequest>((row) => AdminCancelRequest.fromMap(row))
        .toList(growable: false);
  }

  Future<int> fetchPendingCancelRequestCount(String studioId) async {
    final response = await _client
        .from('v_admin_cancel_request_details')
        .select('id')
        .eq('studio_id', studioId)
        .eq('status', 'cancel_requested')
        .not('requested_cancel_at', 'is', null);

    return response.length;
  }

  Future<void> approveCancelRequest({
    required String reservationId,
    required String comment,
  }) async {
    await _client.rpc(
      'approve_reservation_cancel_request_admin',
      params: {'p_reservation_id': reservationId, 'p_comment': comment.trim()},
    );
  }

  Future<void> rejectCancelRequest({
    required String reservationId,
    required String comment,
  }) async {
    await _client.rpc(
      'reject_reservation_cancel_request_admin',
      params: {'p_reservation_id': reservationId, 'p_comment': comment.trim()},
    );
  }
}

String _normalizeTime(String value) {
  final trimmed = value.trim();
  if (trimmed.length == 5) {
    return '$trimmed:00';
  }
  return trimmed;
}

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

Future<void> _ensureInstructorNameAvailable({
  required SupabaseClient client,
  required String studioId,
  required String name,
  String? excludeInstructorId,
}) async {
  var query = client
      .from('instructors')
      .select('id')
      .eq('studio_id', studioId)
      .ilike('name', name);
  if (excludeInstructorId != null) {
    query = query.neq('id', excludeInstructorId);
  }
  final response = await query.limit(1);

  if (response.isNotEmpty) {
    throw StateError('같은 스튜디오에 동일한 이름의 강사가 이미 있습니다.');
  }
}

String _weekdayCode(DateTime date) {
  switch (date.weekday) {
    case DateTime.monday:
      return 'mon';
    case DateTime.tuesday:
      return 'tue';
    case DateTime.wednesday:
      return 'wed';
    case DateTime.thursday:
      return 'thu';
    case DateTime.friday:
      return 'fri';
    case DateTime.saturday:
      return 'sat';
    default:
      return 'sun';
  }
}

List<String> _stringList(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value.map((item) => item.toString()).toList(growable: false);
}

int? _weekdayCodeToIsoWeekday(String code) {
  switch (code) {
    case 'mon':
      return DateTime.monday;
    case 'tue':
      return DateTime.tuesday;
    case 'wed':
      return DateTime.wednesday;
    case 'thu':
      return DateTime.thursday;
    case 'fri':
      return DateTime.friday;
    case 'sat':
      return DateTime.saturday;
    case 'sun':
      return DateTime.sunday;
    default:
      return null;
  }
}
