import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../providers/auth_controller.dart';
import '../../providers/user_context_controller.dart';
import '../widgets/common_widgets.dart';
import '../widgets/root_tab_scope.dart';
import 'auth_screen.dart';
import 'calendar_screen.dart';
import 'studio_screen.dart';
import 'profile_screen.dart';
import 'reservations_screen.dart';

class RootShell extends StatelessWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final userContext = context.watch<UserContextController>();

    if (!auth.isAuthenticated) {
      return const AuthScreen();
    }

    if (auth.isPasswordRecovery) {
      return const PasswordRecoveryScreen();
    }

    if (userContext.isLoading && userContext.profile == null) {
      return const Scaffold(body: SafeArea(child: LoadingSection()));
    }

    if (userContext.requiresSignOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && auth.isAuthenticated && !auth.isBusy) {
          context.read<AuthController>().signOut();
        }
      });
      return const Scaffold(body: SafeArea(child: LoadingSection()));
    }

    if (userContext.error != null && userContext.profile == null) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ErrorSection(
                message: userContext.error!,
                onRetry: userContext.refresh,
              ),
            ],
          ),
        ),
      );
    }

    if (userContext.profile == null) {
      return const Scaffold(body: SafeArea(child: LoadingSection()));
    }

    return _MainTabShell(initialIndex: userContext.hasMemberships ? 1 : 3);
  }
}

class _MainTabShell extends StatefulWidget {
  const _MainTabShell({required this.initialIndex});

  final int initialIndex;

  @override
  State<_MainTabShell> createState() => _MainTabShellState();
}

class _MainTabShellState extends State<_MainTabShell> {
  late int _index;

  static const _screens = [
    StudioScreen(),
    CalendarScreen(),
    ReservationsScreen(),
    ProfileScreen(),
  ];
  static const _destinations = [
    _ShellDestination(
      icon: Icons.apartment_rounded,
      label: '스튜디오',
      description: '공지와 요약',
    ),
    _ShellDestination(
      icon: Icons.calendar_month_rounded,
      label: '예약',
      description: '수업 일정',
    ),
    _ShellDestination(
      icon: Icons.event_available_rounded,
      label: '내 예약',
      description: '예약 상태',
    ),
    _ShellDestination(
      icon: Icons.person_rounded,
      label: '마이',
      description: '회원 정보',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final wideLayout = isWideLayout(context);

    return wideLayout ? _buildDesktopShell(context) : _buildMobileShell();
  }

  Widget _buildMobileShell() {
    return RootTabScope(
      onSelectTab: _selectIndex,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: _screens),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: _selectIndex,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.apartment_rounded),
                label: '스튜디오',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_rounded),
                label: '예약',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.event_available_rounded),
                label: '내 예약',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: '마이',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopShell(BuildContext context) {
    final userContext = context.watch<UserContextController>();
    final auth = context.watch<AuthController>();

    return RootTabScope(
      onSelectTab: _selectIndex,
      child: Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 0, 20),
                child: SizedBox(
                  width: 280,
                  child: SurfaceCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '8UP',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: AppColors.onPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                userContext.profile?.name ?? '회원',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppColors.onPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                userContext.selectedMembership?.studio.name ??
                                    '스튜디오 연결 필요',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.onPrimary.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        for (var i = 0; i < _destinations.length; i++) ...[
                          _DesktopNavButton(
                            destination: _destinations[i],
                            selected: _index == i,
                            onTap: () => _selectIndex(i),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const Spacer(),
                        Text(
                          '회원 ID ${userContext.profile?.memberCode ?? ''}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: AppColors.body,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            auth.signOut();
                          },
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('로그아웃'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth > kAppContentMaxWidth
                          ? kAppContentMaxWidth
                          : constraints.maxWidth;

                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: width,
                          height: constraints.maxHeight,
                          child: IndexedStack(
                            index: _index,
                            children: _screens,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectIndex(int value) {
    setState(() {
      _index = value;
    });
  }
}

class _DesktopNavButton extends StatelessWidget {
  const _DesktopNavButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                destination.icon,
                color: selected ? AppColors.primary : AppColors.subtle,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.primary : AppColors.title,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destination.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.icon,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String description;
}
