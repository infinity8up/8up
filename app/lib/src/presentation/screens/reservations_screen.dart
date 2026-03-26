import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../providers/reservations_controller.dart';
import '../widgets/common_widgets.dart';
import '../widgets/reservation_history_list.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  DateTime? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReservationsController>();
    final availableMonths = controller.availableMonths();
    final selectedMonth = _resolveSelectedMonth(availableMonths);
    final upcomingCount = controller
        .itemsForBucket(ReservationBucket.upcoming, month: selectedMonth)
        .length;
    final waitlistCount = controller
        .itemsForBucket(ReservationBucket.waitlist, month: selectedMonth)
        .length;
    final completedCount = controller
        .itemsForBucket(ReservationBucket.completed, month: selectedMonth)
        .length;
    final cancelledCount = controller
        .itemsForBucket(ReservationBucket.cancelled, month: selectedMonth)
        .length;

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const AppTopSection(child: AppTabHeader()),
          Expanded(
            child: Column(
              children: [
                ColoredBox(
                  color: AppColors.surface,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                        child: Row(
                          children: [
                            const Spacer(),
                            _ReservationMonthFilterButton(
                              selectedMonth: selectedMonth,
                              availableMonths: availableMonths,
                              onSelected: (month) {
                                setState(() {
                                  _selectedMonth = month;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
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
                            _ReservationTab(
                              label: '예정',
                              count: upcomingCount,
                              showDivider: true,
                            ),
                            _ReservationTab(
                              label: '대기',
                              count: waitlistCount,
                              showDivider: true,
                            ),
                            _ReservationTab(
                              label: '완료',
                              count: completedCount,
                              showDivider: true,
                            ),
                            _ReservationTab(label: '취소', count: cancelledCount),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ReservationHistoryList(
                        bucket: ReservationBucket.upcoming,
                        controller: controller,
                        month: selectedMonth,
                      ),
                      ReservationHistoryList(
                        bucket: ReservationBucket.waitlist,
                        controller: controller,
                        month: selectedMonth,
                      ),
                      ReservationHistoryList(
                        bucket: ReservationBucket.completed,
                        controller: controller,
                        month: selectedMonth,
                      ),
                      ReservationHistoryList(
                        bucket: ReservationBucket.cancelled,
                        controller: controller,
                        month: selectedMonth,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _resolveSelectedMonth(List<DateTime> availableMonths) {
    final selectedMonth = _selectedMonth;
    if (selectedMonth == null) {
      return null;
    }

    for (final month in availableMonths) {
      if (month.year == selectedMonth.year &&
          month.month == selectedMonth.month) {
        return month;
      }
    }
    return null;
  }
}

class _ReservationMonthFilterButton extends StatelessWidget {
  const _ReservationMonthFilterButton({
    required this.selectedMonth,
    required this.availableMonths,
    required this.onSelected,
  });

  final DateTime? selectedMonth;
  final List<DateTime> availableMonths;
  final ValueChanged<DateTime?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DateTime?>(
      tooltip: '월별 필터',
      initialValue: selectedMonth,
      onSelected: onSelected,
      itemBuilder: (context) {
        return [
          const PopupMenuItem<DateTime?>(value: null, child: Text('전체')),
          ...availableMonths.map(
            (month) => PopupMenuItem<DateTime?>(
              value: month,
              child: Text(Formatters.yearMonth(month)),
            ),
          ),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              selectedMonth == null
                  ? '전체 월'
                  : Formatters.yearMonth(selectedMonth!),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: AppColors.subtle,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationTab extends StatelessWidget {
  const _ReservationTab({
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
                const SizedBox(width: 6),
                Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.subtle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
