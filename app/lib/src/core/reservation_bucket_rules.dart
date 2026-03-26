bool isReservationUpcomingStatus(
  String? status,
  DateTime? startAt,
  DateTime now,
) {
  return (status == 'reserved' || status == 'studio_rejected') &&
      startAt != null &&
      startAt.isAfter(now);
}

bool isReservationWaitlistedStatus(String? status) {
  return status == 'waitlisted';
}

bool isReservationCompletedStatus(
  String? status,
  DateTime? startAt,
  DateTime now,
) {
  return status == 'completed' ||
      ((status == 'reserved' || status == 'studio_rejected') &&
          startAt != null &&
          !startAt.isAfter(now));
}

bool isReservationCancelledStatus(
  String? status, {
  DateTime? approvedCancelAt,
  bool includeUnapprovedCancelled = false,
}) {
  return status == 'cancel_requested' ||
      status == 'studio_cancelled' ||
      (status == 'cancelled' &&
          (includeUnapprovedCancelled || approvedCancelAt != null));
}
