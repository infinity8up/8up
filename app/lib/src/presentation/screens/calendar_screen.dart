import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/app_colors.dart';
import '../../core/error_text.dart';
import '../../core/formatters.dart';
import '../../models/class_models.dart';
import '../../providers/calendar_controller.dart';
import '../../providers/passes_controller.dart';
import '../../providers/reservations_controller.dart';
import '../../repositories/session_repository.dart';
import '../widgets/common_widgets.dart';
import '../widgets/session_detail_sheet.dart';

const _cancelLockedMessage = '취소 정책 불가 기간입니다. 스튜디오에 직접 문의하세요.';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = now;
    _selectedDay = now;
  }

  @override
  Widget build(BuildContext context) {
    final calendar = context.watch<CalendarController>();
    final passes = context.watch<PassesController>();
    final reservations = context.watch<ReservationsController>();
    final reservationsById = {
      for (final reservation in reservations.reservations) reservation.id: reservation,
    };
    final sessions = calendar.sessionsForDay(_selectedDay, passes.passes);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([calendar.refresh(), passes.refresh()]);
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const AppTopSection(child: AppTabHeader()),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '수업 캘린더',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.title,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SegmentedButton<CalendarFormat>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: WidgetStatePropertyAll(Size(0, 30)),
                        padding: WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        ),
                      ),
                      segments: const [
                        ButtonSegment<CalendarFormat>(
                          value: CalendarFormat.twoWeeks,
                          label: Text('2주'),
                        ),
                        ButtonSegment<CalendarFormat>(
                          value: CalendarFormat.month,
                          label: Text('월'),
                        ),
                      ],
                      selected: {_calendarFormat},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        final nextFormat = selection.first;
                        setState(() {
                          _calendarFormat = nextFormat;
                          if (nextFormat == CalendarFormat.twoWeeks) {
                            final now = DateTime.now();
                            _focusedDay = now;
                            _selectedDay = now;
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SurfaceCard(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: TableCalendar<ClassSessionItem>(
                    firstDay: calendar.rangeStart,
                    lastDay: calendar.rangeEnd,
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    startingDayOfWeek: StartingDayOfWeek.sunday,
                    rowHeight: 62,
                    daysOfWeekHeight: 24,
                    locale: 'ko_KR',
                    selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                    availableCalendarFormats: const {
                      CalendarFormat.twoWeeks: '2weeks',
                      CalendarFormat.month: 'month',
                    },
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      headerPadding: const EdgeInsets.only(bottom: 8),
                      leftChevronVisible:
                          _calendarFormat == CalendarFormat.month,
                      rightChevronVisible:
                          _calendarFormat == CalendarFormat.month,
                      titleTextStyle: Theme.of(context).textTheme.titleMedium!
                          .copyWith(
                            color: AppColors.title,
                            fontWeight: FontWeight.w700,
                          ),
                      leftChevronIcon: const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.title,
                      ),
                      rightChevronIcon: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.title,
                      ),
                      titleTextFormatter: (date, locale) =>
                          Formatters.yearMonth(date),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: Theme.of(context).textTheme.labelMedium!
                          .copyWith(color: AppColors.subtle),
                      weekendStyle: Theme.of(context).textTheme.labelMedium!
                          .copyWith(color: AppColors.subtle),
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      markersMaxCount: 1,
                      canMarkersOverflow: false,
                      defaultDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      weekendDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      outsideDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      holidayDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      withinRangeDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      rangeStartDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      rangeEndDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      todayDecoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      selectedTextStyle: const TextStyle(
                        color: AppColors.title,
                      ),
                      todayTextStyle: const TextStyle(color: AppColors.title),
                    ),
                    calendarBuilders: CalendarBuilders<ClassSessionItem>(
                      defaultBuilder: (context, day, focusedDay) =>
                          _CalendarDayCell(
                            day: day,
                            isToday: _isToday(day),
                            isPast: _isPastCalendarDay(day),
                            isSelected: isSameDay(day, _selectedDay),
                          ),
                      todayBuilder: (context, day, focusedDay) =>
                          _CalendarDayCell(
                            day: day,
                            isToday: true,
                            isPast: false,
                            isSelected: isSameDay(day, _selectedDay),
                          ),
                      selectedBuilder: (context, day, focusedDay) =>
                          _CalendarDayCell(
                            day: day,
                            isToday: _isToday(day),
                            isPast: _isPastCalendarDay(day),
                            isSelected: true,
                          ),
                      markerBuilder: (context, day, events) {
                        final kinds = _markerKinds(events, reservationsById);
                        if (kinds.isEmpty) {
                          return null;
                        }

                        return Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: _isToday(day) ? 42 : 36,
                            ),
                            child: _CalendarMarkerStack(
                              kinds: kinds,
                              isSelected: isSameDay(day, _selectedDay),
                            ),
                          ),
                        );
                      },
                    ),
                    eventLoader: (day) =>
                        calendar.sessionsForDay(day, passes.passes),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _CalendarLegend(
                        color: AppColors.waitlistForeground,
                        label: '대기',
                      ),
                      _CalendarLegend(
                        color: AppColors.calendarReserved,
                        label: '예약됨',
                      ),
                      _CalendarLegend(
                        color: AppColors.calendarOpen,
                        label: '예약 가능',
                      ),
                      _CalendarLegend(
                        color: AppColors.calendarCancelled,
                        label: '취소됨',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  Formatters.monthDay(_selectedDay),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.title,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (calendar.error != null)
                  ErrorSection(
                    message: calendar.error!,
                    onRetry: calendar.refresh,
                  )
                else if (calendar.isLoading)
                  const LoadingSection()
                else
                  ..._buildSectionedSessions(
                    context: context,
                    sessions: sessions,
                    passesController: passes,
                    reservationsById: reservationsById,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_CalendarMarkerKind> _markerKinds(
    List<ClassSessionItem> sessions,
    Map<String, ReservationItem> reservationsById,
  ) {
    final ordered = sessions.toList(growable: false)
      ..sort((left, right) => left.startAt.compareTo(right.startAt));
    return ordered
        .map(
          (session) => _markerKindForSession(session, reservationsById),
        )
        .toList(growable: false);
  }

  List<Widget> _buildSectionedSessions({
    required BuildContext context,
    required List<ClassSessionItem> sessions,
    required PassesController passesController,
    required Map<String, ReservationItem> reservationsById,
  }) {
    if (sessions.isEmpty) {
      return const [
        _CalendarEmptySection(
          title: '표시할 수업이 없습니다',
          description: '선택한 날짜에 열린 수업이나 예약 내역이 있으면 여기에 표시됩니다.',
          icon: Icons.calendar_today_outlined,
        ),
      ];
    }

    final reservedSessions = sessions
        .where(
          (session) =>
              session.myReservationStatus != null &&
              !session.isWaitlisted &&
              !session.isCancelled &&
              !_isRebookableCancelledSession(session, reservationsById),
        )
        .toList(growable: false);
    final waitlistedSessions = sessions
        .where((session) => session.isWaitlisted)
        .toList(growable: false);
    final openSessions = sessions
        .where(
          (session) =>
              (session.myReservationStatus == null ||
                  _isRebookableCancelledSession(session, reservationsById)) &&
              (!session.isCancelled ||
                  _isRebookableCancelledSession(session, reservationsById)),
        )
        .toList(growable: false);
    final cancelledSessions = sessions
        .where(
          (session) =>
              session.isCancelled &&
              !_isRebookableCancelledSession(session, reservationsById),
        )
        .toList(growable: false);

    return [
      _CalendarSectionHeader(
        color: AppColors.calendarReserved,
        label: '예약 완료',
        count: reservedSessions.length,
      ),
      const SizedBox(height: 12),
      if (reservedSessions.isEmpty)
        const _CalendarEmptySection(
          title: '예약된 수업이 없습니다',
          description: '예약을 완료한 수업이 생기면 이 영역에서 확인할 수 있습니다.',
          icon: Icons.event_available_outlined,
        )
      else
        ..._buildSessionCards(
          reservedSessions,
          passesController,
          reservationsById,
        ),
      if (waitlistedSessions.isNotEmpty) ...[
        const SizedBox(height: 24),
        _CalendarSectionHeader(
          color: AppColors.waitlistForeground,
          label: '대기 중',
          count: waitlistedSessions.length,
        ),
        const SizedBox(height: 12),
        ..._buildSessionCards(
          waitlistedSessions,
          passesController,
          reservationsById,
        ),
      ],
      if (openSessions.isNotEmpty) ...[
        const SizedBox(height: 24),
        _CalendarSectionHeader(
          color: AppColors.calendarOpen,
          label: '신청 가능',
          count: openSessions.length,
        ),
        const SizedBox(height: 12),
        ..._buildSessionCards(openSessions, passesController, reservationsById),
      ],
      if (cancelledSessions.isNotEmpty) ...[
        const SizedBox(height: 24),
        _CalendarSectionHeader(
          color: AppColors.calendarCancelled,
          label: '예약 취소',
          count: cancelledSessions.length,
        ),
        const SizedBox(height: 12),
        ..._buildSessionCards(
          cancelledSessions,
          passesController,
          reservationsById,
        ),
      ],
    ];
  }

  List<Widget> _buildSessionCards(
    List<ClassSessionItem> sessions,
    PassesController passesController,
    Map<String, ReservationItem> reservationsById,
  ) {
    return [
      _CalendarSessionListContainer(
        children: [
          for (final session in sessions)
            _SessionCard(
              session: session,
              isPast: _isPastSession(session),
              action: _sessionActionButton(
                session: session,
                passesController: passesController,
                reservationsById: reservationsById,
              ),
            ),
        ],
      ),
    ];
  }

  _CalendarMarkerKind _markerKindForSession(
    ClassSessionItem session,
    Map<String, ReservationItem> reservationsById,
  ) {
    if (_isRebookableCancelledSession(session, reservationsById)) {
      return session.requiresWaitlist
          ? _CalendarMarkerKind.waitlisted
          : _CalendarMarkerKind.open;
    }
    if (session.isWaitlisted) {
      return _CalendarMarkerKind.waitlisted;
    }
    if (session.isCancelRequested) {
      return _CalendarMarkerKind.reserved;
    }
    if (session.isCancelled) {
      return _CalendarMarkerKind.cancelled;
    }
    if (session.myReservationStatus != null) {
      return _CalendarMarkerKind.reserved;
    }
    if (session.requiresWaitlist) {
      return _CalendarMarkerKind.waitlisted;
    }
    return _CalendarMarkerKind.open;
  }

  Widget _sessionBadge(ClassSessionItem session) {
    if (session.myReservationStatus == 'studio_cancelled') {
      return const StatusPill(
        label: '예약 취소',
        backgroundColor: AppColors.neutralBackground,
        foregroundColor: AppColors.neutralForeground,
      );
    }
    if (session.isStudioRejected) {
      return const StatusPill(
        label: '예약 유지',
        backgroundColor: AppColors.neutralBackground,
        foregroundColor: AppColors.neutralForeground,
      );
    }
    if (session.isCancelRequested) {
      return const StatusPill(
        label: '취소 요청 검토 중',
        backgroundColor: AppColors.highlightBackground,
        foregroundColor: AppColors.highlightForeground,
      );
    }
    if (session.isCancelled) {
      return const StatusPill(
        label: '취소',
        backgroundColor: AppColors.neutralBackground,
        foregroundColor: AppColors.neutralForeground,
      );
    }
    if (session.isWaitlisted) {
      return const StatusPill(
        label: '대기',
        backgroundColor: AppColors.waitlistBackground,
        foregroundColor: AppColors.waitlistForeground,
      );
    }
    if (session.isReserved) {
      return const StatusPill(
        label: '예약',
        backgroundColor: AppColors.successBackground,
        foregroundColor: AppColors.successForeground,
      );
    }
    if (session.isCompleted) {
      return const StatusPill(
        label: '수강 완료',
        backgroundColor: AppColors.successBackground,
        foregroundColor: AppColors.successForeground,
      );
    }
    if (session.isStarted) {
      return const StatusPill(
        label: '수업 열림',
        backgroundColor: AppColors.infoBackground,
        foregroundColor: AppColors.infoForeground,
      );
    }
    if (session.requiresWaitlist) {
      return const StatusPill(
        label: '대기',
        backgroundColor: AppColors.waitlistBackground,
        foregroundColor: AppColors.waitlistForeground,
      );
    }
    return const StatusPill(
      label: '예약 가능',
      backgroundColor: AppColors.infoBackground,
      foregroundColor: AppColors.infoForeground,
    );
  }

  Widget _sessionActionButton({
    required ClassSessionItem session,
    required PassesController passesController,
    required Map<String, ReservationItem> reservationsById,
  }) {
    final isRebookableCancelled = _isRebookableCancelledSession(
      session,
      reservationsById,
    );
    final canReserve =
        (session.myReservationStatus == null ||
            isRebookableCancelled) &&
        session.status == 'scheduled' &&
        !session.isStarted &&
        passesController
            .eligiblePassesForTemplate(
              session.classTemplateId,
              onDate: session.sessionDate,
            )
            .isNotEmpty;
    final canCancel =
        session.myReservationId != null &&
        (session.isWaitlisted ||
            session.canCancelDirectly ||
            session.canRequestCancel);
    final isCancelLocked =
        session.myReservationId != null && session.isCancelLocked;

    if (canReserve) {
      if (session.canReserveImmediately) {
        return FilledButton(
          style: _filledCalendarActionButtonStyle(context),
          onPressed: () => _openSessionSheet(session),
          child: const Text('예약'),
        );
      }

      return OutlinedButton(
        style: _outlinedCalendarActionButtonStyle(
          context,
          foregroundColor: AppColors.waitlistForeground,
        ),
        onPressed: () => _openSessionSheet(session),
        child: const Text('대기'),
      );
    }

    if (canCancel) {
      if (session.isWaitlisted) {
        return OutlinedButton(
          style: _outlinedCalendarActionButtonStyle(
            context,
            foregroundColor: AppColors.waitlistForeground,
          ),
          onPressed: () => _handleCancelAction(session),
          child: const Text('대기 취소'),
        );
      }

      if (session.canRequestCancel) {
        return OutlinedButton(
          style: _outlinedCalendarActionButtonStyle(
            context,
            foregroundColor: AppColors.errorForeground,
            borderColor: AppColors.errorForeground,
          ),
          onPressed: () => _handleCancelAction(session),
          child: const Text('취소 요청'),
        );
      }

      return FilledButton(
        style: _filledCalendarActionButtonStyle(context),
        onPressed: () => _handleCancelAction(session),
        child: const Text('취소'),
      );
    }

    if (isCancelLocked) {
      return OutlinedButton(
        style: _outlinedCalendarActionButtonStyle(
          context,
          foregroundColor: AppColors.subtle,
          borderColor: AppColors.border,
        ),
        onPressed: null,
        child: const Text('직접 문의'),
      );
    }

    if (session.isCancelled && !isRebookableCancelled) {
      return OutlinedButton(
        style: _outlinedCalendarActionButtonStyle(
          context,
          foregroundColor: AppColors.subtle,
          borderColor: AppColors.border,
        ),
        onPressed: null,
        child: const Text('취소'),
      );
    }

    return _sessionBadge(session);
  }

  bool _isRebookableCancelledSession(
    ClassSessionItem session,
    Map<String, ReservationItem> reservationsById,
  ) {
    if (session.myReservationStatus != 'cancelled' ||
        session.status != 'scheduled' ||
        session.isStarted) {
      return false;
    }
    final reservationId = session.myReservationId;
    if (reservationId == null) {
      return false;
    }
    return reservationsById[reservationId]?.canRebookAfterCancel ?? false;
  }

  ButtonStyle _filledCalendarActionButtonStyle(BuildContext context) {
    return FilledButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size(0, 34),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      textStyle: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  ButtonStyle _outlinedCalendarActionButtonStyle(
    BuildContext context, {
    required Color foregroundColor,
    Color? borderColor,
  }) {
    return OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size(0, 34),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      textStyle: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      foregroundColor: foregroundColor,
      disabledForegroundColor: AppColors.subtle,
      side: BorderSide(color: borderColor ?? foregroundColor),
    );
  }

  Future<void> _openSessionSheet(ClassSessionItem session) async {
    await showAppBottomSheet<void>(
      context: context,
      builder: (_) => SessionDetailSheet(session: session),
    );
  }

  Future<void> _handleCancelAction(ClassSessionItem session) async {
    if (session.myReservationId == null) {
      return;
    }

    if (session.isWaitlisted || session.canCancelDirectly) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _CancelConfirmDialog(
          title: session.isWaitlisted ? '대기 취소' : '예약 취소',
          description: session.isWaitlisted
              ? '대기 신청을 취소하시겠습니까?'
              : '정말 취소하시겠습니까?',
          confirmLabel: session.isWaitlisted ? '대기 취소' : '취소하기',
        ),
      );
      if (confirmed != true) {
        return;
      }
      if (!mounted) {
        return;
      }

      await _runSessionAction(
        () => context.read<SessionRepository>().cancelReservation(
          session.myReservationId!,
        ),
        successMessage: session.isWaitlisted
            ? '대기 신청이 취소되었습니다.'
            : '예약이 취소되었습니다.',
      );
      return;
    }

    if (!session.canRequestCancel) {
      if (session.isCancelLocked && mounted) {
        showAppSnackBar(context, _cancelLockedMessage, isError: true);
      }
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _CancelRequestDialog(),
    );
    if (reason == null || reason.trim().isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }

    await _runSessionAction(
      () => context.read<SessionRepository>().requestCancel(
        reservationId: session.myReservationId!,
        reason: reason.trim(),
      ),
      successMessage: '취소 요청이 접수되었습니다.',
    );
  }

  Future<void> _runSessionAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final calendarController = context.read<CalendarController>();
    final passesController = context.read<PassesController>();
    final reservationsController = context.read<ReservationsController>();

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
      showAppSnackBarWithMessenger(messenger, successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(
        messenger,
        ErrorText.format(error),
        isError: true,
      );
    }
  }

  bool _isToday(DateTime day) => isSameDay(day, DateTime.now());

  bool _isPastCalendarDay(DateTime day) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return normalizedDay.isBefore(normalizedToday);
  }

  bool _isPastSession(ClassSessionItem session) =>
      session.startAt.isBefore(DateTime.now());
}

enum _CalendarMarkerKind {
  open(AppColors.calendarOpen),
  waitlisted(AppColors.waitlistForeground),
  reserved(AppColors.calendarReserved),
  cancelled(AppColors.calendarCancelled);

  const _CalendarMarkerKind(this.color);

  final Color color;
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.subtle),
        ),
      ],
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isToday,
    required this.isPast,
    required this.isSelected,
  });

  final DateTime day;
  final bool isToday;
  final bool isPast;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected ? AppColors.onPrimary : AppColors.title;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary
            : (isPast
                  ? AppColors.surfaceMuted.withValues(alpha: 0.84)
                  : Colors.transparent),
        borderRadius: BorderRadius.circular(16),
        border: !isSelected && isToday
            ? Border.all(color: AppColors.todayBadgeForeground, width: 1)
            : null,
      ),
      child: Stack(
        children: [
          if (isToday)
            Positioned(
              top: 5,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.18)
                        : AppColors.todayBadgeBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '오늘',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? AppColors.onPrimary
                          : AppColors.todayBadgeForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: isToday ? 24 : 16),
              child: Text(
                '${day.day}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarMarkerStack extends StatelessWidget {
  const _CalendarMarkerStack({required this.kinds, required this.isSelected});

  final List<_CalendarMarkerKind> kinds;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final visibleKinds = kinds.take(6).toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var start = 0; start < visibleKinds.length; start += 2) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (
                var index = start;
                index < start + 2 && index < visibleKinds.length;
                index++
              ) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.92)
                        : visibleKinds[index].color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                if (index < start + 1 && index + 1 < visibleKinds.length)
                  const SizedBox(width: 3),
              ],
            ],
          ),
          if (start + 2 < visibleKinds.length) const SizedBox(height: 2),
        ],
      ],
    );
  }
}

class _CalendarSectionHeader extends StatelessWidget {
  const _CalendarSectionHeader({
    required this.color,
    required this.label,
    required this.count,
  });

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Text(
          '$count개',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.subtle),
        ),
      ],
    );
  }
}

class _CalendarEmptySection extends StatelessWidget {
  const _CalendarEmptySection({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.subtle),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.body),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.isPast,
    required this.action,
  });

  final ClassSessionItem session;
  final bool isPast;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final description = (session.description ?? '').trim();
    final timeRange =
        '${Formatters.time(session.startAt)}-${Formatters.time(session.endAt)}';
    final normalizedInstructorName = (session.instructorName ?? '').trim();
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: AppColors.title,
      fontWeight: FontWeight.w700,
    );

    return Container(
      color: isPast
          ? AppColors.surfaceMuted.withValues(alpha: 0.72)
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.className,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                      ),
                      if (normalizedInstructorName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: _SessionInstructorLine(
                            name: normalizedInstructorName,
                            imageUrl: session.instructorImageUrl,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                action,
              ],
            ),
            const SizedBox(height: 4),
            _SessionMetaLine(
              timeRange: timeRange,
              capacity: session.capacity,
              spotsLeft: session.spotsLeft,
              waitlistCount: session.waitlistCount,
              isWaitlisted: session.isWaitlisted,
              requiresWaitlist: session.requiresWaitlist,
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.body),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SessionMetaLine extends StatelessWidget {
  const _SessionMetaLine({
    required this.timeRange,
    required this.capacity,
    required this.spotsLeft,
    required this.waitlistCount,
    required this.isWaitlisted,
    required this.requiresWaitlist,
  });

  final String timeRange;
  final int capacity;
  final int spotsLeft;
  final int waitlistCount;
  final bool isWaitlisted;
  final bool requiresWaitlist;

  @override
  Widget build(BuildContext context) {
    final seatSummary = isWaitlisted
        ? (waitlistCount > 0 ? '대기 $waitlistCount명 · 신청 완료' : '대기 신청 완료')
        : waitlistCount > 0 && spotsLeft > 0
        ? '대기 $waitlistCount명 · 잔여 $spotsLeft석'
        : waitlistCount > 0
        ? '정원 마감 · 대기 $waitlistCount명'
        : spotsLeft > 0
        ? '총 $capacity석 · 잔여 $spotsLeft석'
        : '정원 마감 · 대기 가능';
    final metaStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.body);
    final seatStyle = metaStyle?.copyWith(
      color: requiresWaitlist || isWaitlisted
          ? AppColors.waitlistForeground
          : AppColors.body,
      fontWeight: requiresWaitlist || isWaitlisted
          ? FontWeight.w800
          : FontWeight.w600,
    );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(timeRange, style: metaStyle),
        Text('|', style: metaStyle),
        Text(seatSummary, style: seatStyle),
      ],
    );
  }
}

class _SessionInstructorLine extends StatelessWidget {
  const _SessionInstructorLine({required this.name, required this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StudioAvatar(
          name: name,
          imageUrl: imageUrl,
          size: 16,
          borderRadius: 999,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarSessionListContainer extends StatelessWidget {
  const _CalendarSessionListContainer({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.border,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelRequestDialog extends StatefulWidget {
  const _CancelRequestDialog();

  @override
  State<_CancelRequestDialog> createState() => _CancelRequestDialogState();
}

class _CancelRequestDialogState extends State<_CancelRequestDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ActionDialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '취소 요청 보내기',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.title,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '취소 사유를 입력하면 스튜디오에서 내용을 확인합니다.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.body),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '취소 사유를 입력하세요.'),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final reason = _reasonController.text.trim();
                    if (reason.isEmpty) {
                      return;
                    }
                    Navigator.of(context).pop(reason);
                  },
                  child: const Text('취소 요청 보내기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancelConfirmDialog extends StatelessWidget {
  const _CancelConfirmDialog({
    required this.title,
    required this.description,
    required this.confirmLabel,
  });

  final String title;
  final String description;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return _ActionDialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.title,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.body),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('닫기'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionDialogShell extends StatelessWidget {
  const _ActionDialogShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SurfaceCard(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: child,
        ),
      ),
    );
  }
}
