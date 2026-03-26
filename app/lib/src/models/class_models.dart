class ClassSessionItem {
  const ClassSessionItem({
    required this.id,
    required this.studioId,
    required this.classTemplateId,
    required this.sessionDate,
    required this.startAt,
    required this.endAt,
    required this.capacity,
    required this.status,
    required this.className,
    required this.category,
    required this.description,
    this.instructorName,
    this.instructorImageUrl,
    required this.spotsLeft,
    required this.waitlistCount,
    required this.myReservationId,
    required this.myReservationStatus,
    this.canCancelDirectly = false,
    this.canRequestCancel = false,
    this.isCancelLocked = false,
  });

  final String id;
  final String studioId;
  final String classTemplateId;
  final DateTime sessionDate;
  final DateTime startAt;
  final DateTime endAt;
  final int capacity;
  final String status;
  final String className;
  final String category;
  final String? description;
  final String? instructorName;
  final String? instructorImageUrl;
  final int spotsLeft;
  final int waitlistCount;
  final String? myReservationId;
  final String? myReservationStatus;
  final bool canCancelDirectly;
  final bool canRequestCancel;
  final bool isCancelLocked;

  bool get hasWaitlist => waitlistCount > 0;
  bool get requiresWaitlist => hasWaitlist || spotsLeft <= 0;
  bool get canReserveImmediately => spotsLeft > 0 && !hasWaitlist;
  bool get isReserved => myReservationStatus == 'reserved';
  bool get isWaitlisted => myReservationStatus == 'waitlisted';
  bool get isCancelRequested => myReservationStatus == 'cancel_requested';
  bool get isStudioRejected => myReservationStatus == 'studio_rejected';
  bool get isCompleted => myReservationStatus == 'completed';
  bool get isCancelled =>
      myReservationStatus == 'cancelled' ||
      myReservationStatus == 'studio_cancelled';
  bool get isRebookableCancelled =>
      myReservationStatus == 'cancelled' &&
      status == 'scheduled' &&
      startAt.isAfter(DateTime.now());
  bool get isStarted => startAt.isBefore(DateTime.now());

  factory ClassSessionItem.fromMap(Map<String, dynamic> map) {
    return ClassSessionItem(
      id: map['id'] as String,
      studioId: map['studio_id'] as String,
      classTemplateId: map['class_template_id'] as String,
      sessionDate: DateTime.parse(map['session_date'] as String),
      startAt: DateTime.parse(map['start_at'] as String),
      endAt: DateTime.parse(map['end_at'] as String),
      capacity: (map['capacity'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'scheduled',
      className: map['class_name'] as String? ?? '',
      category: map['category'] as String? ?? '',
      description: map['description'] as String?,
      instructorName: map['instructor_name'] as String?,
      instructorImageUrl: map['instructor_image_url'] as String?,
      spotsLeft: (map['spots_left'] as num?)?.toInt() ?? 0,
      waitlistCount: (map['waitlist_count'] as num?)?.toInt() ?? 0,
      myReservationId: map['my_reservation_id'] as String?,
      myReservationStatus: map['my_reservation_status'] as String?,
      canCancelDirectly: map['can_cancel_directly'] as bool? ?? false,
      canRequestCancel: map['can_request_cancel'] as bool? ?? false,
      isCancelLocked: map['is_cancel_locked'] as bool? ?? false,
    );
  }
}

class ReservationItem {
  const ReservationItem({
    required this.id,
    required this.studioId,
    required this.userId,
    required this.classSessionId,
    required this.userPassId,
    required this.status,
    required this.requestCancelReason,
    required this.requestedCancelAt,
    required this.approvedCancelAt,
    required this.approvedCancelComment,
    required this.approvedCancelAdminName,
    required this.cancelRequestResponseComment,
    required this.cancelRequestProcessedAt,
    required this.cancelRequestProcessedAdminName,
    required this.isWaitlisted,
    required this.waitlistOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.sessionDate,
    required this.startAt,
    required this.endAt,
    required this.capacity,
    required this.sessionStatus,
    required this.classTemplateId,
    required this.className,
    required this.category,
    required this.description,
    this.instructorName,
    this.instructorImageUrl,
    required this.spotsLeft,
    required this.waitlistCount,
    required this.passName,
    required this.canCancelDirectly,
    required this.canRequestCancel,
    required this.isCancelLocked,
  });

  final String id;
  final String studioId;
  final String userId;
  final String classSessionId;
  final String userPassId;
  final String status;
  final String? requestCancelReason;
  final DateTime? requestedCancelAt;
  final DateTime? approvedCancelAt;
  final String? approvedCancelComment;
  final String? approvedCancelAdminName;
  final String? cancelRequestResponseComment;
  final DateTime? cancelRequestProcessedAt;
  final String? cancelRequestProcessedAdminName;
  final bool isWaitlisted;
  final int? waitlistOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime sessionDate;
  final DateTime startAt;
  final DateTime endAt;
  final int capacity;
  final String sessionStatus;
  final String classTemplateId;
  final String className;
  final String category;
  final String? description;
  final String? instructorName;
  final String? instructorImageUrl;
  final int spotsLeft;
  final int waitlistCount;
  final String passName;
  final bool canCancelDirectly;
  final bool canRequestCancel;
  final bool isCancelLocked;

  bool get isApprovedCancel => status == 'cancelled' && approvedCancelAt != null;
  bool get isMemberCancelled => status == 'cancelled' && approvedCancelAt == null;
  bool get canRebookAfterCancel =>
      isMemberCancelled &&
      sessionStatus == 'scheduled' &&
      startAt.isAfter(DateTime.now());

  factory ReservationItem.fromMap(Map<String, dynamic> map) {
    return ReservationItem(
      id: map['id'] as String,
      studioId: map['studio_id'] as String,
      userId: map['user_id'] as String,
      classSessionId: map['class_session_id'] as String,
      userPassId: map['user_pass_id'] as String,
      status: map['status'] as String? ?? '',
      requestCancelReason: map['request_cancel_reason'] as String?,
      requestedCancelAt: _parseDate(map['requested_cancel_at']),
      approvedCancelAt: _parseDate(map['approved_cancel_at']),
      approvedCancelComment: map['approved_cancel_comment'] as String?,
      approvedCancelAdminName: map['approved_cancel_admin_name'] as String?,
      cancelRequestResponseComment:
          map['cancel_request_response_comment'] as String?,
      cancelRequestProcessedAt: _parseDate(map['cancel_request_processed_at']),
      cancelRequestProcessedAdminName:
          map['cancel_request_processed_admin_name'] as String?,
      isWaitlisted: map['is_waitlisted'] as bool? ?? false,
      waitlistOrder: (map['waitlist_order'] as num?)?.toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      sessionDate: DateTime.parse(map['session_date'] as String),
      startAt: DateTime.parse(map['start_at'] as String),
      endAt: DateTime.parse(map['end_at'] as String),
      capacity: (map['capacity'] as num?)?.toInt() ?? 0,
      sessionStatus: map['session_status'] as String? ?? 'scheduled',
      classTemplateId: map['class_template_id'] as String,
      className: map['class_name'] as String? ?? '',
      category: map['category'] as String? ?? '',
      description: map['description'] as String?,
      instructorName: map['instructor_name'] as String?,
      instructorImageUrl: map['instructor_image_url'] as String?,
      spotsLeft: (map['spots_left'] as num?)?.toInt() ?? 0,
      waitlistCount: (map['waitlist_count'] as num?)?.toInt() ?? 0,
      passName: map['pass_name'] as String? ?? '',
      canCancelDirectly: map['can_cancel_directly'] as bool? ?? false,
      canRequestCancel: map['can_request_cancel'] as bool? ?? false,
      isCancelLocked: map['is_cancel_locked'] as bool? ?? false,
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.parse(value as String);
}
