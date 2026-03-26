import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../models/class_models.dart';
import '../../providers/calendar_controller.dart';
import '../../providers/reservations_controller.dart';
import 'common_widgets.dart';
import 'session_detail_sheet.dart';

class ReservationHistoryList extends StatelessWidget {
  const ReservationHistoryList({
    required this.bucket,
    required this.controller,
    super.key,
    this.month,
    this.userPassId,
    this.showPassBadge = true,
    this.emptyTitle,
    this.emptyDescription,
  });

  final ReservationBucket bucket;
  final ReservationsController controller;
  final DateTime? month;
  final String? userPassId;
  final bool showPassBadge;
  final String? emptyTitle;
  final String? emptyDescription;

  @override
  Widget build(BuildContext context) {
    final items = controller.itemsForBucket(
      bucket,
      userPassId: userPassId,
      month: month,
    );

    if (controller.error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ErrorSection(message: controller.error!, onRetry: controller.refresh),
        ],
      );
    }

    if (controller.isLoading) {
      return const LoadingSection();
    }

    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          EmptySection(
            title: emptyTitle ?? reservationBucketEmptyTitle(bucket),
            description:
                emptyDescription ?? reservationBucketEmptyDescription(bucket),
            icon: reservationBucketEmptyIcon(bucket),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _ReservationListContainer(
            children: [
              for (final item in items)
                _ReservationListItem(item: item, showPassBadge: showPassBadge),
            ],
          ),
        ],
      ),
    );
  }
}

String reservationBucketEmptyTitle(ReservationBucket bucket) {
  switch (bucket) {
    case ReservationBucket.upcoming:
      return '예정된 수업이 없습니다';
    case ReservationBucket.waitlist:
      return '대기 중인 수업이 없습니다';
    case ReservationBucket.completed:
      return '완료한 수업이 없습니다';
    case ReservationBucket.cancelled:
      return '취소된 수업이 없습니다';
  }
}

String reservationBucketEmptyDescription(ReservationBucket bucket) {
  switch (bucket) {
    case ReservationBucket.upcoming:
      return '새 수업을 예약하면 이 탭에서 바로 확인할 수 있습니다.';
    case ReservationBucket.waitlist:
      return '대기 신청한 수업이 생기면 이 탭에 표시됩니다.';
    case ReservationBucket.completed:
      return '수강 완료한 수업 내역이 쌓이면 이 탭에 나타납니다.';
    case ReservationBucket.cancelled:
      return '취소한 수업이나 스튜디오 처리 내역이 있으면 이 탭에 표시됩니다.';
  }
}

IconData reservationBucketEmptyIcon(ReservationBucket bucket) {
  switch (bucket) {
    case ReservationBucket.upcoming:
      return Icons.event_note_outlined;
    case ReservationBucket.waitlist:
      return Icons.hourglass_top_rounded;
    case ReservationBucket.completed:
      return Icons.check_circle_outline_rounded;
    case ReservationBucket.cancelled:
      return Icons.remove_circle_outline_rounded;
  }
}

class _ReservationListContainer extends StatelessWidget {
  const _ReservationListContainer({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const Divider(height: 1, thickness: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _ReservationListItem extends StatelessWidget {
  const _ReservationListItem({required this.item, required this.showPassBadge});

  final ReservationItem item;
  final bool showPassBadge;

  @override
  Widget build(BuildContext context) {
    final calendarController = context.watch<CalendarController>();
    final liveSession = calendarController.sessions
        .where((session) => session.id == item.classSessionId)
        .firstOrNull;
    final effectiveCanCancelDirectly =
        liveSession?.canCancelDirectly ?? item.canCancelDirectly;
    final effectiveCanRequestCancel =
        liveSession?.canRequestCancel ?? item.canRequestCancel;
    final effectiveIsCancelLocked =
        liveSession?.isCancelLocked ?? item.isCancelLocked;
    final statusStyle = _reservationStatusStyle(item.status);
    final isLockedReservation =
        item.status == 'reserved' &&
        (effectiveIsCancelLocked ||
            (!effectiveCanRequestCancel && !effectiveCanCancelDirectly));

    return InkWell(
      onTap: isLockedReservation
          ? null
          : () {
              showAppBottomSheet<void>(
                context: context,
                builder: (_) =>
                    SessionDetailSheet(session: _reservationToSession(item)),
              );
            },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        item.className,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.title,
                            ),
                      ),
                      if (showPassBadge && item.passName.trim().isNotEmpty)
                        _ReservationPassBadge(label: item.passName.trim()),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (item.status == 'studio_cancelled' ||
                    item.status == 'studio_rejected' ||
                    item.isApprovedCancel)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        if (item.status == 'studio_cancelled' ||
                            item.isApprovedCancel) {
                          showStudioCancelReasonDialog(
                            context,
                            reason: item.approvedCancelComment,
                            adminName: item.approvedCancelAdminName,
                            processedAt: item.approvedCancelAt,
                          );
                          return;
                        }
                        showStudioRejectReasonDialog(
                          context,
                          reason: item.cancelRequestResponseComment,
                          adminName: item.cancelRequestProcessedAdminName,
                          processedAt: item.cancelRequestProcessedAt,
                        );
                      },
                      child: StatusPill(
                        label: _reservationStatusLabel(item),
                        backgroundColor: statusStyle.backgroundColor,
                        foregroundColor: statusStyle.foregroundColor,
                      ),
                    ),
                  )
                else
                  StatusPill(
                    label: _reservationStatusLabel(item),
                    backgroundColor: statusStyle.backgroundColor,
                    foregroundColor: statusStyle.foregroundColor,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _ReservationMetaLine(
              scheduleText:
                  '${Formatters.monthDay(item.startAt)} · ${Formatters.time(item.startAt)}-${Formatters.time(item.endAt)}',
              instructorName: item.instructorName,
              instructorImageUrl: item.instructorImageUrl,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.status == 'studio_rejected'
                        ? '스튜디오에서 취소 요청을 거절했습니다. 상세에서 사유를 확인하세요'
                        : item.isApprovedCancel
                        ? '스튜디오에서 취소 요청을 승인했습니다. 상세에서 사유를 확인하세요'
                        : item.status == 'studio_cancelled'
                        ? '스튜디오에서 예약을 취소했습니다. 상세에서 사유를 확인하세요'
                        : item.status == 'cancel_requested'
                        ? '스튜디오에서 취소 요청을 검토 중입니다'
                        : isLockedReservation
                        ? '취소 정책 내 기간이라 스튜디오에 직접 문의해 주세요'
                        : effectiveCanRequestCancel
                        ? '취소 정책 내 기간이라 앱에서 취소 요청을 보낼 수 있습니다'
                        : effectiveCanCancelDirectly
                        ? '취소 정책 외 기간이라 앱에서 직접 취소할 수 있습니다'
                        : '상세에서 상태를 확인하세요',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!isLockedReservation) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.subtle,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationPassBadge extends StatelessWidget {
  const _ReservationPassBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.title,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReservationMetaLine extends StatelessWidget {
  const _ReservationMetaLine({
    required this.scheduleText,
    required this.instructorName,
    required this.instructorImageUrl,
  });

  final String scheduleText;
  final String? instructorName;
  final String? instructorImageUrl;

  @override
  Widget build(BuildContext context) {
    final normalizedInstructorName = (instructorName ?? '').trim();
    final metaStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.body);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(scheduleText, style: metaStyle),
        Text('|', style: metaStyle),
        if (normalizedInstructorName.isNotEmpty) ...[
          StudioAvatar(
            name: normalizedInstructorName,
            imageUrl: instructorImageUrl,
            size: 18,
            borderRadius: 999,
          ),
          Text(normalizedInstructorName, style: metaStyle),
        ] else
          Text('강사 정보 없음', style: metaStyle),
      ],
    );
  }
}

_ReservationStatusStyle _reservationStatusStyle(String status) {
  switch (status) {
    case 'reserved':
      return const _ReservationStatusStyle(
        backgroundColor: AppColors.infoBackground,
        foregroundColor: AppColors.infoForeground,
      );
    case 'waitlisted':
      return const _ReservationStatusStyle(
        backgroundColor: AppColors.waitlistBackground,
        foregroundColor: AppColors.waitlistForeground,
      );
    case 'completed':
      return const _ReservationStatusStyle(
        backgroundColor: AppColors.successBackground,
        foregroundColor: AppColors.successForeground,
      );
    case 'cancel_requested':
      return const _ReservationStatusStyle(
        backgroundColor: AppColors.highlightBackground,
        foregroundColor: AppColors.highlightForeground,
      );
    case 'cancelled':
    case 'studio_cancelled':
    case 'studio_rejected':
      return const _ReservationStatusStyle(
        backgroundColor: AppColors.neutralBackground,
        foregroundColor: AppColors.neutralForeground,
      );
    default:
      return const _ReservationStatusStyle(
        backgroundColor: AppColors.neutralBackground,
        foregroundColor: AppColors.neutralForeground,
      );
  }
}

String _reservationStatusLabel(ReservationItem item) {
  if (item.isApprovedCancel) {
    return '취소 요청 승인';
  }
  return Formatters.reservationStatus(item.status);
}

class _ReservationStatusStyle {
  const _ReservationStatusStyle({
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
}

ClassSessionItem _reservationToSession(ReservationItem item) {
  return ClassSessionItem(
    id: item.classSessionId,
    studioId: item.studioId,
    classTemplateId: item.classTemplateId,
    sessionDate: item.sessionDate,
    startAt: item.startAt,
    endAt: item.endAt,
    capacity: item.capacity,
    status: item.sessionStatus,
    className: item.className,
    category: item.category,
    description: item.description,
    instructorName: item.instructorName,
    instructorImageUrl: item.instructorImageUrl,
    spotsLeft: item.spotsLeft,
    waitlistCount: item.waitlistCount,
    myReservationId: item.id,
    myReservationStatus: item.status,
    canCancelDirectly: item.canCancelDirectly,
    canRequestCancel: item.canRequestCancel,
    isCancelLocked: item.isCancelLocked,
  );
}
