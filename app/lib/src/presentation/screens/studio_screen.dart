import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../models/content_item.dart';
import '../../models/studio.dart';
import '../../providers/studio_controller.dart';
import '../../providers/user_context_controller.dart';
import '../widgets/common_widgets.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  bool _showAllNotices = false;
  bool _showAllEvents = false;

  @override
  Widget build(BuildContext context) {
    final userContext = context.watch<UserContextController>();
    final studioController = context.watch<StudioController>();
    final studio = userContext.selectedMembership?.studio;
    final profileName = userContext.profile?.name?.trim() ?? '';
    final notices = studioController.feed.notices.toList(growable: false)
      ..sort(
        (left, right) =>
            _compareVisibleFromDesc(left.visibleFrom, right.visibleFrom),
      );
    final events = studioController.feed.events.toList(growable: false)
      ..sort(
        (left, right) =>
            _compareVisibleFromDesc(left.visibleFrom, right.visibleFrom),
      );
    final visibleNotices = _showAllNotices ? notices : notices.take(2).toList();
    final visibleEvents = _showAllEvents ? events : events.take(2).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([userContext.refresh(), studioController.refresh()]);
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
                AppPageHeading(
                  title:
                      '안녕하세요${profileName.isNotEmpty ? ', $profileName님' : ''}',
                  subtitle: studio != null
                      ? '오늘도 ${studio.name}의 공지와 수업 소식을 확인해보세요.'
                      : '현재 연결된 스튜디오의 공지와 이벤트를 확인해보세요.',
                  titleStyle: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(
                        color: AppColors.title,
                        fontWeight: FontWeight.w800,
                      ),
                  subtitleStyle: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.subtle, height: 1.4),
                ),
                const SizedBox(height: 16),
                _StudioOverviewCard(studio: studio),
                const SizedBox(height: 32),
                if (studioController.error != null)
                  ErrorSection(
                    message: studioController.error!,
                    onRetry: studioController.refresh,
                  )
                else if (studioController.isLoading)
                  const LoadingSection()
                else ...[
                  if (notices.isNotEmpty) ...[
                    _NoticeSection(
                      notices: visibleNotices,
                      onToggleMore: notices.length > 2
                          ? () {
                              setState(() {
                                _showAllNotices = !_showAllNotices;
                              });
                            }
                          : null,
                      isExpanded: _showAllNotices,
                    ),
                    const SizedBox(height: 32),
                  ],
                  if (events.isNotEmpty)
                    _StudioSection(
                      title: '이벤트',
                      icon: Icons.local_activity_outlined,
                      actionLabel: events.length > 2
                          ? (_showAllEvents ? '접기' : '전체 보기')
                          : null,
                      onToggleMore: events.length > 2
                          ? () {
                              setState(() {
                                _showAllEvents = !_showAllEvents;
                              });
                            }
                          : null,
                      children: visibleEvents
                          .map((event) => _EventCard(event: event))
                          .toList(growable: false),
                    ),
                  if (notices.isEmpty && events.isEmpty)
                    const EmptySection(
                      title: '표시할 스튜디오 콘텐츠가 없습니다',
                      description: '공지나 이벤트가 등록되면 이 화면에 표시됩니다.',
                      icon: Icons.campaign_outlined,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _compareVisibleFromDesc(DateTime? left, DateTime? right) {
    final leftValue =
        left ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final rightValue =
        right ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return rightValue.compareTo(leftValue);
  }
}

class _StudioOverviewCard extends StatelessWidget {
  const _StudioOverviewCard({required this.studio});

  final Studio? studio;

  @override
  Widget build(BuildContext context) {
    if (studio == null) {
      return const EmptySection(
        title: '선택된 스튜디오가 없습니다',
        description: '상단에서 확인할 스튜디오를 선택하면 공지와 수업 정보를 보여드립니다.',
        icon: Icons.apartment_outlined,
      );
    }

    return SurfaceCard(
      showBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudioAvatar(
                name: studio!.name,
                imageUrl: studio!.imageUrl,
                size: 28,
                borderRadius: 10,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  studio!.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.title,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StudioInfoLine(
            icon: Icons.call_outlined,
            label: Formatters.phone(
              studio!.contactPhone,
              fallback: '핸드폰 번호 없음',
            ),
          ),
          if ((studio!.address ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _StudioInfoLine(
              icon: Icons.location_on_outlined,
              label: studio!.address!,
            ),
          ],
        ],
      ),
    );
  }
}

class _StudioSection extends StatelessWidget {
  const _StudioSection({
    required this.title,
    required this.icon,
    required this.children,
    this.actionLabel,
    this.onToggleMore,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final String? actionLabel;
  final VoidCallback? onToggleMore;

  @override
  Widget build(BuildContext context) {
    final sectionTitleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: AppColors.title,
      fontWeight: FontWeight.w800,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppSectionHeader(
              title: title,
              icon: icon,
              titleStyle: sectionTitleStyle,
            ),
            const Spacer(),
            if (onToggleMore != null && actionLabel != null)
              _SectionLinkButton(label: actionLabel!, onTap: onToggleMore!),
          ],
        ),
        const SizedBox(height: 14),
        _SectionListContainer(children: children),
      ],
    );
  }
}

class _NoticeSection extends StatelessWidget {
  const _NoticeSection({
    required this.notices,
    this.onToggleMore,
    this.isExpanded = false,
  });

  final List<NoticeItem> notices;
  final VoidCallback? onToggleMore;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final sectionTitleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: AppColors.title,
      fontWeight: FontWeight.w800,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppSectionHeader(
              title: '공지',
              icon: Icons.campaign_rounded,
              titleStyle: sectionTitleStyle,
            ),
            const Spacer(),
            if (onToggleMore != null)
              _SectionLinkButton(
                label: isExpanded ? '접기' : '전체 보기',
                onTap: onToggleMore!,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionListContainer(
          children: [for (final notice in notices) _NoticeCard(notice: notice)],
        ),
      ],
    );
  }
}

class _SectionListContainer extends StatelessWidget {
  const _SectionListContainer({required this.children});

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
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
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

class _SectionLinkButton extends StatelessWidget {
  const _SectionLinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioInfoLine extends StatelessWidget {
  const _StudioInfoLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.body,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});

  final NoticeItem notice;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openNoticePage(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        notice.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.title,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      _InlineTypeBadge(
                        label: notice.isImportant ? '중요 공지' : '공지',
                        backgroundColor: notice.isImportant
                            ? AppColors.primarySoft
                            : AppColors.surfaceAlt,
                        foregroundColor: notice.isImportant
                            ? AppColors.primary
                            : AppColors.title,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.subtle,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notice.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.35,
                color: AppColors.body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNoticePage(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ContentDetailPage(
          pageTitle: '공지',
          title: notice.title,
          body: notice.body,
          registeredAt: notice.visibleFrom,
          badgeLabel: notice.isImportant ? '중요 공지' : '공지',
          badgeBackgroundColor: notice.isImportant
              ? AppColors.primarySoft
              : AppColors.surfaceAlt,
          badgeForegroundColor: notice.isImportant
              ? AppColors.primary
              : AppColors.title,
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final EventItem event;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openEventPage(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.title,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      _InlineTypeBadge(
                        label: event.isImportant ? '중요' : '이벤트',
                        backgroundColor: event.isImportant
                            ? AppColors.waitlistBackground
                            : AppColors.primarySoft,
                        foregroundColor: event.isImportant
                            ? AppColors.waitlistForeground
                            : AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.subtle,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              event.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.35,
                color: AppColors.body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEventPage(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ContentDetailPage(
          pageTitle: '이벤트',
          title: event.title,
          body: event.body,
          registeredAt: event.visibleFrom,
          badgeLabel: event.isImportant ? '중요' : '이벤트',
          badgeBackgroundColor: event.isImportant
              ? AppColors.waitlistBackground
              : AppColors.primarySoft,
          badgeForegroundColor: event.isImportant
              ? AppColors.waitlistForeground
              : AppColors.primary,
        ),
      ),
    );
  }
}

class _InlineTypeBadge extends StatelessWidget {
  const _InlineTypeBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ContentDetailPage extends StatelessWidget {
  const _ContentDetailPage({
    required this.pageTitle,
    required this.title,
    required this.body,
    required this.registeredAt,
    required this.badgeLabel,
    required this.badgeBackgroundColor,
    required this.badgeForegroundColor,
  });

  final String pageTitle;
  final String title;
  final String body;
  final DateTime? registeredAt;
  final String badgeLabel;
  final Color badgeBackgroundColor;
  final Color badgeForegroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InlineTypeBadge(
                  label: badgeLabel,
                  backgroundColor: badgeBackgroundColor,
                  foregroundColor: badgeForegroundColor,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.title,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (registeredAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '등록일: ${Formatters.date(registeredAt!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.subtle,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.title,
                    height: 1.6,
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
