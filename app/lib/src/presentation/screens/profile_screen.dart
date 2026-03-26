import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../models/pass_models.dart';
import '../../models/studio.dart';
import '../../models/user_profile.dart';
import '../../providers/passes_controller.dart';
import '../../providers/user_context_controller.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/image_storage_repository.dart';
import '../../repositories/profile_repository.dart';
import '../widgets/common_widgets.dart';
import '../widgets/pass_detail_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userContext = context.watch<UserContextController>();
    final passes = context.watch<PassesController>();
    final selectedMembership = userContext.selectedMembership;
    final profile = userContext.profile;
    final sectionTitleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: AppColors.title,
      fontWeight: FontWeight.w800,
    );
    final phoneNumber = Formatters.phone(profile?.phone, fallback: '');
    final availablePasses = passes.passes
        .where((pass) => pass.hasRemaining && !pass.isExpired)
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([userContext.refresh(), passes.refresh()]);
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
                if (!userContext.hasMemberships) ...[
                  _MembershipConnectionCard(
                    memberCode: profile?.memberCode ?? '',
                  ),
                  const SizedBox(height: 24),
                ],
                AppSectionHeader(
                  title: '내 정보',
                  icon: Icons.person_outline_rounded,
                  titleStyle: sectionTitleStyle,
                ),
                const SizedBox(height: 16),
                SurfaceCard(
                  showBorder: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StudioAvatar(
                            name: profile?.name ?? '회원',
                            imageUrl: profile?.imageUrl,
                            size: 64,
                            borderRadius: 20,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
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
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            profile?.name ?? '회원',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  color: AppColors.title,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          if ((profile?.memberCode ?? '')
                                              .isNotEmpty)
                                            _CopyableMemberCodeChip(
                                              memberCode: profile!.memberCode,
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: IconButton(
                                        onPressed: profile == null
                                            ? null
                                            : () => _openEditProfileDialog(
                                                context,
                                                profile: profile,
                                              ),
                                        tooltip: '내 정보 수정',
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _ProfileInfoLine(
                                  icon: Icons.mail_outline_rounded,
                                  label: profile?.email ?? '이메일 없음',
                                ),
                                const SizedBox(height: 8),
                                _ProfileInfoLine(
                                  icon: Icons.call_outlined,
                                  label: phoneNumber.isNotEmpty
                                      ? phoneNumber
                                      : '스튜디오와 소통할 핸드폰 번호를 등록하세요!',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppSectionHeader(
                  title: '스튜디오 선택',
                  icon: Icons.apartment_rounded,
                  titleStyle: sectionTitleStyle,
                ),
                const SizedBox(height: 16),
                _StudioSelectionCard(
                  memberships: userContext.activeMemberships,
                  selectedMembership: selectedMembership,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AppSectionHeader(
                        title: '내 수강권',
                        icon: Icons.confirmation_num_outlined,
                        titleStyle: sectionTitleStyle,
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _UsedPassesScreen(
                                studioName:
                                    selectedMembership?.studio.name ??
                                    '선택 스튜디오',
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '사용한 수강권',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: AppColors.primaryStrong,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: AppColors.primaryStrong,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (passes.error != null)
                  ErrorSection(message: passes.error!, onRetry: passes.refresh)
                else if (passes.isLoading)
                  const LoadingSection()
                else if (availablePasses.isEmpty)
                  const EmptySection(
                    title: '표시할 수강권이 없습니다',
                    description: '잔여 횟수가 있는 수강권이 있으면 이곳에 나타납니다.',
                    icon: Icons.confirmation_num_outlined,
                  )
                else
                  _PassListContainer(
                    children: [
                      for (final pass in availablePasses)
                        _MyPassListItem(pass: pass),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyableMemberCodeChip extends StatelessWidget {
  const _CopyableMemberCodeChip({required this.memberCode});

  final String memberCode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          Clipboard.setData(ClipboardData(text: memberCode));
          showAppSnackBar(context, '회원 ID를 복사했습니다.');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            '회원 ID $memberCode',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _MembershipConnectionCard extends StatelessWidget {
  const _MembershipConnectionCard({required this.memberCode});

  final String memberCode;

  @override
  Widget build(BuildContext context) {
    final resolvedMemberCode = memberCode.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x225A43E3),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26.5),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.priority_high_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '지금 연결이 필요합니다',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '회원 ID를 스튜디오에 전달해\n연결을 완료해주세요',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.title,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '아직 연결된 스튜디오가 없습니다. 아래 회원 ID를 전달하면 수강권과 예약 가능한 수업이 자동으로 표시됩니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.body,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '내 회원 ID',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.subtle,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              resolvedMemberCode.isEmpty
                                  ? '회원 ID 생성 중'
                                  : resolvedMemberCode,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: AppColors.title,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: resolvedMemberCode.isEmpty
                                ? null
                                : () {
                                    Clipboard.setData(
                                      ClipboardData(text: resolvedMemberCode),
                                    );
                                    showAppSnackBar(context, '회원 ID를 복사했습니다.');
                                  },
                            icon: const Icon(
                              Icons.content_copy_rounded,
                              size: 18,
                            ),
                            label: const Text('복사'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _MembershipStep(
                  icon: Icons.looks_one_rounded,
                  text: '회원 ID를 복사해서 다니는 스튜디오에 전달하세요.',
                ),
                const SizedBox(height: 10),
                _MembershipStep(
                  icon: Icons.looks_two_rounded,
                  text: '연결이 완료되면 이 화면에서 스튜디오와 수강권이 바로 보입니다.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MembershipStep extends StatelessWidget {
  const _MembershipStep({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.body,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PassListContainer extends StatelessWidget {
  const _PassListContainer({required this.children});

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

Future<void> _openEditProfileDialog(
  BuildContext context, {
  required UserProfile profile,
}) async {
  final formData = await showDialog<_ProfileEditFormData>(
    context: context,
    builder: (dialogContext) => _EditProfileDialog(profile: profile),
  );

  if (formData == null || !context.mounted) {
    return;
  }

  final authRepository = context.read<AuthRepository>();
  final profileRepository = context.read<ProfileRepository>();
  final userContext = context.read<UserContextController>();
  final normalizedName = formData.name.trim();
  final normalizedPhone = formData.phone.trim();
  final normalizedEmail = formData.email.trim().toLowerCase();
  final currentName = (profile.name ?? '').trim();
  final currentEmail = (profile.email ?? '').trim().toLowerCase();
  final emailChanged = currentEmail != normalizedEmail;
  final nameChanged = currentName != normalizedName;

  try {
    if (emailChanged || nameChanged) {
      await authRepository.updateAccount(
        name: normalizedName,
        email: normalizedEmail,
      );
    }
    await profileRepository.updateProfile(
      currentProfile: profile,
      name: normalizedName,
      phone: normalizedPhone,
      email: normalizedEmail,
      imageFile: formData.imageFile,
      removeImage: formData.removeImage,
    );
    if (!context.mounted) {
      return;
    }
    await userContext.refresh();
    if (!context.mounted) {
      return;
    }
    showAppSnackBar(
      context,
      emailChanged ? '프로필을 저장했습니다. 이메일 변경은 인증 메일을 확인하세요.' : '프로필을 저장했습니다.',
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    showAppSnackBar(context, error.toString(), isError: true);
  }
}

class _ProfileInfoLine extends StatelessWidget {
  const _ProfileInfoLine({required this.icon, required this.label});

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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.title),
          ),
        ),
      ],
    );
  }
}

class _StudioSelectionCard extends StatelessWidget {
  const _StudioSelectionCard({
    required this.memberships,
    required this.selectedMembership,
  });

  final List<StudioMembership> memberships;
  final StudioMembership? selectedMembership;

  @override
  Widget build(BuildContext context) {
    if (memberships.isEmpty) {
      return const EmptySection(
        title: '선택 가능한 스튜디오가 없습니다',
        description: '연결된 스튜디오가 생기면 이곳에서 선택할 수 있습니다.',
        icon: Icons.apartment_outlined,
      );
    }

    final selectedStudio =
        selectedMembership?.studio ?? memberships.first.studio;

    return SurfaceCard(
      showBorder: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StudioAvatar(
                      name: selectedStudio.name,
                      imageUrl: selectedStudio.imageUrl,
                      size: 24,
                      borderRadius: 8,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        selectedStudio.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.title,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ProfileInfoLine(
                  icon: Icons.call_outlined,
                  label: Formatters.phone(
                    selectedStudio.contactPhone,
                    fallback: '핸드폰 번호 없음',
                  ),
                ),
                if ((selectedStudio.address ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ProfileInfoLine(
                    icon: Icons.location_on_outlined,
                    label: selectedStudio.address!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final studioId = await _showStudioSelectionSheet(
                  context,
                  memberships: memberships,
                  selectedStudioId: selectedMembership?.studioId,
                );
                if (studioId == null || !context.mounted) {
                  return;
                }
                final changed = await context
                    .read<UserContextController>()
                    .selectStudio(studioId);
                if (!context.mounted || !changed) {
                  return;
                }
                showAppSnackBar(context, '선택된 스튜디오를 기준으로 앱의 정보들이 표시됩니다');
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.subtle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _showStudioSelectionSheet(
  BuildContext context, {
  required List<StudioMembership> memberships,
  required String? selectedStudioId,
}) {
  final maxHeight = MediaQuery.sizeOf(context).height * 0.62;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x141F2340),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '스튜디오 선택',
                  style: Theme.of(dialogContext).textTheme.titleMedium
                      ?.copyWith(
                        color: AppColors.title,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: SingleChildScrollView(
                    child: Column(
                      children: memberships
                          .map(
                            (membership) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _StudioSelectionOptionTile(
                                membership: membership,
                                isSelected:
                                    membership.studioId == selectedStudioId,
                                onTap: () {
                                  Navigator.of(
                                    dialogContext,
                                  ).pop(membership.studioId);
                                },
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _StudioSelectionOptionTile extends StatelessWidget {
  const _StudioSelectionOptionTile({
    required this.membership,
    required this.isSelected,
    required this.onTap,
  });

  final StudioMembership membership;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final studio = membership.studio;
    final address = (studio.address ?? '').trim();

    return Material(
      color: isSelected ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                StudioAvatar(
                  name: studio.name,
                  imageUrl: studio.imageUrl,
                  size: 40,
                  borderRadius: 14,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studio.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.title,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.subtle),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  size: 18,
                  color: isSelected ? AppColors.primary : AppColors.subtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserPassCard extends StatelessWidget {
  const _UserPassCard({required this.pass});

  final UserPassSummary pass;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(child: _PassCardContent(pass: pass));
  }
}

class _MyPassListItem extends StatelessWidget {
  const _MyPassListItem({required this.pass});

  final UserPassSummary pass;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PassDetailPage(pass: pass)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: _PassCardContent(pass: pass),
      ),
    );
  }
}

class _PassCardContent extends StatelessWidget {
  const _PassCardContent({required this.pass});

  final UserPassSummary pass;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                pass.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            StatusPill(
              label: _userPassStatusLabel(pass),
              backgroundColor: _userPassStatusBackground(pass),
              foregroundColor: _userPassStatusForeground(pass),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${Formatters.date(pass.validFrom)} ~ ${Formatters.date(pass.validUntil)}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.title),
        ),
        const SizedBox(height: 10),
        _PassUsageBar(pass: pass),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PassStat(label: '잔여', value: '${pass.remainingCount}회'),
            ),
            Expanded(
              child: _PassStat(label: '예정', value: '${pass.plannedCount}회'),
            ),
            Expanded(
              child: _PassStat(label: '완료', value: '${pass.completedCount}회'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PassUsageBar extends StatelessWidget {
  const _PassUsageBar({required this.pass});

  final UserPassSummary pass;

  @override
  Widget build(BuildContext context) {
    final derivedTotal =
        pass.completedCount + pass.plannedCount + pass.remainingCount;
    final total = pass.totalCount > derivedTotal
        ? pass.totalCount
        : (derivedTotal > 0 ? derivedTotal : 1);
    final completedFlex = pass.completedCount.clamp(0, total);
    final plannedFlex = pass.plannedCount.clamp(0, total);
    final remainingFlex = pass.remainingCount.clamp(0, total);
    final unusedFlex = total - completedFlex - plannedFlex - remainingFlex;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            if (completedFlex > 0)
              Expanded(
                flex: completedFlex,
                child: const ColoredBox(color: AppColors.successForeground),
              ),
            if (plannedFlex > 0)
              Expanded(
                flex: plannedFlex,
                child: const ColoredBox(color: AppColors.waitlistForeground),
              ),
            if (remainingFlex > 0)
              Expanded(
                flex: remainingFlex,
                child: const ColoredBox(color: AppColors.primary),
              ),
            if (unusedFlex > 0)
              Expanded(
                flex: unusedFlex,
                child: const ColoredBox(color: AppColors.surfaceMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _PassStat extends StatelessWidget {
  const _PassStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.title,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.title,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _UsedPassesScreen extends StatelessWidget {
  const _UsedPassesScreen({required this.studioName});

  final String studioName;

  @override
  Widget build(BuildContext context) {
    final passesController = context.watch<PassesController>();
    final usedPasses =
        passesController.passes
            .where(
              (pass) =>
                  pass.status == 'refunded' ||
                  pass.isExpired ||
                  pass.remainingCount <= 0,
            )
            .toList(growable: false)
          ..sort((left, right) => right.validUntil.compareTo(left.validUntil));

    return Scaffold(
      appBar: AppBar(title: const Text('사용한 수강권')),
      body: RefreshIndicator(
        onRefresh: passesController.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          children: [
            Text(
              studioName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.title,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '만료되었거나 잔여 0회, 환불 처리된 수강권입니다.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
            ),
            const SizedBox(height: 16),
            if (passesController.error != null)
              ErrorSection(
                message: passesController.error!,
                onRetry: passesController.refresh,
              )
            else if (passesController.isLoading)
              const LoadingSection()
            else if (usedPasses.isEmpty)
              const EmptySection(
                title: '사용한 수강권이 없습니다',
                description: '만료되었거나 모두 사용한 수강권이 생기면 이곳에 표시됩니다.',
              )
            else
              ...usedPasses.map(
                (pass) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PassDetailPage(pass: pass),
                        ),
                      );
                    },
                    child: _UserPassCard(pass: pass),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.profile});

  final UserProfile profile;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  PickedImageFile? _selectedImageFile;
  bool _removeImage = false;

  bool get _isPhoneValid => Formatters.isMobilePhone(_phoneController.text);
  bool get _isEmailValid =>
      _emailController.text.trim().isNotEmpty &&
      _emailController.text.trim().contains('@');
  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _isPhoneValid && _isEmailValid;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name ?? '');
    _phoneController = TextEditingController(
      text: Formatters.editablePhone(widget.profile.phone),
    );
    _emailController = TextEditingController(text: widget.profile.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('내 정보 수정'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ImageUploadField(
                name: _nameController.text.trim().isEmpty
                    ? (widget.profile.name ?? '회원')
                    : _nameController.text.trim(),
                label: '프로필 이미지',
                currentImageUrl: _removeImage ? null : widget.profile.imageUrl,
                selectedImageBytes: _selectedImageFile?.bytes,
                helperText: _removeImage ? '저장 시 기존 이미지가 삭제됩니다.' : null,
                onPick: _pickProfileImage,
                onClear:
                    _selectedImageFile != null ||
                        _removeImage ||
                        (!_removeImage &&
                            (widget.profile.imageUrl?.isNotEmpty ?? false))
                    ? _clearProfileImageSelection
                    : null,
                clearLabel: _selectedImageFile != null
                    ? '선택 취소'
                    : (_removeImage ? '삭제 취소' : '이미지 제거'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '이름'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: const [KoreanMobilePhoneTextInputFormatter()],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '핸드폰 번호',
                  helperText: _isPhoneValid
                      ? null
                      : '핸드폰 번호를 올바른 양식으로 입력하세요. (010-1234-5678)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '이메일 주소'),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _canSave
              ? () {
                  final name = _nameController.text.trim();
                  final phone = Formatters.storagePhone(_phoneController.text);
                  final email = _emailController.text.trim();

                  if (name.isEmpty) {
                    showAppSnackBar(context, '이름을 입력하세요.', isError: true);
                    return;
                  }
                  if (!_isPhoneValid) {
                    showAppSnackBar(
                      context,
                      '핸드폰 번호를 올바른 양식으로 입력하세요.',
                      isError: true,
                    );
                    return;
                  }
                  if (email.isEmpty || !email.contains('@')) {
                    showAppSnackBar(
                      context,
                      '올바른 이메일 주소를 입력하세요.',
                      isError: true,
                    );
                    return;
                  }

                  Navigator.of(context).pop(
                    _ProfileEditFormData(
                      name: name,
                      phone: phone,
                      email: email,
                      imageFile: _selectedImageFile,
                      removeImage: _removeImage,
                    ),
                  );
                }
              : null,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      final picked = await context.read<ImageStorageRepository>().pickImage();
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _selectedImageFile = picked;
        _removeImage = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, error.toString(), isError: true);
    }
  }

  void _clearProfileImageSelection() {
    setState(() {
      if (_selectedImageFile != null) {
        _selectedImageFile = null;
      } else if (_removeImage) {
        _removeImage = false;
      } else {
        _removeImage = true;
      }
    });
  }
}

class _ProfileEditFormData {
  const _ProfileEditFormData({
    required this.name,
    required this.phone,
    required this.email,
    required this.imageFile,
    required this.removeImage,
  });

  final String name;
  final String phone;
  final String email;
  final PickedImageFile? imageFile;
  final bool removeImage;
}

String _userPassStatusLabel(UserPassSummary pass) {
  if (pass.status == 'refunded') {
    return Formatters.passStatus(pass.status);
  }
  if (pass.isExpired) {
    return '만료';
  }
  if (pass.remainingCount <= 0) {
    return '소진';
  }
  return '사용 중';
}

Color _userPassStatusBackground(UserPassSummary pass) {
  if (pass.status == 'refunded') {
    return AppColors.errorBackground;
  }
  if (pass.isExpired || pass.remainingCount <= 0) {
    return AppColors.neutralBackground;
  }
  return AppColors.infoBackground;
}

Color _userPassStatusForeground(UserPassSummary pass) {
  if (pass.status == 'refunded') {
    return AppColors.errorForeground;
  }
  if (pass.isExpired || pass.remainingCount <= 0) {
    return AppColors.neutralForeground;
  }
  return AppColors.infoForeground;
}
