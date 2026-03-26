import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../models/pass_models.dart';
import '../../providers/reservations_controller.dart';
import 'common_widgets.dart';
import 'reservation_history_list.dart';

class PassDetailPage extends StatelessWidget {
  const PassDetailPage({required this.pass, super.key});

  final UserPassSummary pass;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReservationsController>();
    final upcomingCount = controller
        .itemsForBucket(ReservationBucket.upcoming, userPassId: pass.id)
        .length;
    final waitlistCount = controller
        .itemsForBucket(ReservationBucket.waitlist, userPassId: pass.id)
        .length;
    final completedCount = controller
        .itemsForBucket(ReservationBucket.completed, userPassId: pass.id)
        .length;
    final cancelledCount = controller
        .itemsForBucket(ReservationBucket.cancelled, userPassId: pass.id)
        .length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('수강권 상세'),
      ),
      body: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            _PassDetailHeader(pass: pass),
            ColoredBox(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TabBar(
                  padding: EdgeInsets.zero,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.title,
                  unselectedLabelColor: AppColors.title,
                  indicatorColor: AppColors.title,
                  dividerColor: AppColors.border,
                  dividerHeight: 1,
                  labelPadding: EdgeInsets.zero,
                  tabs: [
                    _PassHistoryTab(
                      label: '예정',
                      count: upcomingCount,
                      showDivider: true,
                    ),
                    _PassHistoryTab(
                      label: '대기',
                      count: waitlistCount,
                      showDivider: true,
                    ),
                    _PassHistoryTab(
                      label: '완료',
                      count: completedCount,
                      showDivider: true,
                    ),
                    _PassHistoryTab(label: '취소', count: cancelledCount),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ReservationHistoryList(
                    bucket: ReservationBucket.upcoming,
                    controller: controller,
                    userPassId: pass.id,
                    showPassBadge: false,
                    emptyTitle: '이 수강권으로 예정된 수업이 없습니다',
                    emptyDescription: '이 수강권으로 예약한 수업이 생기면 여기에 표시됩니다.',
                  ),
                  ReservationHistoryList(
                    bucket: ReservationBucket.waitlist,
                    controller: controller,
                    userPassId: pass.id,
                    showPassBadge: false,
                    emptyTitle: '이 수강권으로 대기 중인 수업이 없습니다',
                    emptyDescription: '이 수강권으로 대기 신청한 수업이 있으면 여기에 표시됩니다.',
                  ),
                  ReservationHistoryList(
                    bucket: ReservationBucket.completed,
                    controller: controller,
                    userPassId: pass.id,
                    showPassBadge: false,
                    emptyTitle: '이 수강권으로 완료한 수업이 없습니다',
                    emptyDescription: '이 수강권으로 수강 완료한 수업이 쌓이면 여기에 표시됩니다.',
                  ),
                  ReservationHistoryList(
                    bucket: ReservationBucket.cancelled,
                    controller: controller,
                    userPassId: pass.id,
                    showPassBadge: false,
                    emptyTitle: '이 수강권으로 취소된 수업이 없습니다',
                    emptyDescription: '이 수강권으로 예약했다가 취소된 수업이 있으면 여기에 표시됩니다.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassDetailHeader extends StatelessWidget {
  const _PassDetailHeader({required this.pass});

  final UserPassSummary pass;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 8,
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pass.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.title,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PassMetricBadge(
                        label: '총',
                        value: '${pass.totalCount}회',
                        backgroundColor: AppColors.surfaceAlt,
                        foregroundColor: AppColors.title,
                      ),
                      _PassMetricBadge(
                        label: '잔여',
                        value: '${pass.remainingCount}회',
                        backgroundColor: AppColors.infoBackground,
                        foregroundColor: AppColors.infoForeground,
                      ),
                      _PassMetricBadge(
                        label: '예정',
                        value: '${pass.plannedCount}회',
                        backgroundColor: AppColors.waitlistBackground,
                        foregroundColor: AppColors.waitlistForeground,
                      ),
                      _PassMetricBadge(
                        label: '완료',
                        value: '${pass.completedCount}회',
                        backgroundColor: AppColors.successBackground,
                        foregroundColor: AppColors.successForeground,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${Formatters.date(pass.validFrom)} ~ ${Formatters.date(pass.validUntil)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.body),
                  ),
                  if (pass.allowedTemplateNames.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: pass.allowedTemplateNames
                          .map((label) => _AllowedTemplateBadge(label: label))
                          .toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassHistoryTab extends StatelessWidget {
  const _PassHistoryTab({
    required this.label,
    required this.count,
    this.showDivider = false,
  });

  final String label;
  final int count;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 40,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.subtle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showDivider)
            Align(
              alignment: Alignment.centerRight,
              child: Container(width: 1, height: 14, color: AppColors.border),
            ),
        ],
      ),
    );
  }
}

class _AllowedTemplateBadge extends StatelessWidget {
  const _AllowedTemplateBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.body,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PassMetricBadge extends StatelessWidget {
  const _PassMetricBadge({
    required this.label,
    required this.value,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final String value;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
