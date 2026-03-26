import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../core/legal_documents.dart';
import '../../models/notification_item.dart';
import '../../models/studio.dart';
import '../../providers/auth_controller.dart';
import '../../providers/app_settings_controller.dart';
import '../../providers/notifications_controller.dart';
import '../../providers/push_notifications_controller.dart';
import '../../providers/user_context_controller.dart';
import '../../repositories/pass_repository.dart';
import '../../repositories/reservation_repository.dart';
import 'root_tab_scope.dart';

const double kAppWideBreakpoint = 1100;
const double kAppContentMaxWidth = 1180;
const String kBrandLogoAssetPath = 'assets/branding/icon.png';
const String kBrandIconAssetPath = 'assets/branding/icon_large.png';

bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kAppWideBreakpoint;

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.showBorder = true,
    this.backgroundColor = AppColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showBorder;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: showBorder ? Border.all(color: AppColors.border) : null,
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppViewport extends StatelessWidget {
  const AppViewport({
    required this.child,
    super.key,
    this.maxWidth = kAppContentMaxWidth,
    this.padding = const EdgeInsets.all(24),
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class AppTabHeader extends StatelessWidget {
  const AppTabHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationsController>();
    final rootTabs = RootTabScope.maybeOf(context);
    final notificationBadge = notifications.hasImportantUnread
        ? const _HeaderNotificationBadge.important()
        : notifications.hasUnread
        ? const _HeaderNotificationBadge.unread()
        : null;

    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: rootTabs == null ? null : () => rootTabs.selectIndex(1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _BrandBadge(),
                  const SizedBox(width: 8),
                  Text(
                    '8UP',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.title,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        _HeaderActionButton(
          icon: Icons.settings_rounded,
          tooltip: '설정',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _AccountManagementPage(),
              ),
            );
          },
        ),
        const SizedBox(width: 6),
        _HeaderActionButton(
          icon: notifications.hasUnread
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          tooltip: '알림',
          badge: notificationBadge,
          onTap: () async {
            await showAppBottomSheet<void>(
              context: context,
              builder: (_) => _NotificationsSheet(parentContext: context),
            );
          },
        ),
      ],
    );
  }
}

class _AccountManagementPage extends StatefulWidget {
  const _AccountManagementPage();

  @override
  State<_AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<_AccountManagementPage> {
  _AccountDeletionEligibility? _deletionEligibility;
  bool _isCheckingDeletionEligibility = true;
  bool _isDeletingAccount = false;
  String? _deletionEligibilityError;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadDeletionEligibility);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final push = context.watch<PushNotificationsController>();
    final auth = context.watch<AuthController>();
    final pushSubtitle = !push.isSupported
        ? '현재 기기에서는 지원하지 않습니다.'
        : !settings.pushNotificationsEnabled
        ? '인앱 알림과 동일한 항목을 휴대폰 푸쉬로 받습니다.'
        : push.isAuthorized
        ? '기기 푸쉬 알림이 활성화되어 있습니다.'
        : '앱 설정은 켜져 있지만 시스템 푸쉬 권한이 꺼져 있습니다.';
    final canDeleteAccount =
        !_isCheckingDeletionEligibility &&
        (_deletionEligibility?.canDelete ?? false) &&
        !_isDeletingAccount &&
        !auth.isBusy;
    final deleteSubtitle = _isCheckingDeletionEligibility
        ? '예약 이력과 수강권 상태를 확인하고 있습니다.'
        : _deletionEligibilityError != null
        ? _deletionEligibilityError!
        : _deletionEligibility?.message ?? '계정을 삭제하면 복구할 수 없습니다.';

    return Scaffold(
      appBar: AppBar(title: const Text('계정 관리')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '설정',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.title,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '계정과 알림, 앱 사용 관련 설정을 관리합니다.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.body),
                ),
                const SizedBox(height: 12),
                _AccountManagementNavigationTile(
                  icon: Icons.apartment_rounded,
                  title: '다니는 스튜디오 설정',
                  subtitle: '앱에서 표시할 스튜디오의 활성/비활성 상태를 관리합니다.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _StudioMembershipSettingsPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 24),
                SwitchListTile.adaptive(
                  value: settings.pushNotificationsEnabled,
                  onChanged:
                      settings.isLoading || push.isBusy || !push.isSupported
                      ? null
                      : (value) async {
                          final pushController = context
                              .read<PushNotificationsController>();
                          final settingsController = context
                              .read<AppSettingsController>();
                          if (value) {
                            final granted = await pushController
                                .prepareForEnable();
                            if (!granted) {
                              if (!context.mounted) {
                                return;
                              }
                              showAppSnackBar(
                                context,
                                push.error ?? '푸쉬 알림 권한을 활성화하지 못했습니다.',
                                isError: true,
                              );
                              return;
                            }
                          }

                          try {
                            await settingsController
                                .setPushNotificationsEnabled(value);
                            if (!value) {
                              await pushController
                                  .disableForCurrentInstallation();
                            }
                            if (!context.mounted) {
                              return;
                            }
                            showAppSnackBar(
                              context,
                              value
                                  ? '앱 푸시 알림을 활성화했습니다.'
                                  : '앱 푸시 알림을 비활성화했습니다.',
                            );
                          } catch (error) {
                            if (value) {
                              await settingsController
                                  .setPushNotificationsEnabled(false);
                              await pushController
                                  .disableForCurrentInstallation();
                            }
                            if (!context.mounted) {
                              return;
                            }
                            showAppSnackBar(context, '$error', isError: true);
                          }
                        },
                  contentPadding: EdgeInsets.zero,
                  title: const Text('앱 푸시 알림'),
                  subtitle: Text(pushSubtitle),
                ),
                if ((push.error ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      push.error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.errorForeground,
                        height: 1.45,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: _AccountManagementNavigationTile(
              icon: Icons.description_outlined,
              title: '약관 및 정책',
              subtitle: '개인정보 처리방침과 서비스 이용약관을 확인합니다.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _LegalPoliciesPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: _AccountManagementActionTile(
              icon: Icons.logout_rounded,
              title: '로그아웃',
              subtitle: '현재 계정에서 로그아웃합니다.',
              onTap: auth.isBusy || _isDeletingAccount
                  ? null
                  : () async {
                      await context.read<AuthController>().signOut();
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).popUntil((route) => route.isFirst);
                    },
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: _AccountManagementActionTile(
              icon: Icons.person_remove_alt_1_rounded,
              title: '계정 삭제',
              subtitle: deleteSubtitle,
              backgroundColor: AppColors.waitlistBackground,
              foregroundColor: AppColors.waitlistForeground,
              onTap: canDeleteAccount ? _confirmDeleteAccount : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDeletionEligibility() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isCheckingDeletionEligibility = true;
      _deletionEligibilityError = null;
    });

    try {
      final reservationRepository = context.read<ReservationRepository>();
      final passRepository = context.read<PassRepository>();
      final hasReservationHistory = await reservationRepository
          .hasAnyReservationHistory();
      final hasBlockingPass = await passRepository
          .hasBlockingPassForAccountDeletion();

      if (!mounted) {
        return;
      }
      setState(() {
        _deletionEligibility = _AccountDeletionEligibility(
          hasReservationHistory: hasReservationHistory,
          hasBlockingPass: hasBlockingPass,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _deletionEligibilityError = '계정 삭제 가능 여부를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingDeletionEligibility = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: SurfaceCard(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                showBorder: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '계정을 삭제할까요?',
                      style: Theme.of(dialogContext).textTheme.titleMedium
                          ?.copyWith(
                            color: AppColors.title,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '삭제 후에는 계정과 프로필 정보가 복구되지 않습니다. 실제 삭제는 Supabase의 `delete_my_account` RPC와 연결되어야 합니다.',
                      style: Theme.of(dialogContext).textTheme.bodySmall
                          ?.copyWith(color: AppColors.body, height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text('닫기'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.errorForeground,
                              foregroundColor: AppColors.onPrimary,
                            ),
                            child: const Text('계정 삭제'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isDeletingAccount = true;
    });
    try {
      await context.read<AuthController>().deleteAccount();
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, '계정을 삭제했습니다.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, '$error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }
}

class _AccountManagementNavigationTile extends StatelessWidget {
  const _AccountManagementNavigationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.primaryStrong),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.body, height: 1.45),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _AccountManagementActionTile extends StatelessWidget {
  const _AccountManagementActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.backgroundColor = AppColors.errorBackground,
    this.foregroundColor = AppColors.errorForeground,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? backgroundColor : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: enabled ? foregroundColor : AppColors.subtle),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: enabled ? AppColors.title : AppColors.subtle,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: enabled ? AppColors.body : AppColors.subtle,
            height: 1.45,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

class _AccountDeletionEligibility {
  const _AccountDeletionEligibility({
    required this.hasReservationHistory,
    required this.hasBlockingPass,
  });

  final bool hasReservationHistory;
  final bool hasBlockingPass;

  bool get canDelete => !hasReservationHistory && !hasBlockingPass;

  String get message {
    if (hasReservationHistory && hasBlockingPass) {
      return '예약 이력과 만료되지 않았거나 남은 횟수가 있는 수강권이 있어 계정을 삭제할 수 없습니다.';
    }
    if (hasReservationHistory) {
      return '예약 이력이 있어 계정을 삭제할 수 없습니다.';
    }
    if (hasBlockingPass) {
      return '만료되지 않았거나 남은 횟수가 있는 수강권이 있어 계정을 삭제할 수 없습니다.';
    }
    return '예약 이력과 사용 중인 수강권이 없을 때만 계정을 삭제할 수 있습니다.';
  }
}

class _StudioMembershipSettingsPage extends StatefulWidget {
  const _StudioMembershipSettingsPage();

  @override
  State<_StudioMembershipSettingsPage> createState() =>
      _StudioMembershipSettingsPageState();
}

class _StudioMembershipSettingsPageState
    extends State<_StudioMembershipSettingsPage> {
  String? _busyMembershipId;

  @override
  Widget build(BuildContext context) {
    final userContext = context.watch<UserContextController>();
    final memberships = userContext.memberships;

    return Scaffold(
      appBar: AppBar(title: const Text('다니는 스튜디오 설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '활성화한 스튜디오만 앱 본문의 선택 목록에 표시됩니다. 지금은 다니지 않는 스튜디오는 비활성화해 두고, 나중에 다시 활성화할 수 있습니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.body,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (memberships.isEmpty)
            const EmptySection(
              title: '등록된 스튜디오가 없습니다',
              description: '스튜디오 관리자가 회원 등록을 완료하면 이곳에 표시됩니다.',
            )
          else
            ...memberships.map((membership) {
              final isBusy = _busyMembershipId == membership.id;
              final isSelected =
                  userContext.selectedStudioId == membership.studioId;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StudioAvatar(
                            name: membership.studio.name,
                            imageUrl: membership.studio.imageUrl,
                            size: 44,
                            borderRadius: 14,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  membership.studio.name,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: AppColors.title,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  membership.isActive
                                      ? (isSelected
                                            ? '현재 선택된 스튜디오'
                                            : '선택 목록에 표시 중')
                                      : '선택 목록에서 숨김',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.subtle,
                                        height: 1.4,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          StatusPill(
                            label: membership.isActive ? '활성' : '비활성',
                            backgroundColor: membership.isActive
                                ? AppColors.successBackground
                                : AppColors.surfaceMuted,
                            foregroundColor: membership.isActive
                                ? AppColors.successForeground
                                : AppColors.neutralForeground,
                          ),
                        ],
                      ),
                      if ((membership.studio.address ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            membership.studio.address!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.body, height: 1.4),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: membership.isActive
                            ? FilledButton.tonalIcon(
                                onPressed: isBusy
                                    ? null
                                    : () => _updateMembershipStatus(
                                        context,
                                        membership: membership,
                                        nextStatus: 'inactive',
                                      ),
                                icon: isBusy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.visibility_off_rounded),
                                label: const Text('비활성화'),
                              )
                            : FilledButton.icon(
                                onPressed: isBusy
                                    ? null
                                    : () => _updateMembershipStatus(
                                        context,
                                        membership: membership,
                                        nextStatus: 'active',
                                      ),
                                icon: isBusy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.onPrimary,
                                        ),
                                      )
                                    : const Icon(Icons.visibility_rounded),
                                label: const Text('다시 활성화'),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _updateMembershipStatus(
    BuildContext context, {
    required StudioMembership membership,
    required String nextStatus,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busyMembershipId = membership.id;
    });
    try {
      await context.read<UserContextController>().updateMembershipStatus(
        membershipId: membership.id,
        status: nextStatus,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(
        messenger,
        nextStatus == 'active'
            ? '${membership.studio.name}을 다시 활성화했습니다.'
            : '${membership.studio.name}을 비활성화했습니다.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, '$error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busyMembershipId = null;
        });
      }
    }
  }
}

class _LegalPoliciesPage extends StatelessWidget {
  const _LegalPoliciesPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('약관 및 정책')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '안내',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.title,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '아래 문서는 수업 예약 앱 운영을 기준으로 작성한 기본 초안입니다. 실제 공개 전에는 운영자 상호, 연락처, 사업자 정보, 위탁 현황, 환불 정책을 실제 서비스 내용에 맞게 보완해야 합니다.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.body),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              children: [
                _AccountManagementNavigationTile(
                  icon: Icons.privacy_tip_outlined,
                  title: privacyPolicyDocument.title,
                  subtitle: '개인정보 수집, 이용, 보관, 보호 조치를 확인합니다.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _LegalDocumentPage(
                          document: privacyPolicyDocument,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 24),
                _AccountManagementNavigationTile(
                  icon: Icons.gavel_rounded,
                  title: termsOfServiceDocument.title,
                  subtitle: '예약, 취소, 이용 제한, 책임 범위 등 서비스 기준을 확인합니다.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _LegalDocumentPage(
                          document: termsOfServiceDocument,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalDocumentPage extends StatelessWidget {
  const _LegalDocumentPage({required this.document});

  final LegalDocumentData document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          SurfaceCard(
            child: Text(
              document.summary,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.body,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...document.sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.title,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      section.body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.body,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppTopSection extends StatelessWidget {
  const AppTopSection({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.fromLTRB(24, 10, 24, 12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class StudioAvatar extends StatelessWidget {
  const StudioAvatar({
    required this.name,
    super.key,
    this.imageUrl,
    this.imageBytes,
    this.size = 48,
    this.borderRadius = 16,
  });

  final String name;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final imageUrl = this.imageUrl;
    final placeholder = _StudioAvatarPlaceholder(
      name: name,
      size: size,
      borderRadius: borderRadius,
    );

    final imageBytes = this.imageBytes;

    if (imageBytes != null && imageBytes.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: ColoredBox(
            color: AppColors.surface,
            child: Image.memory(
              imageBytes,
              width: size,
              height: size,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => placeholder,
            ),
          ),
        ),
      );
    }

    if (imageUrl == null || imageUrl.isEmpty) {
      return placeholder;
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: ColoredBox(
          color: AppColors.surface,
          child: Image.network(
            imageUrl,
            width: size,
            height: size,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => placeholder,
          ),
        ),
      ),
    );
  }
}

class ImageUploadField extends StatelessWidget {
  const ImageUploadField({
    required this.name,
    required this.label,
    required this.onPick,
    super.key,
    this.currentImageUrl,
    this.selectedImageBytes,
    this.onClear,
    this.clearLabel,
    this.helperText,
    this.size = 72,
    this.borderRadius = 22,
    this.showPickButton = true,
    this.previewOverlayLabel,
  });

  final String name;
  final String label;
  final VoidCallback onPick;
  final String? currentImageUrl;
  final Uint8List? selectedImageBytes;
  final VoidCallback? onClear;
  final String? clearLabel;
  final String? helperText;
  final double size;
  final double borderRadius;
  final bool showPickButton;
  final String? previewOverlayLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (helperText != null && helperText!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            helperText!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onPick,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          StudioAvatar(
                            name: name,
                            imageUrl: currentImageUrl,
                            imageBytes: selectedImageBytes,
                            size: size,
                            borderRadius: borderRadius,
                          ),
                          if (previewOverlayLabel != null &&
                              previewOverlayLabel!.trim().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.56),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                previewOverlayLabel!,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedImageBytes != null
                              ? '새 이미지가 선택되었습니다'
                              : (currentImageUrl?.isNotEmpty == true
                                    ? '등록된 이미지가 있습니다'
                                    : '등록된 이미지가 없습니다'),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          showPickButton
                              ? '기기에서 이미지를 선택해 업로드합니다.'
                              : '이미지를 눌러 변경합니다.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.subtle),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showPickButton || onClear != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (showPickButton)
                      FilledButton.tonalIcon(
                        onPressed: onPick,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('파일 선택'),
                      ),
                    if (onClear != null)
                      FilledButton.tonalIcon(
                        onPressed: onClear,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(clearLabel ?? '이미지 제거'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class StudioPicker extends StatelessWidget {
  const StudioPicker({
    required this.memberships,
    required this.selectedStudioId,
    required this.onChanged,
    super.key,
    this.labelText,
    this.hintText = '스튜디오 선택',
  });

  final List<StudioMembership> memberships;
  final String? selectedStudioId;
  final ValueChanged<String?> onChanged;
  final String? labelText;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final selectedId =
        memberships.any((item) => item.studioId == selectedStudioId)
        ? selectedStudioId
        : (memberships.isEmpty ? null : memberships.first.studioId);

    return DropdownButtonFormField<String>(
      value: selectedId,
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.subtle,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        filled: true,
        fillColor: AppColors.surface,
      ),
      selectedItemBuilder: (context) => memberships
          .map(
            (membership) =>
                _StudioPickerSelectedLabel(studio: membership.studio),
          )
          .toList(growable: false),
      items: memberships
          .map(
            (membership) => DropdownMenuItem<String>(
              value: membership.studioId,
              child: _StudioPickerMenuLabel(studio: membership.studio),
            ),
          )
          .toList(growable: false),
      onChanged: memberships.isEmpty ? null : onChanged,
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.icon,
    this.emoji,
    this.titleStyle,
    super.key,
  }) : assert(icon != null || emoji != null);

  final String title;
  final IconData? icon;
  final String? emoji;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          child: emoji != null
              ? Text(emoji!, style: const TextStyle(fontSize: 14))
              : Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style:
              titleStyle ??
              Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class AppPageHeading extends StatelessWidget {
  const AppPageHeading({
    required this.title,
    required this.subtitle,
    super.key,
    this.trailing,
    this.titleStyle,
    this.subtitleStyle,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    titleStyle ??
                    Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.title,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style:
                    subtitleStyle ??
                    Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.subtle,
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 16),
          Flexible(child: trailing!),
        ],
      ],
    );
  }
}

class EmptySection extends StatelessWidget {
  const EmptySection({
    required this.title,
    required this.description,
    super.key,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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

class ErrorSection extends StatelessWidget {
  const ErrorSection({required this.message, required this.onRetry, super.key});

  final String message;
  final FutureOr<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '불러오는 중 문제가 발생했습니다',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () {
              onRetry();
            },
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

class LoadingSection extends StatelessWidget {
  const LoadingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    super.key,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class InfoBadge extends StatelessWidget {
  const InfoBadge({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.body,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final maxWidth = width >= 900 ? 720.0 : width;

  return showDialog<T>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.82,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Material(
            color: AppColors.background,
            child: builder(dialogContext),
          ),
        ),
      ),
    ),
  );
}

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  showAppSnackBarWithMessenger(
    ScaffoldMessenger.of(context),
    message,
    isError: isError,
  );
}

void showAppSnackBarWithMessenger(
  ScaffoldMessengerState messenger,
  String message, {
  bool isError = false,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.errorForeground : null,
      ),
    );
}

Future<void> showReservationStatusReasonDialog(
  BuildContext context, {
  required String title,
  required String? reason,
  required String emptyMessage,
  String? adminName,
  DateTime? processedAt,
}) {
  final resolvedReason = (reason ?? '').trim();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((adminName ?? '').trim().isNotEmpty || processedAt != null)
              Text(
                [
                  if ((adminName ?? '').trim().isNotEmpty) adminName!.trim(),
                  if (processedAt != null) Formatters.full(processedAt),
                ].join(' · '),
                style: Theme.of(
                  dialogContext,
                ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
              ),
            if ((adminName ?? '').trim().isNotEmpty || processedAt != null)
              const SizedBox(height: 12),
            Text(
              resolvedReason.isNotEmpty ? resolvedReason : emptyMessage,
              style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                color: AppColors.body,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

Future<void> showStudioCancelReasonDialog(
  BuildContext context, {
  required String? reason,
  String? adminName,
  DateTime? processedAt,
}) {
  return showReservationStatusReasonDialog(
    context,
    title: '스튜디오 취소 사유',
    reason: reason,
    emptyMessage: '스튜디오에서 취소 사유를 남기지 않았습니다.',
    adminName: adminName,
    processedAt: processedAt,
  );
}

Future<void> showStudioRejectReasonDialog(
  BuildContext context, {
  required String? reason,
  String? adminName,
  DateTime? processedAt,
}) {
  return showReservationStatusReasonDialog(
    context,
    title: '취소 요청 거절 사유',
    reason: reason,
    emptyMessage: '스튜디오에서 거절 사유를 남기지 않았습니다.',
    adminName: adminName,
    processedAt: processedAt,
  );
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kBrandLogoAssetPath,
      height: 30,
      fit: BoxFit.fitHeight,
      filterQuality: FilterQuality.medium,
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Tooltip(
            message: tooltip,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(child: Icon(icon, size: 18, color: AppColors.title)),
                if (badge != null) Positioned(top: 2, right: 0, child: badge!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderNotificationBadge extends StatelessWidget {
  const _HeaderNotificationBadge._({
    required this.backgroundColor,
    required this.child,
    required this.size,
  });

  const _HeaderNotificationBadge.unread()
    : this._(
        backgroundColor: AppColors.calendarOpen,
        size: 10,
        child: const SizedBox.shrink(),
      );

  const _HeaderNotificationBadge.important()
    : this._(
        backgroundColor: AppColors.errorForeground,
        size: 16,
        child: const Text(
          '!',
          style: TextStyle(
            color: AppColors.onPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  final Color backgroundColor;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 1.5),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({required this.parentContext});

  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationsController>();
    final unreadNotifications = controller.unreadNotifications;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '알림',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.title,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (controller.hasUnread)
                  TextButton(
                    onPressed: () async {
                      await context
                          .read<NotificationsController>()
                          .markAllRead();
                    },
                    child: const Text('모두 읽음'),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '닫기',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (controller.error != null)
              ErrorSection(
                message: controller.error!,
                onRetry: controller.refresh,
              )
            else if (controller.isLoading && controller.notifications.isEmpty)
              const LoadingSection()
            else if (unreadNotifications.isEmpty)
              const EmptySection(
                title: '읽지 않은 알림이 없습니다',
                description: '새 알림이 오면 이곳에 표시되고, 전체보기에서 최근 7일 기록을 확인할 수 있습니다.',
              )
            else
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 480),
                  child: Scrollbar(
                    thumbVisibility: unreadNotifications.length > 5,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: unreadNotifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final notification = unreadNotifications[index];
                        return _NotificationListTile(
                          notification: notification,
                          compact: true,
                          onTap: () => _showNotificationDetailDialog(
                            context,
                            notification,
                          ),
                          onMarkRead: () async {
                            await context
                                .read<NotificationsController>()
                                .markRead(notification.id);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await Future<void>.delayed(Duration.zero);
                  if (!parentContext.mounted) {
                    return;
                  }
                  await Navigator.of(parentContext).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _NotificationsPage(),
                    ),
                  );
                },
                child: const Text('전체보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsPage extends StatefulWidget {
  const _NotificationsPage();

  @override
  State<_NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<_NotificationsPage> {
  static const int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      setState(() {
        _visibleCount += _pageSize;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationsController>();
    final studioName = context
        .watch<UserContextController>()
        .selectedMembership
        ?.studio
        .name;
    final recentBoundary = DateTime.now().subtract(const Duration(days: 7));
    final recentNotifications = controller.notifications
        .where((item) => !item.createdAt.isBefore(recentBoundary))
        .toList(growable: false);
    final visibleItems = recentNotifications
        .take(_visibleCount.clamp(0, recentNotifications.length))
        .toList(growable: false);
    final hasMore = visibleItems.length < recentNotifications.length;

    return Scaffold(
      appBar: AppBar(title: const Text('전체 알림')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studioName == null
                        ? '최근 7일간의 알림을 확인합니다.'
                        : '$studioName 최근 7일간의 알림을 확인합니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.body,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '알림 행을 누르면 전체 내용을 볼 수 있고, 읽지 않은 알림은 각 행의 읽음 버튼으로 처리합니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.subtle,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (controller.error != null) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: ErrorSection(
                      message: controller.error!,
                      onRetry: controller.refresh,
                    ),
                  );
                }
                if (controller.isLoading && controller.notifications.isEmpty) {
                  return const LoadingSection();
                }
                if (recentNotifications.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: EmptySection(
                      title: '최근 7일 알림이 없습니다',
                      description: '새로운 공지나 수업 변경 알림이 오면 이곳에 표시됩니다.',
                    ),
                  );
                }

                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: visibleItems.length + (hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index >= visibleItems.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final notification = visibleItems[index];
                    return _NotificationListTile(
                      notification: notification,
                      onTap: () =>
                          _showNotificationDetailDialog(context, notification),
                      onMarkRead: notification.isRead
                          ? null
                          : () async {
                              await context
                                  .read<NotificationsController>()
                                  .markRead(notification.id);
                            },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationListTile extends StatelessWidget {
  const _NotificationListTile({
    required this.notification,
    required this.onTap,
    this.onMarkRead,
    this.compact = false,
  });

  final AppNotificationItem notification;
  final VoidCallback onTap;
  final Future<void> Function()? onMarkRead;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tileColor = notification.isRead
        ? AppColors.surfaceAlt
        : notification.isImportant
        ? AppColors.highlightBackground
        : AppColors.infoBackground;

    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppColors.title,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: _buildNotificationBadge(notification)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!notification.isRead && onMarkRead != null)
                    TextButton(
                      onPressed: () async {
                        await onMarkRead!();
                      },
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('읽음'),
                    )
                  else if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: notification.isImportant
                            ? AppColors.errorForeground
                            : AppColors.calendarOpen,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              SizedBox(height: compact ? 6 : 8),
              Text(
                notification.body,
                maxLines: compact ? 3 : 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.body,
                  height: 1.45,
                ),
              ),
              SizedBox(height: compact ? 8 : 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      Formatters.full(notification.createdAt),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.subtle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showNotificationDetailDialog(
  BuildContext context,
  AppNotificationItem notification,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNotificationBadge(notification),
                  const SizedBox(height: 12),
                  Text(
                    notification.title,
                    style: Theme.of(dialogContext).textTheme.titleMedium
                        ?.copyWith(
                          color: AppColors.title,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close_rounded),
              tooltip: '닫기',
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Formatters.full(notification.createdAt),
                style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: AppColors.subtle,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                child: Text(
                  notification.body,
                  style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                    color: AppColors.body,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('닫기'),
          ),
        ],
      );
    },
  );
}

Widget _buildNotificationBadge(AppNotificationItem notification) {
  switch (notification.kind) {
    case 'notice':
      return StatusPill(
        label: notification.isImportant ? '중요 공지' : '공지',
        backgroundColor: notification.isImportant
            ? AppColors.highlightBackground
            : AppColors.infoBackground,
        foregroundColor: notification.isImportant
            ? AppColors.highlightForeground
            : AppColors.infoForeground,
      );
    case 'event':
      return StatusPill(
        label: notification.isImportant ? '중요 이벤트' : '이벤트',
        backgroundColor: notification.isImportant
            ? AppColors.highlightBackground
            : AppColors.infoBackground,
        foregroundColor: notification.isImportant
            ? AppColors.highlightForeground
            : AppColors.infoForeground,
      );
    case 'reservation_created':
      return const StatusPill(
        label: '예약 완료',
        backgroundColor: AppColors.successBackground,
        foregroundColor: AppColors.successForeground,
      );
    case 'waitlist_registered':
      return const StatusPill(
        label: '대기 예약',
        backgroundColor: AppColors.waitlistBackground,
        foregroundColor: AppColors.waitlistForeground,
      );
    case 'waitlist_promoted':
      return const StatusPill(
        label: '예약 확정',
        backgroundColor: AppColors.successBackground,
        foregroundColor: AppColors.successForeground,
      );
    case 'reservation_cancelled':
      return const StatusPill(
        label: '예약 취소',
        backgroundColor: AppColors.neutralBackground,
        foregroundColor: AppColors.neutralForeground,
      );
    case 'session_cancelled':
      return const StatusPill(
        label: '수업 취소',
        backgroundColor: AppColors.errorBackground,
        foregroundColor: AppColors.errorForeground,
      );
    case 'session_instructor_changed':
      return const StatusPill(
        label: '강사 변경',
        backgroundColor: AppColors.errorBackground,
        foregroundColor: AppColors.errorForeground,
      );
    case 'cancel_request_approved':
      return const StatusPill(
        label: '취소 승인',
        backgroundColor: AppColors.successBackground,
        foregroundColor: AppColors.successForeground,
      );
    case 'cancel_request_rejected':
      return const StatusPill(
        label: '취소 거절',
        backgroundColor: AppColors.neutralBackground,
        foregroundColor: AppColors.neutralForeground,
      );
    case 'session_reminder_day_before':
      return const StatusPill(
        label: '하루 전 알림',
        backgroundColor: AppColors.infoBackground,
        foregroundColor: AppColors.infoForeground,
      );
    case 'session_reminder_hour_before':
      return const StatusPill(
        label: '곧 시작',
        backgroundColor: AppColors.infoBackground,
        foregroundColor: AppColors.infoForeground,
      );
    case 'pass_issued':
      return const StatusPill(
        label: '수강권 발급',
        backgroundColor: AppColors.successBackground,
        foregroundColor: AppColors.successForeground,
      );
    case 'pass_refunded':
      return const StatusPill(
        label: '수강권 환불',
        backgroundColor: AppColors.neutralBackground,
        foregroundColor: AppColors.neutralForeground,
      );
    case 'pass_hold_registered':
      return const StatusPill(
        label: '수강권 홀딩',
        backgroundColor: AppColors.surfaceAlt,
        foregroundColor: AppColors.body,
      );
    case 'pass_hold_cancelled':
      return const StatusPill(
        label: '홀딩 취소',
        backgroundColor: AppColors.surfaceAlt,
        foregroundColor: AppColors.body,
      );
    case 'pass_hold_ended':
      return const StatusPill(
        label: '홀딩 종료',
        backgroundColor: AppColors.surfaceAlt,
        foregroundColor: AppColors.body,
      );
    case 'studio_membership_approved':
      return const StatusPill(
        label: '가입 승인',
        backgroundColor: AppColors.successBackground,
        foregroundColor: AppColors.successForeground,
      );
    case 'studio_membership_reactivated':
      return const StatusPill(
        label: '이용 재개',
        backgroundColor: AppColors.successBackground,
        foregroundColor: AppColors.successForeground,
      );
    case 'session_reservation_removed':
      return const StatusPill(
        label: '예약 변경',
        backgroundColor: AppColors.errorBackground,
        foregroundColor: AppColors.errorForeground,
      );
    default:
      return StatusPill(
        label: notification.isImportant ? '중요 알림' : '알림',
        backgroundColor: notification.isImportant
            ? AppColors.highlightBackground
            : AppColors.surfaceAlt,
        foregroundColor: notification.isImportant
            ? AppColors.highlightForeground
            : AppColors.body,
      );
  }
}

class _StudioPickerSelectedLabel extends StatelessWidget {
  const _StudioPickerSelectedLabel({required this.studio});

  final Studio studio;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StudioAvatar(
          name: studio.name,
          imageUrl: studio.imageUrl,
          size: 28,
          borderRadius: 10,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            studio.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.title,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StudioPickerMenuLabel extends StatelessWidget {
  const _StudioPickerMenuLabel({required this.studio});

  final Studio studio;

  @override
  Widget build(BuildContext context) {
    final address = (studio.address ?? '').trim();

    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          StudioAvatar(
            name: studio.name,
            imageUrl: studio.imageUrl,
            size: 32,
            borderRadius: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  studio.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.title,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (address.isNotEmpty)
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: AppColors.subtle),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioAvatarPlaceholder extends StatelessWidget {
  const _StudioAvatarPlaceholder({
    required this.name,
    required this.size,
    required this.borderRadius,
  });

  final String name;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        _studioInitials(name),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _studioInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    return '8';
  }

  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'
      .toUpperCase();
}
