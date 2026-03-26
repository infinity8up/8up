import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/error_text.dart';
import '../../core/formatters.dart';
import '../../models/class_models.dart';
import '../../models/pass_models.dart';
import '../../providers/calendar_controller.dart';
import '../../providers/passes_controller.dart';
import '../../providers/reservations_controller.dart';
import '../../repositories/session_repository.dart';
import 'common_widgets.dart';

const _cancelLockedMessage = '취소 정책 내 기간이라 스튜디오에 직접 문의해 주세요.';

class SessionDetailSheet extends StatefulWidget {
  const SessionDetailSheet({required this.session, super.key});

  final ClassSessionItem session;

  @override
  State<SessionDetailSheet> createState() => _SessionDetailSheetState();
}

class _SessionDetailSheetState extends State<SessionDetailSheet> {
  bool _submitting = false;
  String? _selectedPassId;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calendarController = context.watch<CalendarController>();
    final passesController = context.watch<PassesController>();
    final reservationsController = context.watch<ReservationsController>();
    final liveSession = calendarController.sessions
        .where((item) => item.id == widget.session.id)
        .firstOrNull;
    final session = liveSession ?? widget.session;
    final sessionDescription = (session.description ?? '').trim();
    final reservation = reservationsController.reservations
        .where(
          (item) =>
              item.id ==
              (session.myReservationId ?? widget.session.myReservationId),
        )
        .firstOrNull;
    final canCancelDirectly =
        liveSession?.canCancelDirectly ??
        reservation?.canCancelDirectly ??
        session.canCancelDirectly;
    final canRequestCancel =
        liveSession?.canRequestCancel ??
        reservation?.canRequestCancel ??
        session.canRequestCancel;
    final isCancelLocked =
        liveSession?.isCancelLocked ??
        reservation?.isCancelLocked ??
        session.isCancelLocked;
    final requiresWaitlist = session.requiresWaitlist;
    final isRebookableCancelled = reservation?.canRebookAfterCancel ?? false;
    final effectiveStatus = session.myReservationStatus ?? reservation?.status;
    final displayStatus = effectiveStatus ?? '';

    final eligiblePasses =
        passesController.passes
            .where((pass) {
              final inDateRange =
                  !pass.validFrom.isAfter(session.sessionDate) &&
                  !pass.validUntil.isBefore(session.sessionDate);
              return pass.hasRemaining &&
                  inDateRange &&
                  !pass.isHeldOn(session.sessionDate) &&
                  pass.allowedTemplateIds.contains(session.classTemplateId);
            })
            .toList(growable: false)
          ..sort((left, right) => left.validUntil.compareTo(right.validUntil));
    final canCreateReservation =
        (session.myReservationStatus == null || isRebookableCancelled) &&
        session.status == 'scheduled' &&
        !session.isStarted;
    final showDirectCancelSummary =
        reservation != null &&
        canCancelDirectly &&
        session.myReservationStatus == 'reserved';
    final centeredWidthFactor = MediaQuery.sizeOf(context).width >= 900
        ? 0.5
        : 1.0;

    _selectedPassId ??= passesController
        .defaultPassForTemplate(session.classTemplateId, session.sessionDate)
        ?.id;
    if (_selectedPassId != null &&
        !eligiblePasses.any((pass) => pass.id == _selectedPassId)) {
      _selectedPassId = eligiblePasses.firstOrNull?.id;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showDirectCancelSummary) ...[
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '취소할 수업',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.title,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: CloseButton(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    widthFactor: centeredWidthFactor,
                    child: _ReservedSessionSummaryCard(
                      className: session.className,
                      description: sessionDescription,
                      startAt: session.startAt,
                      endAt: session.endAt,
                      instructorName: session.instructorName,
                      instructorImageUrl: session.instructorImageUrl,
                      passName: reservation.passName,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.className,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.title,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const CloseButton(),
                  ],
                ),
                if (sessionDescription.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    sessionDescription,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.title,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
              if (effectiveStatus == null || isRebookableCancelled) ...[
                if (!canCreateReservation)
                  const EmptySection(
                    title: '지난 수업입니다',
                    description: '종료된 수업은 예약할 수 없지만 일정 기록은 계속 확인할 수 있습니다.',
                  )
                else if (eligiblePasses.isEmpty)
                  const EmptySection(
                    title: '사용 가능한 수강권이 없습니다',
                    description: '현재 스튜디오에 연결된 유효한 수강권이 있어야 예약할 수 있습니다.',
                  )
                else
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isRebookableCancelled) ...[
                          const InfoBadge(
                            icon: Icons.refresh_rounded,
                            label: '직접 취소한 수업이라 다시 예약할 수 있습니다.',
                          ),
                          const SizedBox(height: 14),
                        ],
                        Text(
                          '사용할 수강권',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.title,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            for (var i = 0; i < eligiblePasses.length; i++) ...[
                              _PassSelectionCard(
                                pass: eligiblePasses[i],
                                selected:
                                    eligiblePasses[i].id == _selectedPassId,
                                enabled: !_submitting,
                                onTap: () {
                                  setState(() {
                                    _selectedPassId = eligiblePasses[i].id;
                                  });
                                },
                              ),
                              if (i != eligiblePasses.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                        if (requiresWaitlist) ...[
                          const SizedBox(height: 14),
                          _WaitlistNoticeCard(
                            title: session.waitlistCount > 0
                                ? '현재 대기 ${session.waitlistCount}명'
                                : '정원이 가득 찼습니다',
                            message:
                                session.waitlistCount > 0 &&
                                    session.spotsLeft > 0
                                ? '잔여석이 ${session.spotsLeft}석 있어도 먼저 대기한 회원 뒤에 순서대로 등록됩니다.'
                                : session.waitlistCount > 0
                                ? '지금 신청하면 현재 대기 회원 뒤에 순서대로 등록됩니다.'
                                : '지금 신청하면 대기 순번으로 등록됩니다.',
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: requiresWaitlist
                              ? OutlinedButton(
                                  style: _outlinedActionButtonStyle(
                                    context,
                                    foregroundColor:
                                        AppColors.waitlistForeground,
                                  ),
                                  onPressed:
                                      _submitting || _selectedPassId == null
                                      ? null
                                      : () {
                                          _reserve(context);
                                        },
                                  child: const Text('대기'),
                                )
                              : FilledButton(
                                  style: _filledActionButtonStyle(context),
                                  onPressed:
                                      _submitting || _selectedPassId == null
                                      ? null
                                      : () {
                                          _reserve(context);
                                        },
                                  child: const Text('예약'),
                                ),
                        ),
                      ],
                    ),
                  ),
              ] else ...[
                if (!showDirectCancelSummary)
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '내 상태',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        _statusChip(displayStatus, reservation: reservation),
                        if (reservation != null) ...[
                          const SizedBox(height: 16),
                          Text('사용 수강권: ${reservation.passName}'),
                        ],
                      ],
                    ),
                  ),
                if (reservation != null &&
                    (reservation.requestCancelReason?.isNotEmpty == true ||
                        reservation.cancelRequestResponseComment?.isNotEmpty ==
                            true ||
                        reservation.approvedCancelComment?.isNotEmpty == true ||
                        effectiveStatus == 'cancel_requested' ||
                        effectiveStatus == 'studio_rejected' ||
                        (effectiveStatus == 'cancelled' &&
                            reservation.approvedCancelAt != null))) ...[
                  const SizedBox(height: 16),
                  _CancellationConversation(
                    reservation: reservation,
                    effectiveStatus: effectiveStatus,
                  ),
                ],
                const SizedBox(height: 16),
                if (canCancelDirectly)
                  Align(
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      widthFactor: showDirectCancelSummary
                          ? centeredWidthFactor
                          : 1.0,
                      child: session.isWaitlisted
                          ? OutlinedButton(
                              style: _outlinedActionButtonStyle(
                                context,
                                foregroundColor: AppColors.waitlistForeground,
                              ),
                              onPressed: _submitting
                                  ? null
                                  : () {
                                      _cancel(context);
                                    },
                              child: const Text('대기 취소'),
                            )
                          : FilledButton(
                              style: _filledActionButtonStyle(context),
                              onPressed: _submitting
                                  ? null
                                  : () {
                                      _cancel(context);
                                    },
                              child: const Text('예약 취소'),
                            ),
                    ),
                  ),
                if (canRequestCancel) ...[
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '스튜디오 취소 요청',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _reasonController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: '사유를 입력하면 스튜디오에서 검토합니다.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          style: _outlinedActionButtonStyle(
                            context,
                            foregroundColor: AppColors.errorForeground,
                          ),
                          onPressed: _submitting
                              ? null
                              : () {
                                  _requestCancel(context);
                                },
                          child: const Text('취소 요청'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isCancelLocked)
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '취소 안내',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _cancelLockedMessage,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.body, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          style: _outlinedActionButtonStyle(
                            context,
                            foregroundColor: AppColors.subtle,
                            borderColor: AppColors.border,
                          ),
                          onPressed: null,
                          child: const Text('직접 문의'),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status, {ReservationItem? reservation}) {
    final label = switch (status) {
      'cancelled' when reservation?.isApprovedCancel == true => '취소 요청 승인',
      _ => Formatters.reservationStatus(status),
    };
    final baseChip = switch (status) {
      'reserved' => const StatusPill(
        label: '예약 확정',
        backgroundColor: AppColors.successBackground,
        foregroundColor: AppColors.successForeground,
      ),
      'waitlisted' => const StatusPill(
        label: '대기',
        backgroundColor: AppColors.waitlistBackground,
        foregroundColor: AppColors.waitlistForeground,
      ),
      'cancel_requested' => const StatusPill(
        label: '취소 요청 검토 중',
        backgroundColor: AppColors.highlightBackground,
        foregroundColor: AppColors.highlightForeground,
      ),
      _ => StatusPill(
        label: label,
        backgroundColor: AppColors.neutralBackground,
        foregroundColor: AppColors.neutralForeground,
      ),
    };

    final canShowReason =
        reservation != null &&
        (status == 'studio_cancelled' ||
            status == 'studio_rejected' ||
            reservation.isApprovedCancel);
    if (!canShowReason) {
      return baseChip;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          if (status == 'studio_cancelled' || reservation.isApprovedCancel) {
            showStudioCancelReasonDialog(
              context,
              reason: reservation.approvedCancelComment,
              adminName: reservation.approvedCancelAdminName,
              processedAt: reservation.approvedCancelAt,
            );
            return;
          }
          showStudioRejectReasonDialog(
            context,
            reason: reservation.cancelRequestResponseComment,
            adminName: reservation.cancelRequestProcessedAdminName,
            processedAt: reservation.cancelRequestProcessedAt,
          );
        },
        child: baseChip,
      ),
    );
  }

  Future<void> _reserve(BuildContext context) async {
    final selectedPassId = _selectedPassId;
    if (selectedPassId == null) {
      return;
    }

    final calendarController = context.read<CalendarController>();
    final passesController = context.read<PassesController>();
    final reservationsController = context.read<ReservationsController>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _submitting = true;
    });

    try {
      final resultStatus = await context
          .read<SessionRepository>()
          .reserveSession(
            sessionId: widget.session.id,
            userPassId: selectedPassId,
          );
      await Future.wait([
        calendarController.refresh(),
        passesController.refresh(),
        reservationsController.refresh(),
      ]);
      if (!mounted) {
        return;
      }
      scaffoldMessenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              resultStatus == 'waitlisted' ? '대기 신청이 완료되었습니다.' : '예약이 완료되었습니다.',
            ),
          ),
        );
      navigator.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      scaffoldMessenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(ErrorText.format(error)),
            backgroundColor: AppColors.errorForeground,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final reservationId = widget.session.myReservationId;
    if (reservationId == null) {
      return;
    }
    await _runAction(
      context,
      () => context.read<SessionRepository>().cancelReservation(reservationId),
      successMessage: widget.session.isWaitlisted
          ? '대기 신청이 취소되었습니다.'
          : '예약이 취소되었습니다.',
    );
  }

  Future<void> _requestCancel(BuildContext context) async {
    final reservationId = widget.session.myReservationId;
    if (reservationId == null) {
      return;
    }
    await _runAction(
      context,
      () => context.read<SessionRepository>().requestCancel(
        reservationId: reservationId,
        reason: _reasonController.text.trim(),
      ),
      successMessage: '취소 요청이 접수되었습니다.',
    );
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    final calendarController = context.read<CalendarController>();
    final passesController = context.read<PassesController>();
    final reservationsController = context.read<ReservationsController>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _submitting = true;
    });

    try {
      await action();
      await Future.wait([
        calendarController.refresh(),
        passesController.refresh(),
        reservationsController.refresh(),
      ]);
      if (!mounted) {
        return;
      }
      scaffoldMessenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(successMessage)));
      navigator.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      scaffoldMessenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(ErrorText.format(error)),
            backgroundColor: AppColors.errorForeground,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  ButtonStyle _filledActionButtonStyle(BuildContext context) {
    return FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      textStyle: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  ButtonStyle _outlinedActionButtonStyle(
    BuildContext context, {
    required Color foregroundColor,
    Color? borderColor,
  }) {
    return OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      textStyle: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      foregroundColor: foregroundColor,
      disabledForegroundColor: AppColors.subtle,
      side: BorderSide(color: borderColor ?? foregroundColor),
    );
  }
}

class _WaitlistNoticeCard extends StatelessWidget {
  const _WaitlistNoticeCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.waitlistBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.waitlistForeground),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            color: AppColors.waitlistForeground,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.waitlistForeground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.title,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservedSessionSummaryCard extends StatelessWidget {
  const _ReservedSessionSummaryCard({
    required this.className,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.instructorName,
    required this.instructorImageUrl,
    required this.passName,
  });

  final String className;
  final String description;
  final DateTime startAt;
  final DateTime endAt;
  final String? instructorName;
  final String? instructorImageUrl;
  final String passName;

  @override
  Widget build(BuildContext context) {
    final normalizedInstructorName = (instructorName ?? '').trim();

    return SurfaceCard(
      showBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            className,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.title,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.title,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '${Formatters.monthDay(startAt)} · ${Formatters.time(startAt)}-${Formatters.time(endAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.body,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (normalizedInstructorName.isNotEmpty) ...[
                StudioAvatar(
                  name: normalizedInstructorName,
                  imageUrl: instructorImageUrl,
                  size: 18,
                  borderRadius: 999,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    normalizedInstructorName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.body,
                      height: 1.45,
                    ),
                  ),
                ),
              ] else
                Expanded(
                  child: Text(
                    '강사 정보 없음',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.body,
                      height: 1.45,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '사용 수강권: $passName',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.title,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassSelectionCard extends StatelessWidget {
  const _PassSelectionCard({
    required this.pass,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final UserPassSummary pass;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pass.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.title,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _PassMetaText(
                      label: '시작일',
                      value: Formatters.date(pass.validFrom),
                    ),
                    _PassMetaText(
                      label: '만료일',
                      value: Formatters.date(pass.validUntil),
                    ),
                    _PassMetaText(
                      label: '잔여횟수',
                      value: '${pass.remainingCount}회',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 18,
            color: selected ? AppColors.primary : AppColors.subtle,
          ),
        ],
      ),
    );

    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}

class _PassMetaText extends StatelessWidget {
  const _PassMetaText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.title, height: 1.3),
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _CancellationConversation extends StatelessWidget {
  const _CancellationConversation({
    required this.reservation,
    required this.effectiveStatus,
  });

  final ReservationItem reservation;
  final String? effectiveStatus;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '취소 문의 기록',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (reservation.requestCancelReason?.isNotEmpty == true)
            _ConversationBubble(
              title: '회원 요청',
              subtitle: reservation.requestedCancelAt != null
                  ? Formatters.full(reservation.requestedCancelAt!)
                  : '접수 시각 없음',
              message: reservation.requestCancelReason!,
              backgroundColor: AppColors.surfaceAlt,
            ),
          if (reservation.requestCancelReason?.isNotEmpty == true &&
              ((reservation.cancelRequestResponseComment?.isNotEmpty == true ||
                      reservation.approvedCancelComment?.isNotEmpty == true) ||
                  effectiveStatus == 'cancel_requested' ||
                  effectiveStatus == 'studio_rejected' ||
                  (effectiveStatus == 'cancelled' &&
                      reservation.approvedCancelAt != null)))
            const SizedBox(height: 10),
          if ((reservation.cancelRequestResponseComment?.isNotEmpty == true) ||
              (reservation.approvedCancelComment?.isNotEmpty == true))
            _ConversationBubble(
              title:
                  reservation.cancelRequestProcessedAdminName?.isNotEmpty ==
                      true
                  ? '${reservation.cancelRequestProcessedAdminName!} 답변'
                  : reservation.approvedCancelAdminName?.isNotEmpty == true
                  ? '${reservation.approvedCancelAdminName!} 답변'
                  : '스튜디오 답변',
              subtitle: reservation.cancelRequestProcessedAt != null
                  ? Formatters.full(reservation.cancelRequestProcessedAt!)
                  : reservation.approvedCancelAt != null
                  ? Formatters.full(reservation.approvedCancelAt!)
                  : '처리 시각 없음',
              message:
                  reservation.cancelRequestResponseComment ??
                  reservation.approvedCancelComment!,
              backgroundColor: AppColors.infoBackground,
            )
          else if (effectiveStatus == 'studio_rejected')
            _ConversationBubble(
              title: '취소 요청 거절',
              subtitle: reservation.cancelRequestProcessedAt != null
                  ? Formatters.full(reservation.cancelRequestProcessedAt!)
                  : '처리 시각 없음',
              message: '스튜디오에서 취소 요청을 거절해 예약이 유지됩니다.',
              backgroundColor: AppColors.infoBackground,
            )
          else if (effectiveStatus == 'cancelled' &&
              reservation.approvedCancelAt != null)
            _ConversationBubble(
              title: '취소 요청 승인',
              subtitle: reservation.approvedCancelAt != null
                  ? Formatters.full(reservation.approvedCancelAt!)
                  : '처리 시각 없음',
              message: '스튜디오에서 취소 요청을 승인해 예약이 취소되었습니다.',
              backgroundColor: AppColors.infoBackground,
            )
          else if (effectiveStatus == 'cancel_requested')
            _ConversationBubble(
              title: '스튜디오 확인 중',
              subtitle: '승인 대기',
              message: '스튜디오에서 취소 요청을 검토 중입니다.',
              backgroundColor: AppColors.surfaceAlt,
            ),
        ],
      ),
    );
  }
}

class _ConversationBubble extends StatelessWidget {
  const _ConversationBubble({
    required this.title,
    required this.subtitle,
    required this.message,
    required this.backgroundColor,
  });

  final String title;
  final String subtitle;
  final String message;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.subtle),
          ),
          const SizedBox(height: 10),
          Text(message),
        ],
      ),
    );
  }
}
