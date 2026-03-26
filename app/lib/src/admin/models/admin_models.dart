class PlatformAdminProfile {
  const PlatformAdminProfile({
    required this.id,
    required this.loginId,
    required this.name,
    required this.email,
    required this.phone,
    required this.status,
  });

  final String id;
  final String loginId;
  final String? name;
  final String? email;
  final String? phone;
  final String status;

  factory PlatformAdminProfile.fromMap(Map<String, dynamic> map) {
    return PlatformAdminProfile(
      id: map['id'] as String,
      loginId: map['login_id'] as String? ?? '',
      name: map['name'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      status: map['status'] as String? ?? 'inactive',
    );
  }
}

class StudioSignupRequest {
  const StudioSignupRequest({
    required this.id,
    required this.studioName,
    required this.studioPhone,
    required this.studioAddress,
    required this.representativeName,
    required this.requestedLoginId,
    required this.requestedEmail,
    required this.status,
    required this.reviewComment,
    required this.createdAt,
  });

  final String id;
  final String studioName;
  final String studioPhone;
  final String studioAddress;
  final String representativeName;
  final String requestedLoginId;
  final String requestedEmail;
  final String status;
  final String? reviewComment;
  final DateTime createdAt;

  factory StudioSignupRequest.fromMap(Map<String, dynamic> map) {
    return StudioSignupRequest(
      id: map['id'] as String,
      studioName: map['studio_name'] as String? ?? '',
      studioPhone: map['studio_phone'] as String? ?? '',
      studioAddress: map['studio_address'] as String? ?? '',
      representativeName: map['representative_name'] as String? ?? '',
      requestedLoginId: map['requested_login_id'] as String? ?? '',
      requestedEmail: map['requested_email'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      reviewComment: map['review_comment'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class PlatformStudioOverview {
  const PlatformStudioOverview({
    required this.studioId,
    required this.studioName,
    required this.studioPhone,
    required this.studioAddress,
    required this.studioLoginId,
    required this.representativeName,
    required this.representativeEmail,
    required this.templateCount,
    required this.monthSessionCount,
    required this.instructorCount,
    required this.memberCount,
    required this.issuedPassCount,
    required this.monthSalesAmount,
  });

  final String studioId;
  final String studioName;
  final String? studioPhone;
  final String? studioAddress;
  final String? studioLoginId;
  final String? representativeName;
  final String? representativeEmail;
  final int templateCount;
  final int monthSessionCount;
  final int instructorCount;
  final int memberCount;
  final int issuedPassCount;
  final double monthSalesAmount;

  factory PlatformStudioOverview.fromMap(Map<String, dynamic> map) {
    return PlatformStudioOverview(
      studioId: map['studio_id'] as String,
      studioName: map['studio_name'] as String? ?? '',
      studioPhone: map['studio_phone'] as String?,
      studioAddress: map['studio_address'] as String?,
      studioLoginId: map['studio_login_id'] as String?,
      representativeName: map['representative_name'] as String?,
      representativeEmail: map['representative_email'] as String?,
      templateCount: (map['template_count'] as num?)?.toInt() ?? 0,
      monthSessionCount: (map['month_session_count'] as num?)?.toInt() ?? 0,
      instructorCount: (map['instructor_count'] as num?)?.toInt() ?? 0,
      memberCount: (map['member_count'] as num?)?.toInt() ?? 0,
      issuedPassCount: (map['issued_pass_count'] as num?)?.toInt() ?? 0,
      monthSalesAmount: (map['month_sales_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdminStudioSummary {
  const AdminStudioSummary({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.contactPhone,
    required this.address,
    required this.cancelPolicyMode,
    required this.cancelPolicyHoursBefore,
    required this.cancelPolicyDaysBefore,
    required this.cancelPolicyCutoffTime,
    required this.cancelInquiryEnabled,
    required this.status,
  });

  final String id;
  final String name;
  final String? imageUrl;
  final String? contactPhone;
  final String? address;
  final String cancelPolicyMode;
  final int cancelPolicyHoursBefore;
  final int cancelPolicyDaysBefore;
  final String cancelPolicyCutoffTime;
  final bool cancelInquiryEnabled;
  final String status;

  factory AdminStudioSummary.fromMap(Map<String, dynamic> map) {
    return AdminStudioSummary(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      contactPhone: map['contact_phone'] as String?,
      address: map['address'] as String?,
      cancelPolicyMode: map['cancel_policy_mode'] as String? ?? 'hours_before',
      cancelPolicyHoursBefore:
          (map['cancel_policy_hours_before'] as num?)?.toInt() ?? 24,
      cancelPolicyDaysBefore:
          (map['cancel_policy_days_before'] as num?)?.toInt() ?? 1,
      cancelPolicyCutoffTime: _timeOnly(
        map['cancel_policy_cutoff_time'] as String? ?? '18:00',
      ),
      cancelInquiryEnabled: map['cancel_inquiry_enabled'] as bool? ?? true,
      status: map['status'] as String? ?? 'inactive',
    );
  }
}

class AdminProfile {
  const AdminProfile({
    required this.id,
    required this.studioId,
    required this.loginId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.mustChangePassword,
    required this.status,
    required this.studio,
  });

  final String id;
  final String studioId;
  final String loginId;
  final String? name;
  final String? email;
  final String? phone;
  final String role;
  final bool mustChangePassword;
  final String status;
  final AdminStudioSummary studio;

  factory AdminProfile.fromMap(Map<String, dynamic> map) {
    return AdminProfile(
      id: map['id'] as String,
      studioId: map['studio_id'] as String,
      loginId: map['login_id'] as String? ?? '',
      name: map['name'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      role: map['role'] as String? ?? 'admin',
      mustChangePassword: map['must_change_password'] as bool? ?? false,
      status: map['status'] as String? ?? 'inactive',
      studio: AdminStudioSummary.fromMap(
        map['studio'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class AdminDashboardMetrics {
  const AdminDashboardMetrics({
    required this.todaySessionCount,
    required this.todayReservedCount,
    required this.monthSalesAmount,
    required this.previousMonthSalesAmount,
    required this.monthRefundAmount,
    required this.operatingPassCount,
    required this.expiringPassCount,
    required this.pendingCancelRequestCount,
    required this.previousMonthRefundAmount,
  });

  final int todaySessionCount;
  final int todayReservedCount;
  final double monthSalesAmount;
  final double previousMonthSalesAmount;
  final double monthRefundAmount;
  final int operatingPassCount;
  final int expiringPassCount;
  final int pendingCancelRequestCount;
  final double previousMonthRefundAmount;

  factory AdminDashboardMetrics.fromMap(Map<String, dynamic> map) {
    return AdminDashboardMetrics(
      todaySessionCount: (map['today_session_count'] as num?)?.toInt() ?? 0,
      todayReservedCount: (map['today_reserved_count'] as num?)?.toInt() ?? 0,
      monthSalesAmount: (map['month_sales_amount'] as num?)?.toDouble() ?? 0,
      previousMonthSalesAmount:
          (map['previous_month_sales_amount'] as num?)?.toDouble() ?? 0,
      monthRefundAmount: (map['month_refund_amount'] as num?)?.toDouble() ?? 0,
      operatingPassCount: (map['operating_pass_count'] as num?)?.toInt() ?? 0,
      expiringPassCount: (map['expiring_pass_count'] as num?)?.toInt() ?? 0,
      pendingCancelRequestCount:
          (map['pending_cancel_request_count'] as num?)?.toInt() ?? 0,
      previousMonthRefundAmount:
          (map['previous_month_refund_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdminMonthlyClassMetric {
  const AdminMonthlyClassMetric({
    required this.classTemplateId,
    required this.studioId,
    required this.className,
    required this.category,
    required this.capacity,
    required this.openedSessionCount,
    required this.avgReservedCount,
  });

  final String classTemplateId;
  final String studioId;
  final String className;
  final String category;
  final int capacity;
  final int openedSessionCount;
  final double avgReservedCount;

  factory AdminMonthlyClassMetric.fromMap(Map<String, dynamic> map) {
    return AdminMonthlyClassMetric(
      classTemplateId: map['class_template_id'] as String,
      studioId: map['studio_id'] as String,
      className: map['class_name'] as String? ?? '',
      category: map['category'] as String? ?? '',
      capacity: (map['capacity'] as num?)?.toInt() ?? 0,
      openedSessionCount: (map['opened_session_count'] as num?)?.toInt() ?? 0,
      avgReservedCount: (map['avg_reserved_count'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdminMonthlyFinancialMetric {
  const AdminMonthlyFinancialMetric({
    required this.studioId,
    required this.monthStart,
    required this.salesAmount,
    required this.refundAmount,
  });

  final String studioId;
  final DateTime monthStart;
  final double salesAmount;
  final double refundAmount;

  factory AdminMonthlyFinancialMetric.fromMap(Map<String, dynamic> map) {
    return AdminMonthlyFinancialMetric(
      studioId: map['studio_id'] as String,
      monthStart: DateTime.parse(map['month_start'] as String),
      salesAmount: (map['sales_amount'] as num?)?.toDouble() ?? 0,
      refundAmount: (map['refund_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdminMonthlyReservationSummary {
  const AdminMonthlyReservationSummary({
    required this.classSessionId,
    required this.studioId,
    required this.sessionDate,
    required this.startAt,
    required this.endAt,
    required this.capacity,
    required this.sessionStatus,
    required this.className,
    required this.category,
    required this.reservationCount,
  });

  final String classSessionId;
  final String studioId;
  final DateTime sessionDate;
  final DateTime startAt;
  final DateTime endAt;
  final int capacity;
  final String sessionStatus;
  final String className;
  final String category;
  final int reservationCount;

  factory AdminMonthlyReservationSummary.fromMap(Map<String, dynamic> map) {
    return AdminMonthlyReservationSummary(
      classSessionId: map['class_session_id'] as String,
      studioId: map['studio_id'] as String,
      sessionDate: DateTime.parse(map['session_date'] as String),
      startAt: DateTime.parse(map['start_at'] as String),
      endAt: DateTime.parse(map['end_at'] as String),
      capacity: (map['capacity'] as num?)?.toInt() ?? 0,
      sessionStatus: map['session_status'] as String? ?? 'scheduled',
      className: map['class_name'] as String? ?? '',
      category: map['category'] as String? ?? '',
      reservationCount: (map['reservation_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminNotice {
  const AdminNotice({
    required this.id,
    required this.studioId,
    required this.title,
    required this.body,
    required this.isImportant,
    required this.isPublished,
    required this.visibleFrom,
    required this.visibleUntil,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String studioId;
  final String title;
  final String body;
  final bool isImportant;
  final bool isPublished;
  final DateTime? visibleFrom;
  final DateTime? visibleUntil;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdminNotice.fromMap(Map<String, dynamic> map) {
    return AdminNotice(
      id: map['id'] as String,
      studioId: map['studio_id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      isImportant: map['is_important'] as bool? ?? false,
      isPublished: map['is_published'] as bool? ?? true,
      visibleFrom: _parseDate(map['visible_from']),
      visibleUntil: _parseDate(map['visible_until']),
      status: map['status'] as String? ?? 'inactive',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class AdminEvent {
  const AdminEvent({
    required this.id,
    required this.studioId,
    required this.title,
    required this.body,
    required this.isImportant,
    required this.isPublished,
    required this.visibleFrom,
    required this.visibleUntil,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String studioId;
  final String title;
  final String body;
  final bool isImportant;
  final bool isPublished;
  final DateTime? visibleFrom;
  final DateTime? visibleUntil;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdminEvent.fromMap(Map<String, dynamic> map) {
    return AdminEvent(
      id: map['id'] as String,
      studioId: map['studio_id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      isImportant: map['is_important'] as bool? ?? false,
      isPublished: map['is_published'] as bool? ?? true,
      visibleFrom: _parseDate(map['visible_from']),
      visibleUntil: _parseDate(map['visible_until']),
      status: map['status'] as String? ?? 'inactive',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class AdminClassTemplate {
  const AdminClassTemplate({
    required this.id,
    required this.studioId,
    required this.name,
    required this.category,
    required this.defaultInstructorId,
    required this.description,
    required this.dayOfWeekMask,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.status,
  });

  final String id;
  final String studioId;
  final String name;
  final String category;
  final String? defaultInstructorId;
  final String? description;
  final List<String> dayOfWeekMask;
  final String startTime;
  final String endTime;
  final int capacity;
  final String status;

  factory AdminClassTemplate.fromMap(Map<String, dynamic> map) {
    return AdminClassTemplate(
      id: map['id'] as String,
      studioId: map['studio_id'] as String,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? '',
      defaultInstructorId: map['default_instructor_id'] as String?,
      description: map['description'] as String?,
      dayOfWeekMask: _stringList(map['day_of_week_mask']),
      startTime: _timeOnly(map['start_time'] as String? ?? '00:00'),
      endTime: _timeOnly(map['end_time'] as String? ?? '00:00'),
      capacity: (map['capacity'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'inactive',
    );
  }
}

class AdminPassProduct {
  const AdminPassProduct({
    required this.id,
    required this.studioId,
    required this.name,
    required this.totalCount,
    required this.validDays,
    required this.priceAmount,
    required this.description,
    required this.status,
    required this.allowedTemplateIds,
    required this.allowedTemplateNames,
  });

  final String id;
  final String studioId;
  final String name;
  final int totalCount;
  final int validDays;
  final double priceAmount;
  final String? description;
  final String status;
  final List<String> allowedTemplateIds;
  final List<String> allowedTemplateNames;

  factory AdminPassProduct.fromMap(Map<String, dynamic> map) {
    return AdminPassProduct(
      id: map['id'] as String,
      studioId: map['studio_id'] as String,
      name: map['name'] as String? ?? '',
      totalCount: (map['total_count'] as num?)?.toInt() ?? 0,
      validDays: (map['valid_days'] as num?)?.toInt() ?? 0,
      priceAmount: (map['price_amount'] as num?)?.toDouble() ?? 0,
      description: map['description'] as String?,
      status: map['status'] as String? ?? 'inactive',
      allowedTemplateIds: _stringList(map['allowed_template_ids']),
      allowedTemplateNames: _stringList(map['allowed_template_names']),
    );
  }
}

class AdminInstructor {
  const AdminInstructor({
    required this.id,
    required this.studioId,
    required this.name,
    required this.phone,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String studioId;
  final String name;
  final String? phone;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdminInstructor.fromMap(Map<String, dynamic> map) {
    return AdminInstructor(
      id: map['id'] as String,
      studioId: map['studio_id'] as String,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String?,
      imageUrl: map['image_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class AdminMember {
  const AdminMember({
    required this.membershipId,
    required this.studioId,
    required this.userId,
    required this.membershipStatus,
    required this.joinedAt,
    required this.memberCode,
    required this.name,
    required this.email,
    required this.phone,
    required this.activePassCount,
    required this.latestPassValidUntil,
    required this.hasExpiringSoonActivePass,
    required this.expiringSoonActivePassDays,
  });

  final String membershipId;
  final String studioId;
  final String userId;
  final String membershipStatus;
  final DateTime joinedAt;
  final String memberCode;
  final String? name;
  final String? email;
  final String? phone;
  final int activePassCount;
  final DateTime? latestPassValidUntil;
  final bool hasExpiringSoonActivePass;
  final int? expiringSoonActivePassDays;

  factory AdminMember.fromMap(Map<String, dynamic> map) {
    return AdminMember(
      membershipId: map['membership_id'] as String,
      studioId: map['studio_id'] as String,
      userId: map['user_id'] as String,
      membershipStatus: map['membership_status'] as String? ?? 'inactive',
      joinedAt: DateTime.parse(map['joined_at'] as String),
      memberCode: map['member_code'] as String? ?? '',
      name: map['name'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      activePassCount: (map['active_pass_count'] as num?)?.toInt() ?? 0,
      latestPassValidUntil: _parseDate(map['latest_pass_valid_until']),
      hasExpiringSoonActivePass:
          map['has_expiring_soon_active_pass'] as bool? ?? false,
      expiringSoonActivePassDays:
          (map['expiring_soon_active_pass_days'] as num?)?.toInt(),
    );
  }
}

class AdminMemberLookupResult {
  const AdminMemberLookupResult({
    required this.id,
    required this.memberCode,
    required this.name,
    required this.email,
    required this.phone,
    required this.isActiveMember,
  });

  final String id;
  final String memberCode;
  final String? name;
  final String? email;
  final String? phone;
  final bool isActiveMember;

  factory AdminMemberLookupResult.fromMap(Map<String, dynamic> map) {
    return AdminMemberLookupResult(
      id: map['id'] as String,
      memberCode: map['member_code'] as String? ?? '',
      name: map['name'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      isActiveMember: map['is_active_member'] as bool? ?? false,
    );
  }
}

class AdminMemberPassHistory {
  const AdminMemberPassHistory({
    required this.id,
    required this.studioId,
    required this.userId,
    required this.memberCode,
    required this.memberName,
    required this.passProductId,
    required this.passName,
    required this.totalCount,
    required this.validFrom,
    required this.validUntil,
    required this.paidAmount,
    required this.refundedAmount,
    required this.status,
    required this.issuedAt,
    required this.plannedCount,
    required this.completedCount,
    required this.remainingCount,
    required this.totalHoldDays,
    required this.activeHoldFrom,
    required this.activeHoldUntil,
    required this.latestHoldFrom,
    required this.latestHoldUntil,
    required this.latestRefundedAt,
    required this.latestRefundReason,
  });

  final String id;
  final String studioId;
  final String userId;
  final String memberCode;
  final String? memberName;
  final String passProductId;
  final String passName;
  final int totalCount;
  final DateTime validFrom;
  final DateTime validUntil;
  final double paidAmount;
  final double refundedAmount;
  final String status;
  final DateTime issuedAt;
  final int plannedCount;
  final int completedCount;
  final int remainingCount;
  final int totalHoldDays;
  final DateTime? activeHoldFrom;
  final DateTime? activeHoldUntil;
  final DateTime? latestHoldFrom;
  final DateTime? latestHoldUntil;
  final DateTime? latestRefundedAt;
  final String? latestRefundReason;

  bool get isRefunded => status == 'refunded' || refundedAmount > 0;
  bool get isExhausted => status == 'exhausted' || remainingCount <= 0;
  bool get isCurrentlyHolding =>
      activeHoldFrom != null && activeHoldUntil != null;

  factory AdminMemberPassHistory.fromMap(Map<String, dynamic> map) {
    return AdminMemberPassHistory(
      id: map['id'] as String,
      studioId: map['studio_id'] as String,
      userId: map['user_id'] as String,
      memberCode: map['member_code'] as String? ?? '',
      memberName: map['member_name'] as String?,
      passProductId: map['pass_product_id'] as String,
      passName: map['pass_name'] as String? ?? '',
      totalCount: (map['total_count'] as num?)?.toInt() ?? 0,
      validFrom: DateTime.parse(map['valid_from'] as String),
      validUntil: DateTime.parse(map['valid_until'] as String),
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
      refundedAmount: (map['refunded_amount'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'inactive',
      issuedAt: DateTime.parse(map['issued_at'] as String),
      plannedCount: (map['planned_count'] as num?)?.toInt() ?? 0,
      completedCount: (map['completed_count'] as num?)?.toInt() ?? 0,
      remainingCount: (map['remaining_count'] as num?)?.toInt() ?? 0,
      totalHoldDays: (map['total_hold_days'] as num?)?.toInt() ?? 0,
      activeHoldFrom: _parseDate(map['active_hold_from']),
      activeHoldUntil: _parseDate(map['active_hold_until']),
      latestHoldFrom: _parseDate(map['latest_hold_from']),
      latestHoldUntil: _parseDate(map['latest_hold_until']),
      latestRefundedAt: _parseDate(map['latest_refunded_at']),
      latestRefundReason: map['latest_refund_reason'] as String?,
    );
  }
}

class AdminMemberConsultNote {
  const AdminMemberConsultNote({
    required this.id,
    required this.studioId,
    required this.userId,
    required this.memberCode,
    required this.memberName,
    required this.consultedOn,
    required this.note,
    required this.createdAt,
    required this.createdByAdminName,
  });

  final String id;
  final String studioId;
  final String userId;
  final String memberCode;
  final String? memberName;
  final DateTime consultedOn;
  final String note;
  final DateTime createdAt;
  final String? createdByAdminName;

  factory AdminMemberConsultNote.fromMap(Map<String, dynamic> map) {
    return AdminMemberConsultNote(
      id: map['id'] as String,
      studioId: map['studio_id'] as String,
      userId: map['user_id'] as String,
      memberCode: map['member_code'] as String? ?? '',
      memberName: map['member_name'] as String?,
      consultedOn: DateTime.parse(map['consulted_on'] as String),
      note: map['note'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      createdByAdminName: map['created_by_admin_name'] as String?,
    );
  }
}

class AdminDashboardPass {
  const AdminDashboardPass({
    required this.id,
    required this.studioId,
    required this.userId,
    required this.memberCode,
    required this.memberName,
    required this.memberPhone,
    required this.passName,
    required this.validFrom,
    required this.validUntil,
    required this.plannedCount,
    required this.completedCount,
    required this.remainingCount,
    required this.daysUntilExpiry,
  });

  final String id;
  final String studioId;
  final String userId;
  final String memberCode;
  final String? memberName;
  final String? memberPhone;
  final String passName;
  final DateTime validFrom;
  final DateTime validUntil;
  final int plannedCount;
  final int completedCount;
  final int remainingCount;
  final int daysUntilExpiry;

  factory AdminDashboardPass.fromMap(Map<String, dynamic> map) {
    return AdminDashboardPass(
      id: map['id'] as String,
      studioId: map['studio_id'] as String,
      userId: map['user_id'] as String,
      memberCode: map['member_code'] as String? ?? '',
      memberName: map['member_name'] as String?,
      memberPhone: map['member_phone'] as String?,
      passName: map['pass_name'] as String? ?? '',
      validFrom: DateTime.parse(map['valid_from'] as String),
      validUntil: DateTime.parse(map['valid_until'] as String),
      plannedCount: (map['planned_count'] as num?)?.toInt() ?? 0,
      completedCount: (map['completed_count'] as num?)?.toInt() ?? 0,
      remainingCount: (map['remaining_count'] as num?)?.toInt() ?? 0,
      daysUntilExpiry: (map['days_until_expiry'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminSessionSchedule {
  const AdminSessionSchedule({
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
    required this.instructorId,
    required this.instructorName,
    required this.instructorImageUrl,
    required this.spotsLeft,
    required this.waitlistCount,
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
  final String? instructorId;
  final String? instructorName;
  final String? instructorImageUrl;
  final int spotsLeft;
  final int waitlistCount;

  int get reservedCount => capacity - spotsLeft;

  factory AdminSessionSchedule.fromMap(Map<String, dynamic> map) {
    return AdminSessionSchedule(
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
      instructorId: map['instructor_id'] as String?,
      instructorName: map['instructor_name'] as String?,
      instructorImageUrl: map['instructor_image_url'] as String?,
      spotsLeft: (map['spots_left'] as num?)?.toInt() ?? 0,
      waitlistCount: (map['waitlist_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminSessionAttendee {
  const AdminSessionAttendee({
    required this.reservationId,
    required this.userId,
    required this.memberCode,
    required this.name,
    required this.memberPhone,
    required this.memberEmail,
    required this.status,
    required this.waitlistOrder,
    required this.createdAt,
  });

  final String reservationId;
  final String userId;
  final String memberCode;
  final String? name;
  final String? memberPhone;
  final String? memberEmail;
  final String status;
  final int? waitlistOrder;
  final DateTime createdAt;
}

class AdminCancelRequest {
  const AdminCancelRequest({
    required this.id,
    required this.studioId,
    required this.userId,
    required this.memberCode,
    required this.memberName,
    required this.memberPhone,
    required this.memberEmail,
    required this.classSessionId,
    required this.className,
    required this.category,
    required this.userPassId,
    required this.passName,
    required this.requestCancelReason,
    required this.requestedCancelAt,
    required this.responseComment,
    required this.processedAt,
    required this.processedAdminName,
    required this.startAt,
    required this.endAt,
    required this.status,
  });

  final String id;
  final String studioId;
  final String userId;
  final String memberCode;
  final String? memberName;
  final String? memberPhone;
  final String? memberEmail;
  final String classSessionId;
  final String className;
  final String category;
  final String userPassId;
  final String passName;
  final String? requestCancelReason;
  final DateTime? requestedCancelAt;
  final String? responseComment;
  final DateTime? processedAt;
  final String? processedAdminName;
  final DateTime startAt;
  final DateTime endAt;
  final String status;

  bool get isPending => status == 'cancel_requested';
  bool get isApproved => processedAt != null && status == 'cancelled';
  bool get isRejected => processedAt != null && status == 'studio_rejected';

  factory AdminCancelRequest.fromMap(Map<String, dynamic> map) {
    return AdminCancelRequest(
      id: map['id'] as String,
      studioId: map['studio_id'] as String,
      userId: map['user_id'] as String,
      memberCode: map['member_code'] as String? ?? '',
      memberName: map['member_name'] as String?,
      memberPhone: map['member_phone'] as String?,
      memberEmail: map['member_email'] as String?,
      classSessionId: map['class_session_id'] as String,
      className: map['class_name'] as String? ?? '',
      category: map['category'] as String? ?? '',
      userPassId: map['user_pass_id'] as String,
      passName: map['pass_name'] as String? ?? '',
      requestCancelReason: map['request_cancel_reason'] as String?,
      requestedCancelAt: _parseDate(map['requested_cancel_at']),
      responseComment: map['cancel_request_response_comment'] as String?,
      processedAt: _parseDate(map['cancel_request_processed_at']),
      processedAdminName: map['processed_admin_name'] as String?,
      startAt: DateTime.parse(map['start_at'] as String),
      endAt: DateTime.parse(map['end_at'] as String),
      status: map['status'] as String? ?? '',
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value.map((item) => item.toString()).toList(growable: false);
}

DateTime? _parseDate(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.parse(value as String);
}

String _timeOnly(String value) {
  return value.length >= 5 ? value.substring(0, 5) : value;
}
