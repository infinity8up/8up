class UserPassSummary {
  const UserPassSummary({
    required this.id,
    required this.studioId,
    required this.userId,
    required this.passProductId,
    required this.name,
    required this.totalCount,
    required this.validFrom,
    required this.validUntil,
    required this.paidAmount,
    required this.refundedAmount,
    required this.status,
    required this.plannedCount,
    required this.completedCount,
    required this.remainingCount,
    required this.holdPeriods,
    required this.allowedTemplateIds,
    required this.allowedTemplateNames,
  });

  final String id;
  final String studioId;
  final String userId;
  final String passProductId;
  final String name;
  final int totalCount;
  final DateTime validFrom;
  final DateTime validUntil;
  final double paidAmount;
  final double refundedAmount;
  final String status;
  final int plannedCount;
  final int completedCount;
  final int remainingCount;
  final List<UserPassHoldPeriod> holdPeriods;
  final List<String> allowedTemplateIds;
  final List<String> allowedTemplateNames;

  bool get isActive => status == 'active';
  bool get isExpired =>
      status == 'expired' || validUntil.isBefore(DateTime.now());
  bool get hasRemaining => remainingCount > 0 && isActive;

  bool isHeldOn(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return holdPeriods.any((period) => period.contains(normalized));
  }

  UserPassSummary copyWith({
    int? plannedCount,
    int? completedCount,
    int? remainingCount,
    List<String>? allowedTemplateNames,
  }) {
    return UserPassSummary(
      id: id,
      studioId: studioId,
      userId: userId,
      passProductId: passProductId,
      name: name,
      totalCount: totalCount,
      validFrom: validFrom,
      validUntil: validUntil,
      paidAmount: paidAmount,
      refundedAmount: refundedAmount,
      status: status,
      plannedCount: plannedCount ?? this.plannedCount,
      completedCount: completedCount ?? this.completedCount,
      remainingCount: remainingCount ?? this.remainingCount,
      holdPeriods: holdPeriods,
      allowedTemplateIds: allowedTemplateIds,
      allowedTemplateNames: allowedTemplateNames ?? this.allowedTemplateNames,
    );
  }

  factory UserPassSummary.fromMap(Map<String, dynamic> map) {
    return UserPassSummary(
      id: map['id'] as String,
      studioId: map['studio_id'] as String,
      userId: map['user_id'] as String,
      passProductId: map['pass_product_id'] as String,
      name: map['name_snapshot'] as String? ?? '',
      totalCount: (map['total_count'] as num?)?.toInt() ?? 0,
      validFrom: DateTime.parse(map['valid_from'] as String),
      validUntil: DateTime.parse(map['valid_until'] as String),
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
      refundedAmount: (map['refunded_amount'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'inactive',
      plannedCount: (map['planned_count'] as num?)?.toInt() ?? 0,
      completedCount: (map['completed_count'] as num?)?.toInt() ?? 0,
      remainingCount: (map['remaining_count'] as num?)?.toInt() ?? 0,
      holdPeriods: _holdPeriods(map['hold_periods']),
      allowedTemplateIds: _stringList(map['allowed_class_template_ids']),
      allowedTemplateNames: _stringList(map['allowed_class_template_names']),
    );
  }
}

class UserPassHoldPeriod {
  const UserPassHoldPeriod({required this.holdFrom, required this.holdUntil});

  final DateTime holdFrom;
  final DateTime holdUntil;

  bool contains(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(holdFrom) && !normalized.isAfter(holdUntil);
  }

  factory UserPassHoldPeriod.fromMap(Map<String, dynamic> map) {
    return UserPassHoldPeriod(
      holdFrom: DateTime.parse(map['hold_from'] as String),
      holdUntil: DateTime.parse(map['hold_until'] as String),
    );
  }
}

class PassUsageEntry {
  const PassUsageEntry({
    required this.id,
    required this.studioId,
    required this.userPassId,
    required this.reservationId,
    required this.entryType,
    required this.countDelta,
    required this.memo,
    required this.createdAt,
    required this.reservationStatus,
    required this.classSessionId,
    required this.sessionStartAt,
    required this.sessionEndAt,
    required this.className,
  });

  final String id;
  final String studioId;
  final String userPassId;
  final String? reservationId;
  final String entryType;
  final int countDelta;
  final String? memo;
  final DateTime createdAt;
  final String? reservationStatus;
  final String? classSessionId;
  final DateTime? sessionStartAt;
  final DateTime? sessionEndAt;
  final String? className;

  factory PassUsageEntry.fromMap(Map<String, dynamic> map) {
    return PassUsageEntry(
      id: map['id'] as String,
      studioId: map['studio_id'] as String,
      userPassId: map['user_pass_id'] as String,
      reservationId: map['reservation_id'] as String?,
      entryType: map['entry_type'] as String? ?? '',
      countDelta: (map['count_delta'] as num?)?.toInt() ?? 0,
      memo: map['memo'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      reservationStatus: map['reservation_status'] as String?,
      classSessionId: map['class_session_id'] as String?,
      sessionStartAt: _parseDate(map['session_start_at']),
      sessionEndAt: _parseDate(map['session_end_at']),
      className: map['class_name'] as String?,
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value.map((item) => item.toString()).toList(growable: false);
}

List<UserPassHoldPeriod> _holdPeriods(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map<UserPassHoldPeriod>(
        (item) => UserPassHoldPeriod.fromMap(
          item.map((key, mapValue) => MapEntry(key.toString(), mapValue)),
        ),
      )
      .toList(growable: false);
}

DateTime? _parseDate(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.parse(value as String);
}
