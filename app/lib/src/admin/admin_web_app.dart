import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/error_text.dart';
import '../core/formatters.dart';
import '../core/reservation_bucket_rules.dart';
import '../models/class_models.dart';
import '../presentation/widgets/common_widgets.dart';
import 'models/admin_models.dart';
import 'providers/admin_auth_controller.dart';
import 'providers/admin_session_controller.dart';
import 'repositories/admin_auth_repository.dart';
import 'repositories/admin_repository.dart';
import '../repositories/image_storage_repository.dart';

const String _supportEmailAddress = 'cresilience91@gmail.com';

class EightUpAdminWebApp extends StatelessWidget {
  const EightUpAdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SupabaseClient>(create: (_) => Supabase.instance.client),
        ProxyProvider<SupabaseClient, ImageStorageRepository>(
          update: (_, client, __) => ImageStorageRepository(client),
        ),
        ProxyProvider<SupabaseClient, AdminAuthRepository>(
          update: (_, client, __) => AdminAuthRepository(client),
        ),
        ProxyProvider2<SupabaseClient, ImageStorageRepository, AdminRepository>(
          update: (_, client, imageStorage, __) =>
              AdminRepository(client, imageStorage),
        ),
        ChangeNotifierProvider<AdminAuthController>(
          create: (context) =>
              AdminAuthController(context.read<AdminAuthRepository>()),
        ),
        ChangeNotifierProxyProvider2<
          AdminAuthController,
          AdminRepository,
          AdminSessionController
        >(
          create: (context) =>
              AdminSessionController(context.read<AdminRepository>()),
          update: (_, auth, repository, controller) {
            final resolved = controller ?? AdminSessionController(repository);
            resolved.bindAuth(auth);
            return resolved;
          },
        ),
      ],
      child: MaterialApp(
        title: '8UP Admin',
        debugShowCheckedModeBanner: false,
        theme: _adminTheme(),
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _AdminRoot(),
      ),
    );
  }
}

ThemeData _adminTheme() {
  final base = AppTheme.light();
  final textTheme = base.textTheme;
  final adminTextTheme = textTheme.copyWith(
    headlineSmall: textTheme.headlineSmall?.copyWith(
      fontSize: 18.1,
      height: 1.16,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: textTheme.titleLarge?.copyWith(
      fontSize: 17.1,
      height: 1.16,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: textTheme.titleMedium?.copyWith(
      fontSize: 15.1,
      height: 1.2,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: textTheme.titleSmall?.copyWith(
      fontSize: 14.4,
      height: 1.18,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: textTheme.bodyMedium?.copyWith(
      fontSize: 15.1,
      height: 1.3,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: textTheme.bodySmall?.copyWith(
      fontSize: 13.1,
      height: 1.24,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: textTheme.labelLarge?.copyWith(
      fontSize: 13.1,
      height: 1.16,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: textTheme.labelMedium?.copyWith(
      fontSize: 12.1,
      height: 1.14,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: textTheme.labelSmall?.copyWith(
      fontSize: 11.1,
      height: 1.08,
      fontWeight: FontWeight.w500,
    ),
  );

  return base.copyWith(
    textTheme: adminTextTheme,
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      labelStyle: adminTextTheme.bodySmall?.copyWith(
        color: AppColors.subtle,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: adminTextTheme.labelMedium?.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: adminTextTheme.bodySmall?.copyWith(
        color: AppColors.subtle,
        fontWeight: FontWeight.w400,
      ),
      helperStyle: adminTextTheme.bodySmall?.copyWith(
        color: AppColors.subtle,
        fontWeight: FontWeight.w400,
      ),
      prefixStyle: adminTextTheme.bodyMedium?.copyWith(
        color: AppColors.title,
        fontWeight: FontWeight.w400,
      ),
      suffixStyle: adminTextTheme.bodySmall?.copyWith(
        color: AppColors.subtle,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class _AdminRoot extends StatelessWidget {
  const _AdminRoot();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AdminAuthController>();
    final session = context.watch<AdminSessionController>();

    if (!auth.isAuthenticated) {
      return const _AdminLoginScreen();
    }

    if (auth.isPasswordRecovery) {
      return const _AdminPasswordRecoveryScreen();
    }

    if (session.isLoading &&
        session.profile == null &&
        session.platformProfile == null) {
      return const Scaffold(body: SafeArea(child: LoadingSection()));
    }

    if (session.error != null &&
        session.profile == null &&
        session.platformProfile == null) {
      return Scaffold(
        body: SafeArea(
          child: AppViewport(
            maxWidth: 760,
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '관리자 정보를 불러오지 못했습니다',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(session.error!),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton.tonal(
                        onPressed: session.refresh,
                        child: const Text('다시 시도'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () {
                          context.read<AdminAuthController>().signOut();
                        },
                        child: const Text('로그아웃'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (session.platformProfile != null) {
      return const _PlatformAdminShell();
    }

    if (session.profile == null) {
      return Scaffold(
        body: SafeArea(
          child: AppViewport(
            maxWidth: 760,
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '관리자 계정이 아닙니다',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('관리자 웹은 스튜디오 관리자 계정으로만 사용할 수 있습니다.'),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () {
                      context.read<AdminAuthController>().signOut();
                    },
                    child: const Text('로그아웃'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const _AdminShell();
  }
}

class _AdminLoginScreen extends StatefulWidget {
  const _AdminLoginScreen();

  @override
  State<_AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<_AdminLoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AdminAuthController>();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AppViewport(
              maxWidth: 1240,
              padding: EdgeInsets.zero,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: AppColors.surface.withValues(
                                    alpha: 0.88,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppColors.onPrimary.withValues(
                                      alpha: 0.32,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.10,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.asset(
                                  kBrandIconAssetPath,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '8UP Admin',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            color: AppColors.onPrimary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Studio Operations Console',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: AppColors.onPrimary
                                                .withValues(alpha: 0.82),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '성인 취미 스튜디오의 운영을 웹에서 관리하세요.',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppColors.onPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '처음 세팅부터 월간 운영까지, 필요한 작업 흐름을 순서대로 정리했습니다.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: AppColors.onPrimary.withValues(
                                    alpha: 0.92,
                                  ),
                                  height: 1.6,
                                ),
                          ),
                          const SizedBox(height: 24),
                          const _AdminGuideSection(
                            number: '1',
                            title: '수업 관리',
                            items: [
                              _AdminGuideItem(
                                title: '수업 등록',
                                description: '지금 운영 중인 수업을 수업 템플릿에 등록하세요.',
                              ),
                              _AdminGuideItem(
                                title: '수업 개설',
                                description: '다음 달 운영할 수업들을 원클릭으로 일괄 등록하세요.',
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const _AdminGuideSection(
                            number: '2',
                            title: '수강권 운영',
                            items: [
                              _AdminGuideItem(
                                title: '수강권 상품 등록',
                                description: '운영 중인 수업 템플릿을 연결해 수강권 상품을 등록하세요.',
                              ),
                              _AdminGuideItem(
                                title: '학생에게 수강권 발급',
                                description:
                                    '학생의 ID로 쉽게 수강권을 발급하세요. 학생은 발급받은 수강권으로 예약 가능한 수업을 달력에서 확인하고 신청할 수 있습니다.',
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const _AdminGuideSection(
                            number: '3',
                            title: '스튜디오 운영 관리',
                            items: [
                              _AdminGuideItem(
                                title: '대시보드 확인',
                                description:
                                    '대시보드에서 수업 진행률, 매출, 등록 인원 등 운영 현황을 한눈에 확인하세요.',
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '새 스튜디오 관리자 등록',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: AppColors.onPrimary.withValues(
                                    alpha: 0.82,
                                  ),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.onPrimary.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.onPrimary.withValues(
                                  alpha: 0.14,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '등록 요청 후 8UP 관리자 승인 시 사용 가능합니다.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.onPrimary.withValues(
                                          alpha: 0.94,
                                        ),
                                        height: 1.5,
                                      ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.tonalIcon(
                                    onPressed: auth.isBusy
                                        ? null
                                        : _startAdminSignUp,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.surface
                                          .withValues(alpha: 0.9),
                                      foregroundColor: AppColors.primaryStrong,
                                    ),
                                    icon: const Icon(Icons.storefront_rounded),
                                    label: const Text('새 스튜디오 등록 요청'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 420,
                    child: SurfaceCard(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '스튜디오 로그인',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '스튜디오 ID 로 로그인 하세요.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.subtle),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _identifierController,
                            decoration: const InputDecoration(
                              labelText: '스튜디오 ID',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: '비밀번호',
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: auth.isBusy ? null : _submit,
                              child: Text(auth.isBusy ? '로그인 중...' : '로그인'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(
                                '비밀번호를 잃어버리셨습니까?',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.subtle),
                              ),
                              TextButton(
                                onPressed: auth.isBusy
                                    ? null
                                    : _showPasswordSupportGuide,
                                child: const Text('문의하기'),
                              ),
                            ],
                          ),
                          if (auth.error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              auth.error!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.errorForeground),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final auth = context.read<AdminAuthController>();
    try {
      await auth.signIn(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, auth.error ?? '로그인에 실패했습니다.', isError: true);
    }
  }

  Future<void> _showPasswordSupportGuide() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _AdminPasswordSupportDialog(),
    );
  }

  Future<void> _startAdminSignUp() async {
    final request = await showDialog<_AdminSignupRequest>(
      context: context,
      builder: (_) => const _AdminSignupDialog(),
    );
    if (!mounted || request == null) {
      return;
    }

    final auth = context.read<AdminAuthController>();
    try {
      await auth.signUpStudioAdmin(
        studioName: request.studioName,
        studioPhone: request.studioPhone,
        studioAddress: request.studioAddress,
        adminName: request.adminName,
        loginId: request.loginId,
        email: request.email,
        password: request.password,
      );
      if (!mounted) {
        return;
      }
      _identifierController.text = request.loginId;
      _passwordController.clear();
      showAppSnackBar(context, '등록 요청이 접수되었습니다. 8UP 관리자 승인 후 로그인할 수 있습니다.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        auth.error ?? '스튜디오 등록 요청에 실패했습니다.',
        isError: true,
      );
    }
  }
}

class _AdminPasswordRecoveryScreen extends StatefulWidget {
  const _AdminPasswordRecoveryScreen();

  @override
  State<_AdminPasswordRecoveryScreen> createState() =>
      _AdminPasswordRecoveryScreenState();
}

class _AdminPasswordRecoveryScreenState
    extends State<_AdminPasswordRecoveryScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AdminAuthController>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: AppViewport(
            maxWidth: 520,
            child: SurfaceCard(
              padding: const EdgeInsets.all(28),
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  _passwordController,
                  _confirmPasswordController,
                ]),
                builder: (context, _) {
                  final passwordsMatch =
                      _passwordController.text.isNotEmpty &&
                      _passwordController.text ==
                          _confirmPasswordController.text;
                  final canSubmit =
                      !auth.isBusy &&
                      _passwordController.text.length >= 6 &&
                      passwordsMatch;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '새 관리자 비밀번호 설정',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '이메일에서 연 복구 링크로 새 비밀번호를 저장하세요.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.subtle,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: '새 비밀번호'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: '새 비밀번호 확인',
                          helperText:
                              _confirmPasswordController.text.isNotEmpty &&
                                  !passwordsMatch
                              ? '비밀번호가 일치해야 합니다.'
                              : ' ',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: canSubmit ? _submit : null,
                        child: auth.isBusy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('비밀번호 저장'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final auth = context.read<AdminAuthController>();
    final password = _passwordController.text.trim();
    if (password.length < 6) {
      showAppSnackBar(context, '비밀번호는 6자 이상이어야 합니다.', isError: true);
      return;
    }
    if (password != _confirmPasswordController.text.trim()) {
      showAppSnackBar(context, '비밀번호가 일치하지 않습니다.', isError: true);
      return;
    }
    try {
      await auth.updatePassword(password: password);
      auth.clearRecoveryMode();
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, '비밀번호가 변경되었습니다.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, auth.error ?? '비밀번호 변경에 실패했습니다.', isError: true);
    }
  }
}

class _AdminPasswordSupportDialog extends StatelessWidget {
  const _AdminPasswordSupportDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '비밀번호 문의',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '비밀번호 재설정은 자동 발급하지 않습니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
              ),
              child: SelectableText(
                _supportEmailAddress,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryStrong,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '위 이메일 주소로 스튜디오명과 로그인 ID를 함께 보내주시면 확인 후 안내드립니다.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('확인'),
        ),
      ],
    );
  }
}

class _AdminSignupRequest {
  const _AdminSignupRequest({
    required this.studioName,
    required this.studioPhone,
    required this.studioAddress,
    required this.adminName,
    required this.loginId,
    required this.email,
    required this.password,
  });

  final String studioName;
  final String studioPhone;
  final String studioAddress;
  final String adminName;
  final String loginId;
  final String email;
  final String password;
}

class _AdminSignupDialog extends StatefulWidget {
  const _AdminSignupDialog();

  @override
  State<_AdminSignupDialog> createState() => _AdminSignupDialogState();
}

class _AdminSignupDialogState extends State<_AdminSignupDialog> {
  static final RegExp _loginIdPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{2,31}$');
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final TextEditingController _studioNameController = TextEditingController();
  final TextEditingController _studioPhoneController = TextEditingController(
    text: Formatters.editablePhone(),
  );
  final TextEditingController _studioAddressController =
      TextEditingController();
  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool get _isStudioNameValid => _studioNameController.text.trim().isNotEmpty;

  bool get _isStudioPhoneValid {
    return Formatters.isMobilePhone(_studioPhoneController.text);
  }

  bool get _isStudioAddressValid =>
      _studioAddressController.text.trim().isNotEmpty;

  bool get _isAdminNameValid => _adminNameController.text.trim().isNotEmpty;

  bool get _isLoginIdValid =>
      _loginIdPattern.hasMatch(_loginIdController.text.trim().toLowerCase());

  bool get _isEmailValid =>
      _emailPattern.hasMatch(_emailController.text.trim().toLowerCase());

  bool get _isPasswordValid => _passwordController.text.length >= 6;

  bool get _isConfirmPasswordValid =>
      _confirmPasswordController.text.isNotEmpty &&
      _confirmPasswordController.text == _passwordController.text;

  bool get _canSubmit =>
      _isStudioNameValid &&
      _isStudioPhoneValid &&
      _isStudioAddressValid &&
      _isAdminNameValid &&
      _isLoginIdValid &&
      _isEmailValid &&
      _isPasswordValid &&
      _isConfirmPasswordValid;

  void _handleFieldChanged(String _) {
    setState(() {});
  }

  @override
  void dispose() {
    _studioNameController.dispose();
    _studioPhoneController.dispose();
    _studioAddressController.dispose();
    _adminNameController.dispose();
    _loginIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '새 스튜디오 등록 요청',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _studioNameController,
                decoration: const InputDecoration(
                  labelText: '스튜디오명',
                  helperText: '*이 항목은 이후 변경 불가합니다',
                  helperStyle: TextStyle(color: AppColors.errorForeground),
                ),
                onChanged: _handleFieldChanged,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _studioPhoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: const [KoreanMobilePhoneTextInputFormatter()],
                decoration: InputDecoration(
                  labelText: '스튜디오 핸드폰 번호',
                  helperText: _isStudioPhoneValid
                      ? null
                      : '핸드폰 번호를 올바른 양식으로 입력하세요. (010-1234-5678)',
                ),
                onChanged: _handleFieldChanged,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _studioAddressController,
                decoration: const InputDecoration(labelText: '스튜디오 주소'),
                maxLines: 2,
                onChanged: _handleFieldChanged,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _adminNameController,
                decoration: const InputDecoration(labelText: '스튜디오 대표'),
                onChanged: _handleFieldChanged,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _loginIdController,
                decoration: const InputDecoration(
                  labelText: '스튜디오 ID (로그인 시 ID)',
                  helperText: '*이 항목은 이후 변경 불가합니다',
                  helperStyle: TextStyle(color: AppColors.errorForeground),
                ),
                autocorrect: false,
                enableSuggestions: false,
                onChanged: _handleFieldChanged,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '스튜디오 이메일'),
                autocorrect: false,
                enableSuggestions: false,
                onChanged: _handleFieldChanged,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호'),
                onChanged: _handleFieldChanged,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호 확인'),
                onChanged: _handleFieldChanged,
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text('등록 요청'),
        ),
      ],
    );
  }

  void _submit() {
    final studioName = _studioNameController.text.trim();
    final studioPhone = Formatters.storagePhone(_studioPhoneController.text);
    final studioAddress = _studioAddressController.text.trim();
    final adminName = _adminNameController.text.trim();
    final loginId = _loginIdController.text.trim().toLowerCase();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (studioName.isEmpty ||
        studioPhone.isEmpty ||
        studioAddress.isEmpty ||
        adminName.isEmpty ||
        loginId.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      showAppSnackBar(context, '모든 항목을 입력해 주세요.', isError: true);
      return;
    }
    if (!_isStudioPhoneValid) {
      showAppSnackBar(context, '핸드폰 번호를 올바른 양식으로 입력해 주세요.', isError: true);
      return;
    }
    if (!_isLoginIdValid) {
      showAppSnackBar(
        context,
        '로그인 ID는 영문 소문자/숫자로 시작하는 3~32자 형식이어야 합니다.',
        isError: true,
      );
      return;
    }
    if (!_isEmailValid) {
      showAppSnackBar(context, '이메일 형식을 확인해 주세요.', isError: true);
      return;
    }
    if (password.length < 6) {
      showAppSnackBar(context, '비밀번호는 6자 이상이어야 합니다.', isError: true);
      return;
    }
    if (password != confirmPassword) {
      showAppSnackBar(context, '비밀번호가 일치하지 않습니다.', isError: true);
      return;
    }

    Navigator.of(context).pop(
      _AdminSignupRequest(
        studioName: studioName,
        studioPhone: studioPhone,
        studioAddress: studioAddress,
        adminName: adminName,
        loginId: loginId,
        email: email,
        password: password,
      ),
    );
  }
}

class _AdminGuideSection extends StatelessWidget {
  const _AdminGuideSection({
    required this.number,
    required this.title,
    required this.items,
  });

  final String number;
  final String title;
  final List<_AdminGuideItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.onPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.onPrimary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.onPrimary,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primaryStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < items.length; i++) ...[
            _AdminGuideRow(item: items[i]),
            if (i != items.length - 1) ...[
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: AppColors.onPrimary.withValues(alpha: 0.18),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _AdminGuideRow extends StatelessWidget {
  const _AdminGuideRow({required this.item});

  final _AdminGuideItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.onPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          item.description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.onPrimary.withValues(alpha: 0.92),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _AdminGuideItem {
  const _AdminGuideItem({required this.title, required this.description});

  final String title;
  final String description;
}

class _AdminBrandMark extends StatelessWidget {
  const _AdminBrandMark({this.subtitle = 'Studio Admin'});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(kBrandIconAssetPath, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '8UP',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.subtle,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlatformAdminShell extends StatelessWidget {
  const _PlatformAdminShell();

  static const _destination = _AdminDestination(
    label: '플랫폼 대시보드',
    subtitle: '신규 요청과 전체 현황',
    icon: Icons.admin_panel_settings_rounded,
  );

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSessionController>();
    final auth = context.watch<AdminAuthController>();
    final profile = session.platformProfile!;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 0, 20),
              child: SizedBox(
                width: 300,
                child: SurfaceCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _AdminBrandMark(subtitle: 'Platform Admin'),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '8UP 관리자',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: AppColors.onPrimary.withValues(
                                      alpha: 0.92,
                                    ),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              profile.name ?? '8UP Platform Admin',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppColors.onPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              profile.loginId,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.onPrimary.withValues(
                                      alpha: 0.9,
                                    ),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            if (profile.email?.isNotEmpty == true) ...[
                              const SizedBox(height: 10),
                              Text(
                                profile.email!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.onPrimary.withValues(
                                        alpha: 0.88,
                                      ),
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _AdminNavButton(
                        destination: _destination,
                        selected: true,
                        onTap: _noop,
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        onPressed: auth.signOut,
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
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1380),
                    child: const _PlatformDashboardPage(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _noop() {}

class _PlatformDashboardPage extends StatefulWidget {
  const _PlatformDashboardPage();

  @override
  State<_PlatformDashboardPage> createState() => _PlatformDashboardPageState();
}

class _PlatformDashboardPageState extends State<_PlatformDashboardPage> {
  List<StudioSignupRequest> _pendingRequests = const [];
  List<PlatformStudioOverview> _studioOverviews = const [];
  bool _loading = false;
  String? _error;
  String? _platformAdminId;
  String? _processingRequestId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final platformAdminId = context
        .read<AdminSessionController>()
        .platformProfile
        ?.id;
    if (platformAdminId != null && platformAdminId != _platformAdminId) {
      _platformAdminId = platformAdminId;
      Future<void>.microtask(_refresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMonthSales = _studioOverviews.fold<double>(
      0,
      (sum, item) => sum + item.monthSalesAmount,
    );
    final totalTemplateCount = _studioOverviews.fold<int>(
      0,
      (sum, item) => sum + item.templateCount,
    );
    final totalMonthSessions = _studioOverviews.fold<int>(
      0,
      (sum, item) => sum + item.monthSessionCount,
    );
    final totalInstructors = _studioOverviews.fold<int>(
      0,
      (sum, item) => sum + item.instructorCount,
    );
    final totalMembers = _studioOverviews.fold<int>(
      0,
      (sum, item) => sum + item.memberCount,
    );
    final totalIssuedPasses = _studioOverviews.fold<int>(
      0,
      (sum, item) => sum + item.issuedPassCount,
    );

    return _AdminPageFrame(
      title: '8UP 관리자',
      subtitle: '신규 스튜디오 등록 요청과 전체 스튜디오 운영 현황을 확인합니다.',
      trailing: FilledButton.tonalIcon(
        onPressed: _loading ? null : _refresh,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('새로고침'),
      ),
      child:
          _error != null && _pendingRequests.isEmpty && _studioOverviews.isEmpty
          ? ErrorSection(message: _error!, onRetry: _refresh)
          : _loading && _pendingRequests.isEmpty && _studioOverviews.isEmpty
          ? const LoadingSection()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _DashboardSectionHeading(
                  icon: Icons.grid_view_rounded,
                  title: 'Platform Overview',
                  description: '승인 대기 요청과 전체 스튜디오 운영 규모를 먼저 확인합니다.',
                ),
                const SizedBox(height: 12),
                SurfaceCard(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _MetricCard(
                        label: '승인 대기 요청',
                        value: '${_pendingRequests.length}건',
                        note: '신규 등록 요청',
                      ),
                      _MetricCard(
                        label: '운영 스튜디오',
                        value: '${_studioOverviews.length}곳',
                        note: '승인 완료 기준',
                      ),
                      _MetricCard(
                        label: '전체 수업 템플릿',
                        value: '$totalTemplateCount',
                        note: '현재 활성 템플릿 합계',
                      ),
                      _MetricCard(
                        label: '이번달 총 수업 수',
                        value: '$totalMonthSessions',
                        note: '전체 스튜디오 합계',
                      ),
                      _MetricCard(
                        label: '등록 강사 수',
                        value: '$totalInstructors',
                        note: '전체 스튜디오 합계',
                      ),
                      _MetricCard(
                        label: '등록 회원 수',
                        value: '$totalMembers',
                        note: '전체 스튜디오 합계',
                      ),
                      _MetricCard(
                        label: '발급 수강권 수',
                        value: '$totalIssuedPasses',
                        note: '전체 누적 발급',
                      ),
                      _MetricCard(
                        label: '이번달 총 매출',
                        value: _currency(totalMonthSales),
                        note: '전체 스튜디오 합계',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _DashboardSectionHeading(
                  icon: Icons.mark_email_unread_rounded,
                  title: '신규 스튜디오 등록 요청',
                  description: '승인 전에는 스튜디오 로그인이 불가능합니다.',
                ),
                const SizedBox(height: 12),
                SurfaceCard(
                  child: _pendingRequests.isEmpty
                      ? const Text('신규 스튜디오 등록 요청이 없습니다.')
                      : Column(
                          children: [
                            for (
                              var i = 0;
                              i < _pendingRequests.length;
                              i++
                            ) ...[
                              _PlatformSignupRequestCard(
                                request: _pendingRequests[i],
                                processing:
                                    _processingRequestId ==
                                    _pendingRequests[i].id,
                                onApprove: () =>
                                    _approveRequest(_pendingRequests[i]),
                                onReject: () =>
                                    _rejectRequest(_pendingRequests[i]),
                              ),
                              if (i != _pendingRequests.length - 1) ...[
                                const SizedBox(height: 18),
                                const Divider(height: 1),
                                const SizedBox(height: 18),
                              ],
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 24),
                const _DashboardSectionHeading(
                  icon: Icons.apartment_rounded,
                  title: '스튜디오 운영 현황',
                  description: '스튜디오별 운영 규모와 이번달 핵심 지표를 확인합니다.',
                ),
                const SizedBox(height: 12),
                if (_studioOverviews.isEmpty)
                  const SurfaceCard(child: Text('승인 완료된 스튜디오가 아직 없습니다.'))
                else
                  Column(
                    children: [
                      for (var i = 0; i < _studioOverviews.length; i++) ...[
                        _PlatformStudioOverviewCard(
                          overview: _studioOverviews[i],
                        ),
                        if (i != _studioOverviews.length - 1)
                          const SizedBox(height: 14),
                      ],
                    ],
                  ),
              ],
            ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repository = context.read<AdminRepository>();
      final results = await Future.wait([
        repository.fetchPendingStudioSignupRequests(),
        repository.fetchPlatformStudioOverviews(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingRequests = results[0] as List<StudioSignupRequest>;
        _studioOverviews = results[1] as List<PlatformStudioOverview>;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = ErrorText.format(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _approveRequest(StudioSignupRequest request) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: _AdminDialogTitle(
          title: '스튜디오 등록 승인',
          onClose: () => Navigator.of(dialogContext).pop(false),
        ),
        content: Text(
          '${request.studioName} 등록 요청을 승인하시겠습니까?\n승인하면 스튜디오와 로그인 계정이 바로 생성됩니다.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('승인'),
          ),
        ],
      ),
    );

    if (approved != true || !mounted) {
      return;
    }

    setState(() {
      _processingRequestId = request.id;
    });

    try {
      await context.read<AdminRepository>().approveStudioSignupRequest(
        request.id,
      );
      if (!mounted) {
        return;
      }
      await _refresh();
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, '${request.studioName} 등록을 승인했습니다.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, ErrorText.format(error), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestId = null;
        });
      }
    }
  }

  Future<void> _rejectRequest(StudioSignupRequest request) async {
    final reviewComment = await showDialog<String?>(
      context: context,
      builder: (dialogContext) =>
          _StudioSignupRejectDialog(studioName: request.studioName),
    );

    if (reviewComment == null || !mounted) {
      return;
    }

    setState(() {
      _processingRequestId = request.id;
    });

    try {
      await context.read<AdminRepository>().rejectStudioSignupRequest(
        request.id,
        reviewComment: reviewComment,
      );
      if (!mounted) {
        return;
      }
      await _refresh();
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, '${request.studioName} 등록 요청을 반려했습니다.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, ErrorText.format(error), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestId = null;
        });
      }
    }
  }
}

class _PlatformSignupRequestCard extends StatelessWidget {
  const _PlatformSignupRequestCard({
    required this.request,
    required this.processing,
    required this.onApprove,
    required this.onReject,
  });

  final StudioSignupRequest request;
  final bool processing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.studioName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '스튜디오 대표 ${request.representativeName}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.body,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const StatusPill(
              label: '승인 대기',
              backgroundColor: AppColors.waitlistBackground,
              foregroundColor: AppColors.waitlistForeground,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _PlatformInfoItem(
              label: '스튜디오 ID',
              value: request.requestedLoginId,
            ),
            _PlatformInfoItem(label: '스튜디오 이메일', value: request.requestedEmail),
            _PlatformInfoItem(
              label: '스튜디오 핸드폰 번호',
              value: Formatters.phone(request.studioPhone),
            ),
            _PlatformInfoItem(
              label: '요청일',
              value: Formatters.date(request.createdAt.toLocal()),
            ),
          ],
        ),
        if (request.studioAddress.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            request.studioAddress,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.body,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 130,
              child: ElevatedButton.icon(
                onPressed: processing ? null : onApprove,
                icon: const Icon(Icons.check_rounded),
                label: Text(processing ? '처리 중...' : '승인'),
              ),
            ),
            SizedBox(
              width: 130,
              child: FilledButton.tonalIcon(
                onPressed: processing ? null : onReject,
                icon: const Icon(Icons.close_rounded),
                label: const Text('반려'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlatformStudioOverviewCard extends StatelessWidget {
  const _PlatformStudioOverviewCard({required this.overview});

  final PlatformStudioOverview overview;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overview.studioName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      overview.representativeName?.isNotEmpty == true
                          ? '대표 ${overview.representativeName}'
                          : '대표 정보 없음',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.body,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (overview.studioLoginId?.isNotEmpty == true)
                StatusPill(
                  label: overview.studioLoginId!,
                  backgroundColor: AppColors.infoBackground,
                  foregroundColor: AppColors.infoForeground,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DashboardStatChip(
                label: '수업 템플릿 수',
                value: '${overview.templateCount}',
              ),
              _DashboardStatChip(
                label: '이번달 수업 수',
                value: '${overview.monthSessionCount}',
              ),
              _DashboardStatChip(
                label: '등록 강사 수',
                value: '${overview.instructorCount}',
              ),
              _DashboardStatChip(
                label: '등록 회원 수',
                value: '${overview.memberCount}',
              ),
              _DashboardStatChip(
                label: '발급 수강권 수',
                value: '${overview.issuedPassCount}',
              ),
              _DashboardStatChip(
                label: '이번달 매출',
                value: _currency(overview.monthSalesAmount),
              ),
            ],
          ),
          if (overview.studioPhone?.isNotEmpty == true ||
              overview.representativeEmail?.isNotEmpty == true ||
              overview.studioAddress?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (overview.representativeEmail?.isNotEmpty == true)
                  _PlatformInfoItem(
                    label: '스튜디오 이메일',
                    value: overview.representativeEmail!,
                  ),
                if (overview.studioPhone?.isNotEmpty == true)
                  _PlatformInfoItem(
                    label: '스튜디오 핸드폰 번호',
                    value: Formatters.phone(overview.studioPhone),
                  ),
              ],
            ),
            if (overview.studioAddress?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                overview.studioAddress!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.body,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PlatformInfoItem extends StatelessWidget {
  const _PlatformInfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.subtle,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioSignupRejectDialog extends StatefulWidget {
  const _StudioSignupRejectDialog({required this.studioName});

  final String studioName;

  @override
  State<_StudioSignupRejectDialog> createState() =>
      _StudioSignupRejectDialogState();
}

class _StudioSignupRejectDialogState extends State<_StudioSignupRejectDialog> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '등록 요청 반려',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.studioName} 등록 요청을 반려합니다.'),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '반려 사유',
                hintText: '필요하면 사유를 남겨주세요.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton.tonal(
          onPressed: () =>
              Navigator.of(context).pop(_commentController.text.trim()),
          child: const Text('반려'),
        ),
      ],
    );
  }
}

class _AdminShell extends StatefulWidget {
  const _AdminShell();

  @override
  State<_AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<_AdminShell> {
  int _index = 0;
  DateTime? _sessionTargetDate;
  int _sessionTargetNonce = 0;
  String? _attentionStudioId;
  int _pendingWaitlistRequestCount = 0;
  int _pendingCancelRequestCount = 0;

  static const _destinations = [
    _AdminDestination(
      label: '대시보드',
      subtitle: '오늘 운영 요약',
      icon: Icons.space_dashboard_rounded,
    ),
    _AdminDestination(
      label: '콘텐츠 관리',
      subtitle: '공지와 이벤트',
      icon: Icons.campaign_rounded,
    ),
    _AdminDestination(
      label: '강사 관리',
      subtitle: '강사 등록과 배정',
      icon: Icons.badge_rounded,
    ),
    _AdminDestination(
      label: '수업 템플릿',
      subtitle: '반복 수업 규칙',
      icon: Icons.view_week_rounded,
    ),
    _AdminDestination(
      label: '수업 관리',
      subtitle: '회차 개설과 배정',
      icon: Icons.calendar_month_rounded,
    ),
    _AdminDestination(
      label: '수강권 상품',
      subtitle: '판매 상품 설정',
      icon: Icons.confirmation_num_rounded,
    ),
    _AdminDestination(
      label: '회원 관리',
      subtitle: '회원 연결과 발급',
      icon: Icons.groups_rounded,
    ),
    _AdminDestination(
      label: '취소 관리',
      subtitle: '취소 정책/요청 처리',
      icon: Icons.pending_actions_rounded,
    ),
    _AdminDestination(
      label: '사용법 설명',
      subtitle: '운영 흐름 가이드',
      icon: Icons.menu_book_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSessionController>();
    final auth = context.watch<AdminAuthController>();
    final profile = session.profile!;
    if (profile.studioId != _attentionStudioId) {
      _attentionStudioId = profile.studioId;
      _scheduleAttentionRefresh();
    }
    final screens = [
      _DashboardPage(
        onOpenCancelRequests: () => _setIndex(7),
        onOpenSessionsForDay: _openSessionsForDay,
      ),
      const _ContentPage(),
      _InstructorsPage(isActive: _index == 2),
      _TemplatesPage(isActive: _index == 3),
      _SessionsPage(
        isActive: _index == 4,
        targetDate: _sessionTargetDate,
        navigationNonce: _sessionTargetNonce,
        onAttentionChanged: _scheduleAttentionRefresh,
      ),
      _PassProductsPage(isActive: _index == 5),
      _MembersPage(isActive: _index == 6),
      _CancelRequestsPage(
        isActive: _index == 7,
        onAttentionChanged: _scheduleAttentionRefresh,
      ),
      const _AdminGuidePage(),
    ];

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 0, 20),
              child: SizedBox(
                width: 300,
                child: SurfaceCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _AdminBrandMark(),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '스튜디오 정보',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: AppColors.onPrimary.withValues(
                                          alpha: 0.92,
                                        ),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () {
                                    _openStudioSettingsDialog(profile);
                                  },
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.onPrimary
                                        .withValues(alpha: 0.14),
                                    foregroundColor: AppColors.onPrimary,
                                  ),
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                  ),
                                  tooltip: '스튜디오 정보 수정',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StudioAvatar(
                                  name: profile.studio.name,
                                  imageUrl: profile.studio.imageUrl,
                                  size: 56,
                                  borderRadius: 999,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile.studio.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: AppColors.onPrimary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (profile.studio.address?.isNotEmpty == true ||
                                profile.studio.contactPhone?.isNotEmpty ==
                                    true) ...[
                              const SizedBox(height: 14),
                              if (profile.studio.address?.isNotEmpty == true)
                                Text(
                                  profile.studio.address!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.onPrimary.withValues(
                                          alpha: 0.88,
                                        ),
                                        height: 1.45,
                                      ),
                                ),
                              if (profile.studio.address?.isNotEmpty == true &&
                                  profile.studio.contactPhone?.isNotEmpty ==
                                      true)
                                const SizedBox(height: 6),
                              if (profile.studio.contactPhone?.isNotEmpty ==
                                  true)
                                Text(
                                  Formatters.phone(profile.studio.contactPhone),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.onPrimary.withValues(
                                          alpha: 0.88,
                                        ),
                                      ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _AdminNavButton(
                        destination: _destinations[0],
                        selected: _index == 0,
                        onTap: () => _setIndex(0),
                      ),
                      const SizedBox(height: 8),
                      _AdminNavButton(
                        destination: _destinations[1],
                        selected: _index == 1,
                        onTap: () => _setIndex(1),
                      ),
                      const SizedBox(height: 12),
                      _AdminNavButton(
                        destination: _destinations[2],
                        selected: _index == 2,
                        onTap: () => _setIndex(2),
                      ),
                      const SizedBox(height: 12),
                      _AdminNavGroup(
                        children: [
                          _AdminNavButton(
                            destination: _destinations[3],
                            selected: _index == 3,
                            onTap: () => _setIndex(3),
                          ),
                          const SizedBox(height: 8),
                          _AdminNavButton(
                            destination: _destinations[4],
                            selected: _index == 4,
                            onTap: () => _setIndex(4),
                            trailing: _pendingWaitlistRequestCount > 0
                                ? _AdminNavCountBadge(
                                    count: _pendingWaitlistRequestCount,
                                    backgroundColor:
                                        AppColors.waitlistBackground,
                                    foregroundColor:
                                        AppColors.waitlistForeground,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          _AdminNavButton(
                            destination: _destinations[7],
                            selected: _index == 7,
                            onTap: () => _setIndex(7),
                            trailing: _pendingCancelRequestCount > 0
                                ? _AdminNavCountBadge(
                                    count: _pendingCancelRequestCount,
                                    backgroundColor: AppColors.errorBackground,
                                    foregroundColor: AppColors.errorForeground,
                                  )
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _AdminNavGroup(
                        children: [
                          _AdminNavButton(
                            destination: _destinations[5],
                            selected: _index == 5,
                            onTap: () => _setIndex(5),
                          ),
                          const SizedBox(height: 8),
                          _AdminNavButton(
                            destination: _destinations[6],
                            selected: _index == 6,
                            onTap: () => _setIndex(6),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _AdminNavButton(
                        destination: _destinations[8],
                        selected: _index == 8,
                        onTap: () => _setIndex(8),
                      ),
                      const Spacer(),
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
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1380),
                    child: IndexedStack(index: _index, children: screens),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setIndex(int value) {
    setState(() {
      _index = value;
    });
  }

  void _openSessionsForDay(DateTime date) {
    setState(() {
      _sessionTargetDate = DateTime(date.year, date.month, date.day);
      _sessionTargetNonce += 1;
      _index = 4;
    });
  }

  void _scheduleAttentionRefresh() {
    Future<void>.microtask(_refreshAttentionCounts);
  }

  Future<void> _refreshAttentionCounts() async {
    final studioId = _attentionStudioId;
    if (studioId == null) {
      return;
    }

    try {
      final repository = context.read<AdminRepository>();
      final results = await Future.wait([
        repository.fetchPendingWaitlistRequestCount(studioId),
        repository.fetchPendingCancelRequestCount(studioId),
      ]);
      if (!mounted || studioId != _attentionStudioId) {
        return;
      }

      setState(() {
        _pendingWaitlistRequestCount = results[0];
        _pendingCancelRequestCount = results[1];
      });
    } catch (_) {
      if (!mounted || studioId != _attentionStudioId) {
        return;
      }

      setState(() {
        _pendingWaitlistRequestCount = 0;
        _pendingCancelRequestCount = 0;
      });
    }
  }

  Future<void> _openStudioSettingsDialog(AdminProfile profile) async {
    final repository = context.read<AdminRepository>();
    final authRepository = context.read<AdminAuthRepository>();
    final messenger = ScaffoldMessenger.of(context);

    final formData = await showDialog<_StudioSettingsFormData>(
      context: context,
      builder: (dialogContext) => _StudioSettingsDialog(profile: profile),
    );

    if (formData == null) {
      return;
    }

    try {
      await repository.updateStudioSettings(
        currentStudio: profile.studio,
        contactPhone: formData.contactPhone,
        address: formData.address,
        imageFile: formData.imageFile,
        removeImage: formData.removeImage,
        clearMustChangePassword: formData.password.trim().isNotEmpty,
      );
      if (formData.password.trim().isNotEmpty) {
        await authRepository.updatePassword(formData.password.trim());
      }
      if (!mounted) {
        return;
      }
      await context.read<AdminSessionController>().refresh();
      showAppSnackBarWithMessenger(messenger, '스튜디오 정보를 저장했습니다.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, error.toString(), isError: true);
    }
  }
}

class _AdminDestination {
  const _AdminDestination({
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  final String label;
  final String subtitle;
  final IconData icon;
}

class _AdminNavButton extends StatelessWidget {
  const _AdminNavButton({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final _AdminDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

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
            color: selected ? AppColors.infoBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                destination.icon,
                color: selected ? AppColors.primaryStrong : AppColors.subtle,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: selected
                            ? AppColors.primaryStrong
                            : AppColors.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destination.subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminNavCountBadge extends StatelessWidget {
  const _AdminNavCountBadge({
    required this.count,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final int count;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.28)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AdminNavGroup extends StatelessWidget {
  const _AdminNavGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _AdminPageFrame extends StatelessWidget {
  const _AdminPageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 20),
        child,
      ],
    );
  }
}

class _DashboardSectionHeading extends StatelessWidget {
  const _DashboardSectionHeading({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primarySoft.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Icon(icon, color: AppColors.primaryStrong, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardPage extends StatefulWidget {
  const _DashboardPage({
    required this.onOpenCancelRequests,
    required this.onOpenSessionsForDay,
  });

  final VoidCallback onOpenCancelRequests;
  final ValueChanged<DateTime> onOpenSessionsForDay;

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  AdminDashboardMetrics? _metrics;
  List<AdminMonthlyClassMetric> _classMetrics = const [];
  List<AdminMonthlyReservationSummary> _monthReservationSummaries = const [];
  int _monthSessionCount = 0;
  int _monthReservationCount = 0;
  bool _loading = false;
  String? _error;
  String? _studioId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final studioId = context.read<AdminSessionController>().profile?.studioId;
    if (studioId != null && studioId != _studioId) {
      _studioId = studioId;
      Future<void>.microtask(_refresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPageFrame(
      title: '대시보드',
      subtitle: '오늘 운영 상황과 확인이 필요한 요청을 빠르게 봅니다.',
      trailing: FilledButton.tonalIcon(
        onPressed: _loading ? null : _refresh,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('새로고침'),
      ),
      child: _error != null
          ? ErrorSection(message: _error!, onRetry: _refresh)
          : _loading && _metrics == null
          ? const LoadingSection()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _DashboardSectionHeading(
                  icon: Icons.grid_view_rounded,
                  title: 'Overview',
                  description: '오늘 운영 상황과 이번 달 핵심 지표를 빠르게 확인합니다.',
                ),
                const SizedBox(height: 12),
                SurfaceCard(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _MetricCard(
                        label: '이번달 총 수업 수',
                        value: '$_monthSessionCount',
                        note: '일정관리로 이동',
                        onTap: _openTodaySessions,
                      ),
                      _MetricCard(
                        label: '오늘 수업',
                        value: '${_metrics?.todaySessionCount ?? 0}',
                        note: '개설된 회차',
                        onTap: _openTodaySessions,
                      ),
                      _MetricCard(
                        label: '이번달 총 예약 수',
                        value: '$_monthReservationCount',
                        note: '완료 포함',
                        onTap: _showMonthlyReservationOverview,
                      ),
                      _MetricCard(
                        label: '이번 달 매출',
                        value: _currency(_metrics?.monthSalesAmount ?? 0),
                        note: _salesDeltaNote(),
                        onTap: _showSalesComparison,
                      ),
                      _MetricCard(
                        label: '이번 달 환불',
                        value: _currency(_metrics?.monthRefundAmount ?? 0),
                        note: _refundDeltaNote(),
                        onTap: _showRefundComparison,
                      ),
                      _MetricCard(
                        label: '이번달 운영중인 수강증',
                        value: '${_metrics?.operatingPassCount ?? 0}',
                        note: '오늘 기준 사용 중',
                        onTap: _showOperatingPasses,
                      ),
                      _MetricCard(
                        label: '이번달 만료 수강증',
                        value: '${_metrics?.expiringPassCount ?? 0}',
                        note: '이번달 만료 수강권',
                        onTap: _showExpiringPasses,
                      ),
                      _MetricCard(
                        label: '대기 취소 요청',
                        value: '${_metrics?.pendingCancelRequestCount ?? 0}',
                        note: '관리자 확인 필요',
                        onTap: widget.onOpenCancelRequests,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: _DashboardSectionHeading(
                        icon: Icons.view_timeline_rounded,
                        title: '이번 달 수업 운영',
                        description: '템플릿별 개설 횟수, 정원, 평균 예약 인원을 확인합니다.',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _classMetrics.isEmpty
                          ? null
                          : _showMonthlyTemplateOverview,
                      icon: const Icon(Icons.layers_rounded),
                      label: const Text('템플릿 보기'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_classMetrics.isEmpty)
                        const Text('이번 달 운영 중인 수업 데이터가 아직 없습니다.')
                      else
                        ..._classMetrics.map(
                          (metric) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          metric.className,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  _DashboardStatChip(
                                    label: '개설',
                                    value: '${metric.openedSessionCount}회',
                                  ),
                                  const SizedBox(width: 8),
                                  _DashboardStatChip(
                                    label: '정원',
                                    value: '${metric.capacity}명',
                                  ),
                                  const SizedBox(width: 8),
                                  _DashboardStatChip(
                                    label: '평균 예약',
                                    value:
                                        '${metric.avgReservedCount.toStringAsFixed(metric.avgReservedCount.truncateToDouble() == metric.avgReservedCount ? 0 : 1)}명',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _refresh() async {
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }
    final repository = context.read<AdminRepository>();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month);
      final monthEnd = DateTime(now.year, now.month + 1, 0);
      final results = await Future.wait([
        repository.fetchDashboardMetrics(),
        repository.fetchTemplates(studioId),
        repository.fetchSessions(
          studioId: studioId,
          startDate: monthStart,
          endDate: monthEnd,
        ),
        repository.fetchMonthlyReservationSummaries(
          studioId: studioId,
          startDate: monthStart,
          endDate: monthEnd,
        ),
      ]);
      if (!mounted) {
        return;
      }
      final templates = results[1] as List<AdminClassTemplate>;
      final sessions = results[2] as List<AdminSessionSchedule>;
      final reservationSummaries =
          results[3] as List<AdminMonthlyReservationSummary>;
      setState(() {
        _metrics = results[0] as AdminDashboardMetrics;
        _classMetrics = _buildMonthlyClassMetrics(templates, sessions);
        _monthSessionCount = sessions.length;
        _monthReservationSummaries = reservationSummaries
            .where((summary) => summary.reservationCount > 0)
            .toList(growable: false);
        _monthReservationCount = _monthReservationSummaries.fold(
          0,
          (sum, summary) => sum + summary.reservationCount,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _salesDeltaNote() {
    final metrics = _metrics;
    if (metrics == null) {
      return '발급 기준 합계';
    }

    final diff = metrics.monthSalesAmount - metrics.previousMonthSalesAmount;
    if (diff == 0) {
      return '전월과 동일';
    }

    final direction = diff > 0 ? '+' : '-';
    return '전월 대비 $direction${_currency(diff.abs())}';
  }

  String _refundDeltaNote() {
    final metrics = _metrics;
    if (metrics == null) {
      return '환불 로그 합계';
    }

    final diff = metrics.monthRefundAmount - metrics.previousMonthRefundAmount;
    if (diff == 0) {
      return '전월과 동일';
    }

    final direction = diff > 0 ? '+' : '-';
    return '전월 대비 $direction${_currency(diff.abs())}';
  }

  Future<void> _showSalesComparison() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _FinancialTrendDialog(
          title: '월 매출 비교',
          description: '월별 발급 매출 추이를 확인합니다.',
          metricLabel: '매출',
          color: AppColors.primaryStrong,
          future: context
              .read<AdminRepository>()
              .fetchMonthlyFinancialMetrics(),
          valueSelector: (metric) => metric.salesAmount,
        );
      },
    );
  }

  Future<void> _showRefundComparison() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _FinancialTrendDialog(
          title: '월 환불 비교',
          description: '월별 환불 금액 추이를 확인합니다.',
          metricLabel: '환불',
          color: AppColors.highlightForeground,
          future: context
              .read<AdminRepository>()
              .fetchMonthlyFinancialMetrics(),
          valueSelector: (metric) => metric.refundAmount,
        );
      },
    );
  }

  Future<void> _showOperatingPasses() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _DashboardPassesDialog(
        title: '이번달 운영중인 수강증',
        emptyMessage: '오늘 기준 운영중인 수강증이 없습니다.',
        errorMessage: '이번달 운영중인 수강증 정보를 불러오지 못했습니다.',
        passesFuture: context.read<AdminRepository>().fetchOperatingPasses(),
        detailBuilder: (pass) =>
            '사용기간 ${Formatters.date(pass.validFrom)} - ${Formatters.date(pass.validUntil)}',
      ),
    );
  }

  Future<void> _showExpiringPasses() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _DashboardPassesDialog(
        title: '이번달 만료 수강증',
        emptyMessage: '이번달 만료 수강증이 없습니다.',
        errorMessage: '이번달 만료 수강증 정보를 불러오지 못했습니다.',
        passesFuture: context.read<AdminRepository>().fetchExpiringPasses(),
        detailBuilder: (pass) =>
            '종료 ${Formatters.date(pass.validUntil)} · 잔여 ${pass.remainingCount}회 · 예정 ${pass.plannedCount}회',
        statusLabelBuilder: (pass) =>
            _daysUntilExpiryLabel(pass.daysUntilExpiry),
      ),
    );
  }

  void _openTodaySessions() {
    widget.onOpenSessionsForDay(DateTime.now());
  }

  Future<void> _showMonthlyTemplateOverview() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          _MonthlyTemplateOverviewDialog(metrics: _classMetrics),
    );
  }

  Future<void> _showMonthlyReservationOverview() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _MonthlyReservationOverviewDialog(
        summaries: _monthReservationSummaries,
        totalReservationCount: _monthReservationCount,
      ),
    );
  }

  List<AdminMonthlyClassMetric> _buildMonthlyClassMetrics(
    List<AdminClassTemplate> templates,
    List<AdminSessionSchedule> sessions,
  ) {
    final activeTemplates =
        templates
            .where((template) => template.status == 'active')
            .toList(growable: false)
          ..sort((left, right) => left.name.compareTo(right.name));
    final sessionsByTemplate = <String, List<AdminSessionSchedule>>{};
    for (final session in sessions) {
      sessionsByTemplate
          .putIfAbsent(session.classTemplateId, () => <AdminSessionSchedule>[])
          .add(session);
    }

    return activeTemplates
        .map((template) {
          final templateSessions =
              sessionsByTemplate[template.id] ?? const <AdminSessionSchedule>[];
          final openedCount = templateSessions.length;
          final averageReserved = openedCount == 0
              ? 0.0
              : templateSessions
                        .map((session) => session.reservedCount)
                        .reduce((left, right) => left + right) /
                    openedCount;
          return AdminMonthlyClassMetric(
            classTemplateId: template.id,
            studioId: template.studioId,
            className: template.name,
            category: template.category,
            capacity: template.capacity,
            openedSessionCount: openedCount,
            avgReservedCount: averageReserved,
          );
        })
        .where((metric) => metric.openedSessionCount > 0)
        .toList(growable: false);
  }
}

class _ContentPage extends StatefulWidget {
  const _ContentPage();

  @override
  State<_ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<_ContentPage> {
  List<AdminNotice> _notices = const [];
  List<AdminEvent> _events = const [];
  bool _loading = false;
  String? _error;
  String? _studioId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final studioId = context.read<AdminSessionController>().profile?.studioId;
    if (studioId != null && studioId != _studioId) {
      _studioId = studioId;
      Future<void>.microtask(_refresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPageFrame(
      title: '콘텐츠 관리',
      subtitle: '사용자 앱에 노출되는 공지사항과 이벤트의 공개 여부와 노출 기간을 관리합니다.',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonalIcon(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('새로고침'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _loading ? null : () => _openNoticeDialog(),
            icon: const Icon(Icons.campaign_rounded),
            label: const Text('새 공지'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _loading ? null : () => _openEventDialog(),
            child: const Text('새 이벤트'),
          ),
        ],
      ),
      child: _error != null
          ? ErrorSection(message: _error!, onRetry: _refresh)
          : _loading && _notices.isEmpty && _events.isEmpty
          ? const LoadingSection()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AdminContentSection(
                  title: '공지사항',
                  subtitle: '공개 여부와 노출 기간을 관리합니다.',
                  emptyTitle: '등록된 공지사항이 없습니다',
                  emptyDescription: '새 공지를 등록하면 사용자 앱 스튜디오 탭에 노출할 수 있습니다.',
                  children: _notices
                      .map(
                        (notice) => _AdminContentTile(
                          title: notice.title,
                          body: notice.body,
                          meta:
                              '노출 ${_contentWindowLabel(notice.visibleFrom, notice.visibleUntil)} · 수정 ${Formatters.date(notice.updatedAt)}',
                          badges: [
                            if (notice.isImportant)
                              const _ContentBadge(
                                label: '중요',
                                backgroundColor: AppColors.highlightBackground,
                                foregroundColor: AppColors.highlightForeground,
                              ),
                            _ContentBadge(
                              label: notice.isPublished ? '공개' : '비공개',
                              backgroundColor: notice.isPublished
                                  ? AppColors.infoBackground
                                  : AppColors.neutralBackground,
                              foregroundColor: notice.isPublished
                                  ? AppColors.infoForeground
                                  : AppColors.neutralForeground,
                            ),
                          ],
                          onEdit: () => _openNoticeDialog(notice: notice),
                          onDelete: () => _deleteNotice(notice),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 18),
                _AdminContentSection(
                  title: '이벤트',
                  subtitle: '사용자 앱에 노출할 이벤트를 관리합니다.',
                  emptyTitle: '등록된 이벤트가 없습니다',
                  emptyDescription: '새 이벤트를 등록하면 사용자 앱 스튜디오 탭에 노출할 수 있습니다.',
                  children: _events
                      .map(
                        (event) => _AdminContentTile(
                          title: event.title,
                          body: event.body,
                          meta:
                              '노출 ${_contentWindowLabel(event.visibleFrom, event.visibleUntil)} · 수정 ${Formatters.date(event.updatedAt)}',
                          badges: [
                            if (event.isImportant)
                              const _ContentBadge(
                                label: '중요',
                                backgroundColor: AppColors.highlightBackground,
                                foregroundColor: AppColors.highlightForeground,
                              ),
                            _ContentBadge(
                              label: event.isPublished ? '공개' : '비공개',
                              backgroundColor: event.isPublished
                                  ? AppColors.infoBackground
                                  : AppColors.neutralBackground,
                              foregroundColor: event.isPublished
                                  ? AppColors.infoForeground
                                  : AppColors.neutralForeground,
                            ),
                          ],
                          onEdit: () => _openEventDialog(event: event),
                          onDelete: () => _deleteEvent(event),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
    );
  }

  Future<void> _refresh() async {
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        context.read<AdminRepository>().fetchNotices(studioId),
        context.read<AdminRepository>().fetchEvents(studioId),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _notices = results[0] as List<AdminNotice>;
        _events = results[1] as List<AdminEvent>;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openNoticeDialog({AdminNotice? notice}) async {
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }
    final repository = context.read<AdminRepository>();

    final formData = await showDialog<_NoticeFormData>(
      context: context,
      builder: (dialogContext) => _NoticeDialog(initialValue: notice),
    );

    if (formData == null) {
      return;
    }

    try {
      await repository.saveNotice(
        id: notice?.id,
        studioId: studioId,
        title: formData.title,
        body: formData.body,
        isImportant: formData.isImportant,
        isPublished: formData.isPublished,
        status: formData.status,
        visibleFrom: formData.visibleFrom,
        visibleUntil: formData.visibleUntil,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, '공지사항을 저장했습니다.');
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, error.toString(), isError: true);
    }
  }

  Future<void> _openEventDialog({AdminEvent? event}) async {
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }
    final repository = context.read<AdminRepository>();

    final formData = await showDialog<_EventFormData>(
      context: context,
      builder: (dialogContext) => _EventDialog(initialValue: event),
    );

    if (formData == null) {
      return;
    }

    try {
      await repository.saveEvent(
        id: event?.id,
        studioId: studioId,
        title: formData.title,
        body: formData.body,
        isImportant: formData.isImportant,
        isPublished: formData.isPublished,
        status: formData.status,
        visibleFrom: formData.visibleFrom,
        visibleUntil: formData.visibleUntil,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, '이벤트를 저장했습니다.');
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, error.toString(), isError: true);
    }
  }

  Future<void> _deleteNotice(AdminNotice notice) async {
    final repository = context.read<AdminRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: _AdminDialogTitle(
          title: '공지 삭제',
          onClose: () => Navigator.of(dialogContext).pop(false),
        ),
        content: Text('`${notice.title}` 공지를 실제로 삭제하시겠습니까?'),
        actions: [
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('유지'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorForeground,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await repository.deleteNotice(id: notice.id);
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, '공지사항을 삭제했습니다.');
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, ErrorText.format(error), isError: true);
    }
  }

  Future<void> _deleteEvent(AdminEvent event) async {
    final repository = context.read<AdminRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: _AdminDialogTitle(
          title: '이벤트 삭제',
          onClose: () => Navigator.of(dialogContext).pop(false),
        ),
        content: Text('`${event.title}` 이벤트를 실제로 삭제하시겠습니까?'),
        actions: [
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('유지'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorForeground,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await repository.deleteEvent(id: event.id);
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, '이벤트를 삭제했습니다.');
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, ErrorText.format(error), isError: true);
    }
  }
}

class _TemplatesPage extends StatefulWidget {
  const _TemplatesPage({required this.isActive});

  final bool isActive;

  @override
  State<_TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<_TemplatesPage> {
  List<AdminClassTemplate> _templates = const [];
  List<AdminInstructor> _instructors = const [];
  List<AdminPassProduct> _products = const [];
  bool _loading = false;
  bool _showArchivedTemplates = false;
  String? _error;
  String? _studioId;

  List<AdminClassTemplate> get _activeTemplates => _templates
      .where(
        (template) => template.status == 'active' && template.category != '일회성',
      )
      .toList(growable: false);

  List<AdminClassTemplate> get _inactiveTemplates => _templates
      .where(
        (template) => template.status != 'active' || template.category == '일회성',
      )
      .toList(growable: false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final studioId = context.read<AdminSessionController>().profile?.studioId;
    if (studioId != null && studioId != _studioId) {
      _studioId = studioId;
      Future<void>.microtask(_refresh);
    }
  }

  @override
  void didUpdateWidget(covariant _TemplatesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      Future<void>.microtask(_refresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTemplates = _activeTemplates;
    final inactiveTemplates = _inactiveTemplates;

    return _AdminPageFrame(
      title: '수업 템플릿 관리',
      subtitle: '요일, 시간, 정원 기준으로 반복 수업 규칙을 등록하고, 수업 관리에서 사용할 템플릿만 활성화합니다.',
      trailing: FilledButton.icon(
        onPressed: _loading ? null : _openTemplateDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('새 템플릿'),
      ),
      child: _error != null
          ? ErrorSection(message: _error!, onRetry: _refresh)
          : _loading && _templates.isEmpty
          ? const LoadingSection()
          : _templates.isEmpty
          ? const EmptySection(
              title: '등록된 템플릿이 없습니다',
              description: '새 템플릿을 만들어 수업 개설에 사용하세요.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AdminStatusBucketSection(
                  title: '운영 중인 템플릿',
                  subtitle: '수업 관리에서 수업 개설 시 선택 가능한 템플릿입니다.',
                  emptyTitle: '운영 중인 템플릿이 없습니다',
                  emptyDescription: '필요한 템플릿을 활성화하면 수업 관리에서 바로 사용할 수 있습니다.',
                  children: activeTemplates
                      .map(_buildTemplateCard)
                      .toList(growable: false),
                ),
                const SizedBox(height: 18),
                _AdminStatusBucketSection(
                  title: '보관된 템플릿',
                  subtitle: '지금은 사용하지 않지만 나중에 다시 활성화할 수 있습니다.',
                  emptyTitle: '보관된 템플릿이 없습니다',
                  emptyDescription: '비활성화한 템플릿은 이 구역에 모여 보입니다.',
                  isCollapsed: !_showArchivedTemplates,
                  onToggleCollapsed: () {
                    setState(() {
                      _showArchivedTemplates = !_showArchivedTemplates;
                    });
                  },
                  children: inactiveTemplates
                      .map(_buildTemplateCard)
                      .toList(growable: false),
                ),
              ],
            ),
    );
  }

  Widget _buildTemplateCard(AdminClassTemplate template) {
    AdminInstructor? defaultInstructor;
    for (final instructor in _instructors) {
      if (instructor.id == template.defaultInstructorId) {
        defaultInstructor = instructor;
        break;
      }
    }
    final mappedProducts = _products
        .where((product) => product.allowedTemplateIds.contains(template.id))
        .toList(growable: false);
    final activeMappedProducts = mappedProducts
        .where((product) => product.status == 'active')
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          template.name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (template.category == '일회성') ...[
                          const SizedBox(width: 12),
                          const StatusPill(
                            label: '일회성 수업',
                            backgroundColor: AppColors.highlightBackground,
                            foregroundColor: AppColors.highlightForeground,
                          ),
                        ],
                        const SizedBox(width: 12),
                        _buildTemplateInfoTag(
                          '${_weekdayLabels(template.dayOfWeekMask)} · ${template.startTime} - ${template.endTime}',
                        ),
                        const SizedBox(width: 8),
                        _buildTemplateInfoTag('정원 ${template.capacity}명'),
                        const SizedBox(width: 8),
                        _buildTemplateInstructorTag(defaultInstructor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '노출 수강권:',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (mappedProducts.isEmpty)
                                Text(
                                  '연결된 수강권 상품이 없습니다. 현재는 회원 앱에서 이 수업이 보이지 않습니다.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.errorForeground,
                                        fontWeight: FontWeight.w700,
                                      ),
                                )
                              else ...[
                                ...mappedProducts.expand(
                                  (product) => [
                                    _buildTemplateProductChip(product),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                                if (activeMappedProducts.isEmpty)
                                  Text(
                                    '현재 앱 비노출',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.errorForeground,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                backgroundColor: template.status == 'active'
                    ? AppColors.infoBackground
                    : AppColors.neutralBackground,
                foregroundColor: template.status == 'active'
                    ? AppColors.infoForeground
                    : AppColors.neutralForeground,
              ),
              onPressed: _loading
                  ? null
                  : () => _toggleTemplateStatus(template),
              child: Text(template.status == 'active' ? '활성' : '비활성'),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: () {
                _openTemplateDialog(template: template);
              },
              child: const Text('수정'),
            ),
            if (template.status != 'active') ...[
              const SizedBox(width: 8),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.errorBackground,
                  foregroundColor: AppColors.errorForeground,
                ),
                onPressed: () {
                  _confirmDeleteTemplate(template);
                },
                child: const Text('삭제'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateInfoTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.body,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTemplateInstructorTag(AdminInstructor? instructor) {
    if (instructor == null) {
      return _buildTemplateInfoTag('기본 강사 미지정');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '기본 강사:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.body,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          StudioAvatar(
            name: instructor.name,
            imageUrl: instructor.imageUrl,
            size: 20,
            borderRadius: 6,
          ),
          const SizedBox(width: 6),
          Text(
            instructor.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateProductChip(AdminPassProduct product) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: product.status == 'active'
            ? AppColors.infoBackground
            : AppColors.neutralBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: product.status == 'active'
              ? AppColors.infoForeground.withValues(alpha: 0.2)
              : AppColors.border,
        ),
      ),
      child: Text(
        product.status == 'active' ? product.name : '${product.name} (보관)',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: product.status == 'active'
              ? AppColors.infoForeground
              : AppColors.neutralForeground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        context.read<AdminRepository>().fetchTemplates(studioId),
        context.read<AdminRepository>().fetchInstructors(studioId),
        context.read<AdminRepository>().fetchPassProducts(studioId),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _templates = results[0] as List<AdminClassTemplate>;
        _instructors = results[1] as List<AdminInstructor>;
        _products = results[2] as List<AdminPassProduct>;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openTemplateDialog({AdminClassTemplate? template}) async {
    final studioId = _studioId;
    final repository = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    if (studioId == null) {
      return;
    }

    final formData = await showDialog<_TemplateFormData>(
      context: context,
      builder: (dialogContext) {
        return _TemplateDialog(
          initialValue: template,
          instructors: _instructors,
        );
      },
    );

    if (formData == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    try {
      if (template != null &&
          template.status == 'active' &&
          formData.status != 'active') {
        final sessionDates = await repository
            .fetchTemplateSessionDatesInCurrentMonth(templateId: template.id);
        if (sessionDates.isNotEmpty) {
          if (!mounted) {
            return;
          }
          await _showTemplateDeactivateBlockedDialog(
            template: template,
            sessionDates: sessionDates,
          );
          return;
        }
      }

      await repository.saveTemplate(
        id: template?.id,
        studioId: studioId,
        name: formData.name,
        category: template?.category ?? '수업',
        defaultInstructorId: formData.defaultInstructorId,
        description: formData.description,
        dayOfWeekMask: formData.dayOfWeekMask,
        startTime: formData.startTime,
        endTime: formData.endTime,
        capacity: formData.capacity,
        status: formData.status,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, '수업 템플릿을 저장했습니다.');
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, error.toString(), isError: true);
    }
  }

  Future<void> _toggleTemplateStatus(AdminClassTemplate template) async {
    final studioId = _studioId;
    final repository = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    if (studioId == null) {
      return;
    }

    final nextStatus = template.status == 'active' ? 'inactive' : 'active';
    if (template.status == 'active') {
      final sessionDates = await repository
          .fetchTemplateSessionDatesInCurrentMonth(templateId: template.id);
      if (sessionDates.isNotEmpty) {
        if (!mounted) {
          return;
        }
        await _showTemplateDeactivateBlockedDialog(
          template: template,
          sessionDates: sessionDates,
        );
        return;
      }
    }

    try {
      await repository.saveTemplate(
        id: template.id,
        studioId: studioId,
        name: template.name,
        category: template.category,
        defaultInstructorId: template.defaultInstructorId,
        description: template.description ?? '',
        dayOfWeekMask: template.dayOfWeekMask,
        startTime: template.startTime,
        endTime: template.endTime,
        capacity: template.capacity,
        status: nextStatus,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(
        messenger,
        nextStatus == 'active' ? '템플릿을 운영 중으로 전환했습니다.' : '템플릿을 보관 처리했습니다.',
      );
      await _refresh();
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

  Future<void> _showTemplateDeactivateBlockedDialog({
    required AdminClassTemplate template,
    required List<DateTime> sessionDates,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: _AdminDialogTitle(
          title: '비활성화할 수 없습니다',
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '비활성화는 이번달에 해당 템플릿으로 만들어진 수업이 없는 경우에만 가능합니다.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Text(
                '${template.name} 템플릿으로 이번달에 등록된 수업 날짜',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sessionDates
                    .map(
                      (date) => StatusPill(
                        label: Formatters.date(date),
                        backgroundColor: AppColors.infoBackground,
                        foregroundColor: AppColors.infoForeground,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTemplate(AdminClassTemplate template) async {
    final repository = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: _AdminDialogTitle(
          title: '템플릿을 삭제할까요?',
          onClose: () => Navigator.of(dialogContext).pop(false),
        ),
        content: Text(
          '${template.name} 템플릿을 삭제합니다.\n'
          '개설된 수업 회차가 없는 템플릿만 삭제할 수 있습니다.',
        ),
        actions: [
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorBackground,
              foregroundColor: AppColors.errorForeground,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await repository.deleteTemplate(templateId: template.id);
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, '수업 템플릿을 삭제했습니다.');
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, error.toString(), isError: true);
    }
  }
}

class _PassProductsPage extends StatefulWidget {
  const _PassProductsPage({required this.isActive});

  final bool isActive;

  @override
  State<_PassProductsPage> createState() => _PassProductsPageState();
}

class _PassProductsPageState extends State<_PassProductsPage> {
  List<AdminPassProduct> _products = const [];
  List<AdminClassTemplate> _templates = const [];
  bool _loading = false;
  String? _error;
  String? _studioId;

  List<AdminPassProduct> get _activeProducts => _products
      .where((product) => product.status == 'active')
      .toList(growable: false);

  List<AdminPassProduct> get _inactiveProducts => _products
      .where((product) => product.status != 'active')
      .toList(growable: false);

  List<String> _visibleTemplateNamesForProduct(AdminPassProduct product) {
    final templateNamesById = {
      for (final template in _templates)
        if (template.category != '일회성') template.id: template.name,
    };
    return product.allowedTemplateIds
        .map((id) => templateNamesById[id])
        .whereType<String>()
        .toList(growable: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final studioId = context.read<AdminSessionController>().profile?.studioId;
    if (studioId != null && studioId != _studioId) {
      _studioId = studioId;
      Future<void>.microtask(_refresh);
    }
  }

  @override
  void didUpdateWidget(covariant _PassProductsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      Future<void>.microtask(_refresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeProducts = _activeProducts;
    final inactiveProducts = _inactiveProducts;

    return _AdminPageFrame(
      title: '수강권 상품 관리',
      subtitle: '판매/발급에 사용할 상품과 보관용 상품을 나눠 관리합니다.',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonalIcon(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('새로고침'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _openProductDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('새 상품'),
          ),
        ],
      ),
      child: _error != null
          ? ErrorSection(message: _error!, onRetry: _refresh)
          : _loading && _products.isEmpty
          ? const LoadingSection()
          : _products.isEmpty
          ? const EmptySection(
              title: '등록된 수강권 상품이 없습니다',
              description: '수강권 상품을 등록하면 회원에게 발급할 수 있습니다.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AdminStatusBucketSection(
                  title: '운영 중인 수강권 상품',
                  subtitle: '회원 발급과 일회성 수업 연결에 사용할 상품입니다.',
                  emptyTitle: '운영 중인 수강권 상품이 없습니다',
                  emptyDescription: '판매하거나 발급할 상품을 활성화하세요.',
                  children: activeProducts
                      .map(_buildProductCard)
                      .toList(growable: false),
                ),
                const SizedBox(height: 18),
                _AdminStatusBucketSection(
                  title: '보관된 수강권 상품',
                  subtitle: '지금은 사용하지 않지만 나중에 다시 활성화할 수 있습니다.',
                  emptyTitle: '보관된 수강권 상품이 없습니다',
                  emptyDescription: '비활성화한 상품은 이 구역에 모여 보입니다.',
                  children: inactiveProducts
                      .map(_buildProductCard)
                      .toList(growable: false),
                ),
              ],
            ),
    );
  }

  Widget _buildProductCard(AdminPassProduct product) {
    final description = product.description?.trim();
    final visibleTemplateNames = _visibleTemplateNamesForProduct(product);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusPill(
                  label: product.status == 'active' ? '활성' : '비활성',
                  backgroundColor: product.status == 'active'
                      ? AppColors.infoBackground
                      : AppColors.neutralBackground,
                  foregroundColor: product.status == 'active'
                      ? AppColors.infoForeground
                      : AppColors.neutralForeground,
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: () {
                    _openProductDialog(product: product);
                  },
                  child: const Text('수정'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    description?.isNotEmpty == true ? description! : '설명 없음',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildProductMetaTag('${product.totalCount}회'),
                  const SizedBox(width: 8),
                  _buildProductMetaTag('${product.validDays}일'),
                  const SizedBox(width: 8),
                  _buildProductMetaTag(_currency(product.priceAmount)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '예약 가능한 수업:',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: product.allowedTemplateNames.isEmpty
                          ? [
                              Text(
                                '연결된 수업 없음',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.subtle),
                              ),
                            ]
                          : visibleTemplateNames.isEmpty
                          ? [
                              Text(
                                '연결된 수업 없음',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.subtle),
                              ),
                            ]
                          : visibleTemplateNames
                                .expand(
                                  (name) => [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                )
                                .toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductMetaTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.body,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        context.read<AdminRepository>().fetchPassProducts(studioId),
        context.read<AdminRepository>().fetchTemplates(studioId),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _products = results[0] as List<AdminPassProduct>;
        _templates = results[1] as List<AdminClassTemplate>;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openProductDialog({AdminPassProduct? product}) async {
    final studioId = _studioId;
    final repository = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    if (studioId == null) {
      return;
    }

    try {
      final templates = await repository.fetchTemplates(studioId);
      if (!mounted) {
        return;
      }
      setState(() {
        _templates = templates;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(
        messenger,
        ErrorText.format(error),
        isError: true,
      );
      return;
    }

    final formData = await showDialog<_PassProductFormData>(
      context: context,
      builder: (dialogContext) {
        return _PassProductDialog(initialValue: product, templates: _templates);
      },
    );

    if (formData == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    try {
      await repository.savePassProduct(
        id: product?.id,
        studioId: studioId,
        name: formData.name,
        totalCount: formData.totalCount,
        validDays: formData.validDays,
        priceAmount: formData.priceAmount,
        description: formData.description,
        status: formData.status,
        templateIds: formData.templateIds,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, '수강권 상품을 저장했습니다.');
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, error.toString(), isError: true);
    }
  }
}

class _InstructorsPage extends StatefulWidget {
  const _InstructorsPage({required this.isActive});

  final bool isActive;

  @override
  State<_InstructorsPage> createState() => _InstructorsPageState();
}

class _InstructorsPageState extends State<_InstructorsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(
    text: Formatters.editablePhone(),
  );
  PickedImageFile? _selectedImageFile;

  List<AdminInstructor> _instructors = const [];
  List<AdminSessionSchedule> _currentMonthSessions = const [];
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _studioId;

  bool get _isPhoneValid => Formatters.isMobilePhone(_phoneController.text);

  DateTime get _currentMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final studioId = context.read<AdminSessionController>().profile?.studioId;
    if (studioId != null && studioId != _studioId) {
      _studioId = studioId;
      Future<void>.microtask(_refresh);
    }
  }

  @override
  void didUpdateWidget(covariant _InstructorsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      Future<void>.microtask(_refresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPageFrame(
      title: '강사 관리',
      subtitle: '강사를 등록하고, 이번달 강의 진행/예정/취소 현황과 월별 배정 내역을 확인합니다.',
      trailing: FilledButton.tonalIcon(
        onPressed: _loading ? null : _refresh,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('새로고침'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '강사 등록',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '강사 사진은 선택 사항입니다. 로컬 파일에서 이미지를 업로드하고 이름, 핸드폰 번호를 입력해 등록하세요.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                ),
                const SizedBox(height: 14),
                ImageUploadField(
                  name: _nameController.text.trim().isEmpty
                      ? '강사'
                      : _nameController.text.trim(),
                  label: '강사 대표 이미지',
                  selectedImageBytes: _selectedImageFile?.bytes,
                  onPick: _pickNewInstructorImage,
                  showPickButton: false,
                  previewOverlayLabel: '업로드',
                  onClear: _selectedImageFile == null
                      ? null
                      : () {
                          setState(() {
                            _selectedImageFile = null;
                          });
                        },
                  clearLabel: '선택 취소',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: '강사 이름'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: const [
                          KoreanMobilePhoneTextInputFormatter(),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: '핸드폰 번호',
                          helperText: _isPhoneValid
                              ? null
                              : '핸드폰 번호를 올바른 양식으로 입력하세요. (010-1234-5678)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed:
                        _saving ||
                            _nameController.text.trim().isEmpty ||
                            !_isPhoneValid
                        ? null
                        : _registerInstructor,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(_saving ? '등록 중...' : '강사 등록'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('등록된 강사', _instructors.length),
          const SizedBox(height: 12),
          if (_error != null)
            ErrorSection(message: _error!, onRetry: _refresh)
          else if (_loading && _instructors.isEmpty)
            const LoadingSection()
          else if (_instructors.isEmpty)
            const EmptySection(
              title: '등록된 강사가 없습니다',
              description: '위에서 강사를 등록하면 이번달 강의 현황과 월별 배정 내역을 확인할 수 있습니다.',
            )
          else
            Column(
              children: _instructors
                  .map(
                    (instructor) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildInstructorCard(instructor),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count명',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructorCard(AdminInstructor instructor) {
    final stats = _summaryForInstructor(instructor);

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () {
            _openInstructorSessionsDialog(instructor);
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudioAvatar(
                  name: instructor.name,
                  imageUrl: instructor.imageUrl,
                  size: 58,
                  borderRadius: 18,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        instructor.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        instructor.phone?.isNotEmpty == true
                            ? Formatters.phone(instructor.phone)
                            : '핸드폰 번호 없음',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: AppColors.body),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '이번달 기준 강의 현황입니다. row를 눌러 월별 상세 내역을 확인하세요.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.subtle,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SessionStatChip(
                            label: '진행',
                            value: '${stats.completedCount}',
                          ),
                          _SessionStatChip(
                            label: '예정',
                            value: '${stats.scheduledCount}',
                          ),
                          _SessionStatChip(
                            label: '취소',
                            value: '${stats.cancelledCount}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    TextButton(
                      onPressed: () {
                        _openEditInstructorDialog(instructor);
                      },
                      child: const Text('수정'),
                    ),
                    const SizedBox(height: 6),
                    IconButton(
                      onPressed: () {
                        _confirmDeleteInstructor(instructor);
                      },
                      tooltip: '강사 삭제',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.errorBackground,
                        foregroundColor: AppColors.errorForeground,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _InstructorMonthlyStats _summaryForInstructor(AdminInstructor instructor) {
    var scheduledCount = 0;
    var completedCount = 0;
    var cancelledCount = 0;

    for (final session in _currentMonthSessions) {
      if (session.instructorId != instructor.id) {
        continue;
      }
      switch (session.status) {
        case 'completed':
          completedCount += 1;
          break;
        case 'cancelled':
          cancelledCount += 1;
          break;
        default:
          scheduledCount += 1;
          break;
      }
    }

    return _InstructorMonthlyStats(
      scheduledCount: scheduledCount,
      completedCount: completedCount,
      cancelledCount: cancelledCount,
    );
  }

  Future<void> _refresh() async {
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }

    final monthStart = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final monthEnd = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        context.read<AdminRepository>().fetchInstructors(studioId),
        context.read<AdminRepository>().fetchSessions(
          studioId: studioId,
          startDate: monthStart,
          endDate: monthEnd,
        ),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _instructors = results[0] as List<AdminInstructor>;
        _currentMonthSessions = results[1] as List<AdminSessionSchedule>;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickNewInstructorImage() async {
    try {
      final picked = await context.read<ImageStorageRepository>().pickImage();
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _selectedImageFile = picked;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, ErrorText.format(error), isError: true);
    }
  }

  Future<void> _registerInstructor() async {
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppSnackBar(context, '강사 이름을 입력하세요.', isError: true);
      return;
    }
    if (!_isPhoneValid) {
      showAppSnackBar(context, '핸드폰 번호를 올바른 양식으로 입력하세요.', isError: true);
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await context.read<AdminRepository>().saveInstructor(
        studioId: studioId,
        name: name,
        phone: Formatters.storagePhone(_phoneController.text),
        imageFile: _selectedImageFile,
      );
      if (!mounted) {
        return;
      }
      _nameController.clear();
      _phoneController.text = Formatters.editablePhone();
      setState(() {
        _selectedImageFile = null;
      });
      showAppSnackBar(context, '강사를 등록했습니다.');
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, ErrorText.format(error), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _openEditInstructorDialog(AdminInstructor instructor) async {
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }

    final formData = await showDialog<_InstructorFormData>(
      context: context,
      builder: (dialogContext) => _InstructorDialog(initialValue: instructor),
    );

    if (formData == null || !mounted) {
      return;
    }

    try {
      await context.read<AdminRepository>().saveInstructor(
        id: instructor.id,
        studioId: studioId,
        name: formData.name,
        phone: formData.phone,
        previousInstructor: instructor,
        imageFile: formData.imageFile,
        removeImage: formData.removeImage,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, '강사 정보를 수정했습니다.');
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, ErrorText.format(error), isError: true);
    }
  }

  Future<void> _confirmDeleteInstructor(AdminInstructor instructor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: _AdminDialogTitle(
          title: '강사를 삭제할까요?',
          onClose: () => Navigator.of(dialogContext).pop(false),
        ),
        content: Text(
          '${instructor.name} 강사를 삭제합니다.\n'
          '기존 템플릿과 수업의 강사 지정은 자동으로 해제됩니다.',
        ),
        actions: [
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorBackground,
              foregroundColor: AppColors.errorForeground,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await context.read<AdminRepository>().deleteInstructor(
        instructor: instructor,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, '강사를 삭제했습니다.');
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, ErrorText.format(error), isError: true);
    }
  }

  Future<void> _openInstructorSessionsDialog(AdminInstructor instructor) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _InstructorSessionsDialog(
        studioId: _studioId!,
        instructor: instructor,
      ),
    );
  }
}

class _MembersPage extends StatefulWidget {
  const _MembersPage({required this.isActive});

  final bool isActive;

  @override
  State<_MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<_MembersPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _memberNameFilterController =
      TextEditingController();
  List<AdminMember> _members = const [];
  bool _loading = false;
  bool _searching = false;
  bool _showExpiredAfterMonthMembers = false;
  String? _error;
  String? _studioId;
  int _membersWithPassPage = 0;
  int _membersExpiringWithinMonthPage = 0;

  static const int _memberPageSize = 10;

  DateTime get _today => _normalizedDate(DateTime.now());

  List<AdminMember> get _membersWithPass => _members
      .where((member) => member.activePassCount > 0)
      .toList(growable: false);

  List<AdminMember> get _membersExpiringWithinMonth =>
      _members.where(_isMemberExpiredWithinMonth).toList(growable: false);

  List<AdminMember> get _membersExpiringAfterMonth => _members
      .where(
        (member) =>
            member.activePassCount <= 0 && !_isMemberExpiredWithinMonth(member),
      )
      .toList(growable: false);

  String get _memberNameFilter => _memberNameFilterController.text.trim();

  @override
  void dispose() {
    _searchController.dispose();
    _memberNameFilterController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final studioId = context.read<AdminSessionController>().profile?.studioId;
    if (studioId != null && studioId != _studioId) {
      _studioId = studioId;
      Future<void>.microtask(_refresh);
    }
  }

  @override
  void didUpdateWidget(covariant _MembersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      Future<void>.microtask(_refresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPageFrame(
      title: '회원 관리',
      subtitle: '회원 ID로 사용자를 찾아 스튜디오 회원으로 등록하고 수강권을 발급합니다.',
      trailing: FilledButton.tonalIcon(
        onPressed: _loading ? null : _refresh,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('새로고침'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '회원 등록',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '학생 앱의 회원 ID를 입력해 이 스튜디오에 연결하세요.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) {
                          if (!_searching) {
                            _searchMember();
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: '회원 ID',
                          hintText: '예: tsr01',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: _searching ? null : _searchMember,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('검색'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildMemberSectionHeader(
            '등록된 회원',
            _members.length,
            emphasized: true,
            countLabel: '총 ${_members.length}명',
          ),
          const SizedBox(height: 12),
          if (_error != null)
            ErrorSection(message: _error!, onRetry: _refresh)
          else if (_loading && _members.isEmpty)
            const LoadingSection()
          else if (_members.isEmpty)
            const EmptySection(
              title: '등록된 회원이 없습니다',
              description: '위에서 회원 ID를 검색한 뒤 팝업에서 스튜디오 회원으로 등록하세요.',
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPagedMemberSection(
                    title: '수강권 있는 회원',
                    members: _filterMembersByName(_membersWithPass),
                    emptyMessage: '현재 활성 수강권이 있는 회원이 없습니다.',
                    pageIndex: _membersWithPassPage,
                    onPageChanged: (page) {
                      setState(() {
                        _membersWithPassPage = page;
                      });
                    },
                    trailing: SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _memberNameFilterController,
                        onChanged: (_) {
                          setState(() {
                            _membersWithPassPage = 0;
                          });
                        },
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '이름 검색',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _memberNameFilter.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _memberNameFilterController.clear();
                                    setState(() {
                                      _membersWithPassPage = 0;
                                    });
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                  tooltip: '검색어 지우기',
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildPagedMemberSection(
                    title: '수강권 만료 후 1달 이내 회원',
                    members: _membersExpiringWithinMonth,
                    emptyMessage: '최근 1달 내 수강권이 만료된 회원이 없습니다.',
                    pageIndex: _membersExpiringWithinMonthPage,
                    onPageChanged: (page) {
                      setState(() {
                        _membersExpiringWithinMonthPage = page;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildCollapsibleMemberSection(
                    title: '수강권 만료 1달 이후 회원',
                    members: _membersExpiringAfterMonth,
                    emptyMessage: '수강권 만료 후 1달이 지난 회원이 없습니다.',
                    expanded: _showExpiredAfterMonthMembers,
                    onToggle: () {
                      setState(() {
                        _showExpiredAfterMonthMembers =
                            !_showExpiredAfterMonthMembers;
                      });
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _isMemberExpiredWithinMonth(AdminMember member) {
    if (member.activePassCount > 0) {
      return false;
    }
    final referenceDate = member.latestPassValidUntil ?? member.joinedAt;
    final normalizedValidUntil = _normalizedDate(referenceDate);
    final threshold = _today.subtract(const Duration(days: 30));
    return !normalizedValidUntil.isBefore(threshold);
  }

  Widget _buildMemberSectionHeader(
    String title,
    int count, {
    bool emphasized = false,
    String? countLabel,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                title,
                style:
                    (emphasized
                            ? Theme.of(context).textTheme.titleLarge
                            : Theme.of(context).textTheme.titleMedium)
                        ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  countLabel ?? '$count명',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing],
      ],
    );
  }

  Widget _buildPagedMemberSection({
    required String title,
    required List<AdminMember> members,
    required String emptyMessage,
    required int pageIndex,
    required ValueChanged<int> onPageChanged,
    Widget? trailing,
  }) {
    final totalPages = members.isEmpty
        ? 1
        : ((members.length - 1) ~/ _memberPageSize) + 1;
    final safePageIndex = math.min(pageIndex, totalPages - 1);
    final start = safePageIndex * _memberPageSize;
    final visibleMembers = members.isEmpty
        ? const <AdminMember>[]
        : members.sublist(
            start,
            math.min(start + _memberPageSize, members.length),
          );
    final sectionChildren = <Widget>[
      ...visibleMembers.map(
        (member) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildMemberCard(member),
        ),
      ),
      if (totalPages > 1)
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonalIcon(
                onPressed: safePageIndex > 0
                    ? () => onPageChanged(safePageIndex - 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('이전'),
              ),
              const SizedBox(width: 10),
              Text(
                '${safePageIndex + 1} / $totalPages',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: safePageIndex < totalPages - 1
                    ? () => onPageChanged(safePageIndex + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('다음'),
              ),
            ],
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMemberSectionHeader(title, members.length, trailing: trailing),
        const SizedBox(height: 12),
        if (members.isEmpty)
          SurfaceCard(
            child: Text(
              emptyMessage,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
            ),
          )
        else
          Column(children: sectionChildren),
      ],
    );
  }

  Widget _buildCollapsibleMemberSection({
    required String title,
    required List<AdminMember> members,
    required String emptyMessage,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMemberSectionHeader(
          title,
          members.length,
          trailing: FilledButton.tonalIcon(
            onPressed: onToggle,
            icon: Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
            label: Text(expanded ? '접기' : '펼쳐서 보기'),
          ),
        ),
        const SizedBox(height: 12),
        if (!expanded)
          SurfaceCard(
            child: Text(
              '펼쳐서 보기를 눌러 회원 목록을 확인하세요.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
            ),
          )
        else if (members.isEmpty)
          SurfaceCard(
            child: Text(
              emptyMessage,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
            ),
          )
        else
          Column(
            children: members
                .map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildMemberCard(member),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }

  List<AdminMember> _filterMembersByName(List<AdminMember> members) {
    final query = _memberNameFilter.toLowerCase();
    if (query.isEmpty) {
      return members;
    }
    return members
        .where((member) => (member.name ?? '').toLowerCase().contains(query))
        .toList(growable: false);
  }

  Widget _buildMemberCard(AdminMember member) {
    return SurfaceCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      member.name ?? '이름 없음',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    StatusPill(
                      label: '회원 ID ${member.memberCode}',
                      backgroundColor: AppColors.surfaceAlt,
                      foregroundColor: AppColors.primaryStrong,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(member.email ?? '이메일 없음'),
                Text(Formatters.phone(member.phone, fallback: '핸드폰 번호 없음')),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '활성 수강권 ${member.activePassCount}개',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
              ),
              if (member.activePassCount > 0 &&
                  member.hasExpiringSoonActivePass) ...[
                const SizedBox(height: 6),
                Text(
                  member.expiringSoonActivePassDays != null
                      ? '만료 임박 수강권 존재: ${member.expiringSoonActivePassDays}일'
                      : '만료 임박 수강권 존재',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (member.activePassCount <= 0 &&
                  member.latestPassValidUntil != null) ...[
                const SizedBox(height: 4),
                Text(
                  '최근 만료 ${Formatters.date(member.latestPassValidUntil!)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                ),
              ],
              if (member.activePassCount <= 0 &&
                  member.latestPassValidUntil == null) ...[
                const SizedBox(height: 4),
                Text(
                  '수강권 이력 없음 · 스튜디오 연결 ${Formatters.date(member.joinedAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () {
                      _openPassHistoryDialog(member);
                    },
                    child: const Text('수강권 이력'),
                  ),
                  FilledButton.tonal(
                    onPressed: () {
                      _openConsultNotesDialog(member);
                    },
                    child: const Text('상담 노트'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.successForeground,
                      foregroundColor: AppColors.onPrimary,
                    ),
                    onPressed: () {
                      _openIssuePassDialog(member);
                    },
                    child: const Text('수강권 발급'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final members = await context.read<AdminRepository>().fetchMembers(
        studioId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _members = members;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _searchMember() async {
    final memberCode = _searchController.text.trim().toLowerCase();
    if (memberCode.isEmpty) {
      showAppSnackBar(context, '회원 ID를 입력하세요.', isError: true);
      return;
    }

    setState(() {
      _searching = true;
    });

    try {
      final result = await context.read<AdminRepository>().findMemberByCode(
        memberCode,
      );
      if (!mounted) {
        return;
      }
      if (result == null) {
        showAppSnackBar(
          context,
          '해당 회원을 찾을 수 없습니다. 회원가입 완료 후 받은 회원 ID인지 확인하세요.',
          isError: true,
        );
        return;
      }

      final shouldRegister = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => _MemberLookupDialog(result: result),
      );
      if (!mounted || shouldRegister != true) {
        return;
      }
      await _linkMember(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, ErrorText.format(error), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  Future<void> _linkMember(AdminMemberLookupResult result) async {
    if (result.isActiveMember) {
      showAppSnackBar(context, '이미 등록된 회원입니다.');
      return;
    }

    try {
      await context.read<AdminRepository>().addMemberToStudio(
        userId: result.id,
      );
      if (!mounted) {
        return;
      }
      _searchController.clear();
      showAppSnackBar(context, '회원을 스튜디오에 등록했습니다.');
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, ErrorText.format(error), isError: true);
    }
  }

  Future<void> _openIssuePassDialog(AdminMember member) async {
    final repository = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }

    List<AdminPassProduct> latestProducts;
    List<AdminClassTemplate> latestTemplates;
    try {
      final results = await Future.wait([
        repository.fetchPassProducts(studioId),
        repository.fetchTemplates(studioId),
      ]);
      latestProducts = results[0] as List<AdminPassProduct>;
      latestTemplates = results[1] as List<AdminClassTemplate>;
      if (!mounted) {
        return;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(
        messenger,
        ErrorText.format(error),
        isError: true,
      );
      return;
    }

    final activeProducts = latestProducts
        .where((product) => product.status == 'active')
        .map(
          (product) => _filterIssuePassProductTemplates(
            product,
            templates: latestTemplates,
          ),
        )
        .toList(growable: false);
    if (activeProducts.isEmpty) {
      showAppSnackBar(
        context,
        '먼저 활성 수강권 상품을 등록하거나 비활성 상품을 활성화하세요.',
        isError: true,
      );
      return;
    }

    final formData = await showDialog<_IssuePassFormData>(
      context: context,
      builder: (dialogContext) => _IssuePassDialog(products: activeProducts),
    );

    if (formData == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    try {
      await repository.issueUserPass(
        userId: member.userId,
        passProductId: formData.passProductId,
        validFrom: formData.validFrom,
        paidAmount: formData.paidAmount,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, '수강권을 발급했습니다.');
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, error.toString(), isError: true);
    }
  }

  AdminPassProduct _filterIssuePassProductTemplates(
    AdminPassProduct product, {
    required List<AdminClassTemplate> templates,
  }) {
    final visibleTemplateNamesById = {
      for (final template in templates)
        if (template.category != '일회성') template.id: template.name,
    };
    final filteredTemplateIds = product.allowedTemplateIds
        .where(visibleTemplateNamesById.containsKey)
        .toList(growable: false);
    final filteredTemplateNames = filteredTemplateIds
        .map((id) => visibleTemplateNamesById[id]!)
        .toList(growable: false);

    return AdminPassProduct(
      id: product.id,
      studioId: product.studioId,
      name: product.name,
      totalCount: product.totalCount,
      validDays: product.validDays,
      priceAmount: product.priceAmount,
      description: product.description,
      status: product.status,
      allowedTemplateIds: filteredTemplateIds,
      allowedTemplateNames: filteredTemplateNames,
    );
  }

  Future<void> _openPassHistoryDialog(AdminMember member) async {
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }

    final didChange = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _MemberPassHistoryDialog(
        member: member,
        historyFuture: context.read<AdminRepository>().fetchMemberPassHistories(
          studioId: studioId,
          userId: member.userId,
        ),
      ),
    );

    if (didChange == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _openConsultNotesDialog(AdminMember member) async {
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _MemberConsultNotesDialog(
        member: member,
        notesFuture: context.read<AdminRepository>().fetchMemberConsultNotes(
          studioId: studioId,
          userId: member.userId,
        ),
      ),
    );
  }
}

class _MemberLookupDialog extends StatelessWidget {
  const _MemberLookupDialog({required this.result});

  final AdminMemberLookupResult result;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '회원 확인',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: AppColors.title,
          fontWeight: FontWeight.w800,
        ),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        result.name ?? '이름 없음',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.title,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      StatusPill(
                        label: '회원 ID ${result.memberCode}',
                        backgroundColor: AppColors.surfaceAlt,
                        foregroundColor: AppColors.primaryStrong,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _MemberLookupInfoRow(
                    icon: Icons.mail_outline_rounded,
                    value: result.email ?? '이메일 없음',
                  ),
                  const SizedBox(height: 10),
                  _MemberLookupInfoRow(
                    icon: Icons.phone_rounded,
                    value: Formatters.phone(
                      result.phone,
                      fallback: '핸드폰 번호 없음',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              result.isActiveMember
                  ? '이 회원은 이미 현재 스튜디오에 등록되어 있습니다.'
                  : '이 회원을 현재 스튜디오에 등록하시겠습니까?',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
            ),
          ],
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: result.isActiveMember
              ? null
              : () => Navigator.of(context).pop(true),
          child: const Text('등록'),
        ),
      ],
    );
  }
}

class _MemberLookupInfoRow extends StatelessWidget {
  const _MemberLookupInfoRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.subtle),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.title,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionsPage extends StatefulWidget {
  const _SessionsPage({
    required this.isActive,
    this.targetDate,
    required this.navigationNonce,
    this.onAttentionChanged,
  });

  final bool isActive;
  final DateTime? targetDate;
  final int navigationNonce;
  final VoidCallback? onAttentionChanged;

  @override
  State<_SessionsPage> createState() => _SessionsPageState();
}

enum _AdminScheduleViewMode { monthly, weekly }

class _SessionsPageState extends State<_SessionsPage> {
  List<AdminClassTemplate> _templates = const [];
  List<AdminPassProduct> _products = const [];
  List<AdminInstructor> _instructors = const [];
  List<AdminSessionSchedule> _sessions = const [];
  Set<String> _selectedTemplateIds = <String>{};
  bool _didInitializeTemplateFilter = false;
  bool _didCustomizeTemplateFilter = false;
  bool _selectAllTemplatesOnNextRefresh = false;
  bool _hasExplicitDaySelection = false;
  bool _loading = false;
  String? _error;
  String? _studioId;
  _AdminScheduleViewMode _viewMode = _AdminScheduleViewMode.monthly;
  late DateTime _visibleMonth;
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  List<AdminPassProduct> get _activeProducts => _products
      .where((product) => product.status == 'active')
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    final now = _normalizedToday();
    _visibleMonth = DateTime(now.year, now.month);
    _focusedDay = now;
    _selectedDay = now;
  }

  @override
  void didUpdateWidget(covariant _SessionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      Future<void>.microtask(_refresh);
    }
    if (widget.navigationNonce != oldWidget.navigationNonce &&
        widget.targetDate != null) {
      _jumpToDate(widget.targetDate!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final studioId = context.read<AdminSessionController>().profile?.studioId;
    if (studioId != null && studioId != _studioId) {
      _studioId = studioId;
      Future<void>.microtask(_refresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDaySessions = _sessionsForDay(_selectedDay);
    final isWeeklyView = _viewMode == _AdminScheduleViewMode.weekly;

    return _AdminPageFrame(
      title: '수업 관리',
      subtitle: '월간 달력과 주간 타임테이블에서 개설된 수업을 확인하고, 수업 템플릿 기준으로 표시 대상을 필터링합니다.',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonalIcon(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('새로고침'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _loading ? null : _openCreateSessionDialog,
            child: const Text('수업 개설'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            ErrorSection(message: _error!, onRetry: _refresh)
          else if (_loading && _sessions.isEmpty)
            const LoadingSection()
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loading) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 12),
                ],
                isWeeklyView
                    ? _buildWeeklyScheduleCard()
                    : _buildMonthlyScheduleCard(),
                if (_sessions.isEmpty) ...[
                  const SizedBox(height: 12),
                  const InfoBadge(
                    icon: Icons.info_outline_rounded,
                    label: '아직 등록된 회차가 없습니다. 수업 개설 버튼으로 첫 회차를 등록하세요.',
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  '${Formatters.monthDay(_selectedDay)} 일정',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (selectedDaySessions.isEmpty)
                  EmptySection(
                    title: _selectedTemplateIds.isEmpty
                        ? '선택된 수업 템플릿이 없습니다'
                        : _sessions.isEmpty
                        ? '아직 등록된 회차가 없습니다'
                        : '표시할 수업이 없습니다',
                    description: _selectedTemplateIds.isEmpty
                        ? '필터에서 수업 템플릿을 한 개 이상 선택하세요.'
                        : _sessions.isEmpty
                        ? '수업 개설 버튼으로 첫 수업을 등록하면 이 날짜 목록에 표시됩니다.'
                        : '선택한 날짜에는 현재 필터에 맞는 수업이 없습니다.',
                  )
                else
                  Column(
                    children: selectedDaySessions
                        .map((session) {
                          final isPastSession = session.startAt.isBefore(
                            DateTime.now(),
                          );
                          final hasWaitlist = session.waitlistCount > 0;
                          final needsWaitlistAction = _hasProcessableWaitlist(
                            session,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SurfaceCard(
                              backgroundColor: isPastSession
                                  ? AppColors.surfaceMuted
                                  : AppColors.surface,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _sessionTemplateBackground(
                                        session.classTemplateId,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              Text(
                                                '${Formatters.time(session.startAt)} - ${Formatters.time(session.endAt)} · ${session.className}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                              if (session
                                                      .instructorName
                                                      ?.isNotEmpty ==
                                                  true) ...[
                                                const SizedBox(width: 10),
                                                StudioAvatar(
                                                  name: session.instructorName!,
                                                  imageUrl: session
                                                      .instructorImageUrl,
                                                  size: 22,
                                                  borderRadius: 7,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (hasWaitlist) ...[
                                          const SizedBox(height: 12),
                                          _WaitlistActionCard(
                                            title: needsWaitlistAction
                                                ? '대기 ${session.waitlistCount}명, 지금 처리 필요'
                                                : '대기 ${session.waitlistCount}명',
                                            description: needsWaitlistAction
                                                ? '빈 자리가 ${math.max(session.spotsLeft, 1)}석 생겨 순번대로 예약 승급 또는 대기 취소를 진행해야 합니다.'
                                                : '현재 대기 중인 회원이 있습니다. 빈 자리가 생기면 대기 보기에서 순번대로 처리하세요.',
                                            actionLabel: needsWaitlistAction
                                                ? '대기 처리'
                                                : '대기 보기',
                                            onAction: () {
                                              _showSessionAttendeesDialog(
                                                session,
                                                initialFilter:
                                                    _SessionAttendeeFilter
                                                        .waitlisted,
                                                lockFilter: true,
                                              );
                                            },
                                            emphasized: needsWaitlistAction,
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Row(
                                                  children: [
                                                    _SessionActionChip(
                                                      label: '예약 회원 관리',
                                                      icon: Icons
                                                          .groups_2_rounded,
                                                      onTap: () {
                                                        _showSessionAttendeesDialog(
                                                          session,
                                                          initialFilter:
                                                              _SessionAttendeeFilter
                                                                  .reserved,
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(width: 8),
                                                    _SessionActionChip(
                                                      label:
                                                          session.instructorId ==
                                                              null
                                                          ? '강사 지정'
                                                          : '강사 변경',
                                                      icon: Icons.badge_rounded,
                                                      onTap: () {
                                                        _openAssignInstructorDialog(
                                                          session,
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(width: 8),
                                                    _SessionActionChip(
                                                      label: '수강 가능 수강권 수정',
                                                      icon: Icons
                                                          .confirmation_number_outlined,
                                                      onTap: () {
                                                        _openEditSessionPassProductsDialog(
                                                          session,
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(width: 8),
                                                    _SessionActionChip(
                                                      label: '예약 가능 인원수',
                                                      icon: Icons
                                                          .people_alt_outlined,
                                                      onTap: () {
                                                        _openEditSessionCapacityDialog(
                                                          session,
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            _SessionStatChip(
                                              label: '예약',
                                              value:
                                                  '${session.reservedCount}/${session.capacity}',
                                              onTap: () {
                                                _showSessionAttendeesDialog(
                                                  session,
                                                  initialFilter:
                                                      _SessionAttendeeFilter
                                                          .reserved,
                                                  lockFilter: true,
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            _SessionStatChip(
                                              label: needsWaitlistAction
                                                  ? '처리 필요'
                                                  : '대기',
                                              value: needsWaitlistAction
                                                  ? '대기 ${session.waitlistCount}'
                                                  : '${session.waitlistCount}',
                                              icon: hasWaitlist
                                                  ? (needsWaitlistAction
                                                        ? Icons
                                                              .notification_important_rounded
                                                        : Icons
                                                              .hourglass_top_rounded)
                                                  : null,
                                              backgroundColor: hasWaitlist
                                                  ? AppColors.waitlistBackground
                                                  : AppColors.surfaceAlt,
                                              labelColor: hasWaitlist
                                                  ? AppColors.waitlistForeground
                                                  : AppColors.subtle,
                                              valueColor: hasWaitlist
                                                  ? (needsWaitlistAction
                                                        ? AppColors
                                                              .waitlistForeground
                                                        : AppColors.title)
                                                  : AppColors.title,
                                              borderColor: hasWaitlist
                                                  ? AppColors.waitlistForeground
                                                  : AppColors.border,
                                              onTap: () {
                                                _showSessionAttendeesDialog(
                                                  session,
                                                  initialFilter:
                                                      _SessionAttendeeFilter
                                                          .waitlisted,
                                                  lockFilter: true,
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            StatusPill(
                                              label:
                                                  isPastSession &&
                                                      session.status ==
                                                          'scheduled'
                                                  ? '완료'
                                                  : _sessionStatusLabel(
                                                      session.status,
                                                    ),
                                              backgroundColor:
                                                  AppColors.neutralBackground,
                                              foregroundColor:
                                                  AppColors.neutralForeground,
                                            ),
                                            if (session.status ==
                                                'scheduled') ...[
                                              const SizedBox(width: 8),
                                              IconButton(
                                                onPressed: () {
                                                  _confirmDeleteSession(
                                                    session,
                                                  );
                                                },
                                                tooltip: '수업 삭제',
                                                style: IconButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.errorBackground,
                                                  foregroundColor:
                                                      AppColors.errorForeground,
                                                ),
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }

    final range = _currentDateRange();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        context.read<AdminRepository>().fetchTemplates(studioId),
        context.read<AdminRepository>().fetchPassProducts(studioId),
        context.read<AdminRepository>().fetchInstructors(studioId),
        context.read<AdminRepository>().fetchSessions(
          studioId: studioId,
          startDate: range.start,
          endDate: range.end,
        ),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _templates = results[0] as List<AdminClassTemplate>;
        _products = results[1] as List<AdminPassProduct>;
        _instructors = results[2] as List<AdminInstructor>;
        _sessions = results[3] as List<AdminSessionSchedule>;
        _syncSelectedTemplateFilter();
      });
      widget.onAttentionChanged?.call();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _jumpToDate(DateTime date) async {
    final previousRange = _currentDateRange();
    final normalized = DateTime(date.year, date.month, date.day);
    final targetMonth = DateTime(normalized.year, normalized.month);
    final nextRange = _dateRangeFor(
      viewMode: _viewMode,
      visibleMonth: targetMonth,
      focusedDay: normalized,
    );

    setState(() {
      _visibleMonth = targetMonth;
      _focusedDay = normalized;
      _selectedDay = normalized;
      _hasExplicitDaySelection = true;
    });

    if (!previousRange.matches(nextRange)) {
      await _refresh();
    }
  }

  Future<void> _openCreateSessionDialog() async {
    final studioId = _studioId;
    final repository = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    if (studioId == null) {
      return;
    }

    try {
      final results = await Future.wait([
        repository.fetchTemplates(studioId),
        repository.fetchPassProducts(studioId),
        repository.fetchInstructors(studioId),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _templates = results[0] as List<AdminClassTemplate>;
        _products = results[1] as List<AdminPassProduct>;
        _instructors = results[2] as List<AdminInstructor>;
        _syncSelectedTemplateFilter();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(
        messenger,
        ErrorText.format(error),
        isError: true,
      );
      return;
    }

    final formData = await showDialog<_CreateSessionFormData>(
      context: context,
      builder: (dialogContext) => _CreateSessionDialog(
        templates: _filterTemplates,
        products: _activeProducts,
        instructors: _instructors,
      ),
    );

    if (formData == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    try {
      if (formData.mode == _CreateSessionMode.templateApplied) {
        final templateIds = formData.templateIds ?? const <String>[];
        if (templateIds.isEmpty) {
          showAppSnackBarWithMessenger(
            messenger,
            '수업 템플릿을 한 개 이상 선택하세요.',
            isError: true,
          );
          return;
        }
        var createdCount = 0;
        for (final templateId in templateIds) {
          createdCount += await repository.createSessionsFromTemplate(
            classTemplateId: templateId,
            startDate: formData.startDate!,
            endDate: formData.endDate!,
          );
        }
        if (!mounted) {
          return;
        }
        showAppSnackBarWithMessenger(
          messenger,
          createdCount > 0
              ? '$createdCount개의 수업 회차를 개설했습니다.'
              : '조건에 맞는 신규 회차가 없어 개설하지 않았습니다.',
          isError: createdCount == 0,
        );
      } else {
        await repository.createOneOffSession(
          studioId: studioId,
          name: formData.name!,
          description: formData.description ?? '',
          sessionDate: formData.sessionDate!,
          startTime: formData.startTime!,
          endTime: formData.endTime!,
          capacity: formData.capacity!,
          passProductIds: formData.passProductIds!,
          instructorId: formData.instructorId,
        );
        if (!mounted) {
          return;
        }
        showAppSnackBarWithMessenger(messenger, '일회성 수업을 생성했습니다.');
        _selectAllTemplatesOnNextRefresh = true;
      }
      if (!mounted) {
        return;
      }
      await _refresh();
      if (formData.mode == _CreateSessionMode.oneOff &&
          formData.sessionDate != null &&
          mounted) {
        await _jumpToDate(formData.sessionDate!);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, error.toString(), isError: true);
    }
  }

  Future<void> _openAssignInstructorDialog(AdminSessionSchedule session) async {
    final formData = await showDialog<_AssignSessionInstructorFormData>(
      context: context,
      builder: (dialogContext) => _AssignSessionInstructorDialog(
        session: session,
        instructors: _instructors,
      ),
    );

    if (formData == null || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AdminRepository>().assignInstructorToSession(
        sessionId: session.id,
        instructorId: formData.instructorId,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, '강사 배정을 저장했습니다.');
      await _refresh();
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

  Future<void> _openEditSessionPassProductsDialog(
    AdminSessionSchedule session,
  ) async {
    final studioId = _studioId;
    final messenger = ScaffoldMessenger.of(context);
    if (studioId == null) {
      return;
    }
    if (_activeProducts.isEmpty) {
      showAppSnackBarWithMessenger(
        messenger,
        '활성 수강권 상품이 없어 연결할 수 없습니다.',
        isError: true,
      );
      return;
    }

    try {
      final initialIds = await context
          .read<AdminRepository>()
          .fetchTemplatePassProductIds(
            classTemplateId: session.classTemplateId,
          );
      if (!mounted) {
        return;
      }

      final selectedIds = await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => _EditSessionPassProductsDialog(
          session: session,
          products: _activeProducts,
          initialPassProductIds: initialIds,
        ),
      );

      if (selectedIds == null || !mounted) {
        return;
      }

      await context.read<AdminRepository>().saveTemplatePassProductIds(
        studioId: studioId,
        classTemplateId: session.classTemplateId,
        passProductIds: selectedIds,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, '수강 가능 수강권을 저장했습니다.');
      await _refresh();
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

  Future<void> _openEditSessionCapacityDialog(
    AdminSessionSchedule session,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final capacity = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _EditSessionCapacityDialog(session: session),
    );

    if (capacity == null || !mounted) {
      return;
    }

    try {
      await context.read<AdminRepository>().updateSessionCapacity(
        sessionId: session.id,
        capacity: capacity,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, '예약 가능 인원수를 저장했습니다.');
      await _refresh();
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

  List<AdminClassTemplate> get _filterTemplates => _templates
      .where(
        (template) => template.status == 'active' && template.category != '일회성',
      )
      .toList(growable: false);

  Widget _buildMonthlyScheduleCard() {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        children: [
          _buildScheduleToolbar(),
          const SizedBox(height: 12),
          TableCalendar<AdminSessionSchedule>(
            firstDay: DateTime(DateTime.now().year - 1, DateTime.now().month),
            lastDay: DateTime(DateTime.now().year + 1, DateTime.now().month),
            focusedDay: _focusedDay,
            rowHeight: 152,
            daysOfWeekHeight: 22,
            locale: 'ko_KR',
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            availableCalendarFormats: const {CalendarFormat.month: 'month'},
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
                color: AppColors.title,
                fontWeight: FontWeight.w800,
              ),
              leftChevronIcon: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.title,
              ),
              rightChevronIcon: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.title,
              ),
              titleTextFormatter: (date, locale) => Formatters.yearMonth(date),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: Theme.of(
                context,
              ).textTheme.labelMedium!.copyWith(color: AppColors.subtle),
              weekendStyle: Theme.of(
                context,
              ).textTheme.labelMedium!.copyWith(color: AppColors.subtle),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              canMarkersOverflow: false,
              defaultDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
              ),
              weekendDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
              ),
              outsideDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
              ),
              disabledDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
              ),
              holidayDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
              ),
              withinRangeDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
              ),
              rangeStartDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
              ),
              rangeEndDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
              ),
              todayDecoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              selectedTextStyle: const TextStyle(color: AppColors.title),
              todayTextStyle: const TextStyle(color: AppColors.title),
            ),
            calendarBuilders: CalendarBuilders<AdminSessionSchedule>(
              defaultBuilder: (context, day, focusedDay) =>
                  _AdminScheduleDayCell(
                    day: day,
                    sessions: _sessionsForDay(day),
                    isToday: _isToday(day),
                    isPast: _isPastDay(day),
                    isSelected: isSameDay(day, _selectedDay),
                  ),
              todayBuilder: (context, day, focusedDay) => _AdminScheduleDayCell(
                day: day,
                sessions: _sessionsForDay(day),
                isToday: true,
                isPast: false,
                isSelected: isSameDay(day, _selectedDay),
              ),
              selectedBuilder: (context, day, focusedDay) =>
                  _AdminScheduleDayCell(
                    day: day,
                    sessions: _sessionsForDay(day),
                    isToday: _isToday(day),
                    isPast: _isPastDay(day),
                    isSelected: true,
                  ),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _hasExplicitDaySelection = true;
              });
            },
            onPageChanged: (focusedDay) {
              final lastDayOfMonth = DateTime(
                focusedDay.year,
                focusedDay.month + 1,
                0,
              ).day;
              setState(() {
                _visibleMonth = DateTime(focusedDay.year, focusedDay.month);
                _focusedDay = focusedDay;
                _selectedDay = DateTime(
                  focusedDay.year,
                  focusedDay.month,
                  _selectedDay.day > lastDayOfMonth
                      ? lastDayOfMonth
                      : _selectedDay.day,
                );
              });
              _refresh();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyScheduleCard() {
    final weekStart = _startOfWeek(_focusedDay);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        children: [
          _buildScheduleToolbar(),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton(
                onPressed: _loading ? null : () => _shiftWeek(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: '이전 주',
              ),
              Expanded(
                child: Text(
                  _weeklyRangeLabel(weekStart),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : () => _shiftWeek(1),
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: '다음 주',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AdminWeeklyScheduleView(
            weekStart: weekStart,
            selectedDay: _selectedDay,
            sessions: _sessions
                .where((session) => session.status != 'cancelled')
                .where((session) {
                  if (session.category == '일회성') {
                    return true;
                  }
                  if (_filterTemplates.isEmpty) {
                    return true;
                  }
                  if (_selectedTemplateIds.isEmpty) {
                    return false;
                  }
                  return _selectedTemplateIds.contains(session.classTemplateId);
                })
                .toList(growable: false),
            onSelectDay: (day) {
              setState(() {
                _selectedDay = day;
                _focusedDay = day;
                _hasExplicitDaySelection = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleToolbar() {
    return Row(
      children: [
        SegmentedButton<_AdminScheduleViewMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment<_AdminScheduleViewMode>(
              value: _AdminScheduleViewMode.monthly,
              icon: Icon(Icons.calendar_month_rounded),
              label: Text('월간'),
            ),
            ButtonSegment<_AdminScheduleViewMode>(
              value: _AdminScheduleViewMode.weekly,
              icon: Icon(Icons.view_week_rounded),
              label: Text('주간'),
            ),
          ],
          selected: {_viewMode},
          onSelectionChanged: (selection) {
            final nextMode = selection.first;
            _setViewMode(nextMode);
          },
        ),
        const Spacer(),
        IconButton(
          onPressed: _filterTemplates.isEmpty
              ? null
              : _openTemplateFilterDialog,
          tooltip: '수업 템플릿 필터',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceAlt,
            foregroundColor: AppColors.title,
          ),
          icon: const Icon(Icons.filter_alt_rounded),
        ),
      ],
    );
  }

  void _syncSelectedTemplateFilter() {
    final activeIds = _filterTemplates.map((template) => template.id).toSet();
    if (!_didInitializeTemplateFilter ||
        !_didCustomizeTemplateFilter ||
        _selectAllTemplatesOnNextRefresh ||
        activeIds.isEmpty) {
      _selectedTemplateIds = activeIds;
      _didInitializeTemplateFilter = true;
      _selectAllTemplatesOnNextRefresh = false;
      return;
    }

    _selectedTemplateIds = _selectedTemplateIds
        .where(activeIds.contains)
        .toSet();
    _selectAllTemplatesOnNextRefresh = false;
  }

  List<AdminSessionSchedule> _sessionsForDay(DateTime day) {
    return _sessions
        .where((session) => session.status != 'cancelled')
        .where((session) => isSameDay(session.sessionDate, day))
        .where((session) {
          if (session.category == '일회성') {
            return true;
          }
          if (_filterTemplates.isEmpty) {
            return true;
          }
          if (_selectedTemplateIds.isEmpty) {
            return false;
          }
          return _selectedTemplateIds.contains(session.classTemplateId);
        })
        .toList(growable: false)
      ..sort((left, right) {
        final byStart = left.startAt.compareTo(right.startAt);
        if (byStart != 0) {
          return byStart;
        }
        return left.className.compareTo(right.className);
      });
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  bool _isPastDay(DateTime day) {
    final now = _normalizedToday();
    final normalized = DateTime(day.year, day.month, day.day);
    return normalized.isBefore(now);
  }

  _SessionDateRange _currentDateRange() {
    return _dateRangeFor(
      viewMode: _viewMode,
      visibleMonth: _visibleMonth,
      focusedDay: _focusedDay,
    );
  }

  _SessionDateRange _dateRangeFor({
    required _AdminScheduleViewMode viewMode,
    required DateTime visibleMonth,
    required DateTime focusedDay,
  }) {
    if (viewMode == _AdminScheduleViewMode.weekly) {
      final start = _startOfWeek(focusedDay);
      return _SessionDateRange(
        start: start,
        end: start.add(const Duration(days: 6)),
      );
    }
    return _SessionDateRange(
      start: DateTime(visibleMonth.year, visibleMonth.month),
      end: DateTime(visibleMonth.year, visibleMonth.month + 1, 0),
    );
  }

  Future<void> _setViewMode(_AdminScheduleViewMode nextMode) async {
    if (_viewMode == nextMode) {
      return;
    }
    final anchorDay = nextMode == _AdminScheduleViewMode.weekly
        ? (_hasExplicitDaySelection ? _selectedDay : _normalizedToday())
        : _selectedDay;
    setState(() {
      _viewMode = nextMode;
      _focusedDay = anchorDay;
      _selectedDay = anchorDay;
      _visibleMonth = DateTime(anchorDay.year, anchorDay.month);
    });
    await _refresh();
  }

  Future<void> _shiftWeek(int offset) async {
    final movedFocusedDay = _focusedDay.add(Duration(days: 7 * offset));
    final movedSelectedDay = _selectedDay.add(Duration(days: 7 * offset));
    setState(() {
      _focusedDay = movedFocusedDay;
      _selectedDay = movedSelectedDay;
      _visibleMonth = DateTime(movedFocusedDay.year, movedFocusedDay.month);
      _hasExplicitDaySelection = true;
    });
    await _refresh();
  }

  String _weeklyRangeLabel(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    if (weekStart.year == weekEnd.year && weekStart.month == weekEnd.month) {
      return '${Formatters.yearMonth(weekStart)} ${weekStart.day}일 - ${weekEnd.day}일';
    }
    final monthDay = DateFormat('M월 d일', 'ko_KR');
    if (weekStart.year == weekEnd.year) {
      return '${weekStart.year}년 ${monthDay.format(weekStart)} - ${monthDay.format(weekEnd)}';
    }
    final full = DateFormat('yyyy년 M월 d일', 'ko_KR');
    return '${full.format(weekStart)} - ${full.format(weekEnd)}';
  }

  DateTime _normalizedToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _confirmDeleteSession(AdminSessionSchedule session) async {
    if (session.reservedCount > 0 || session.waitlistCount > 0) {
      showAppSnackBar(
        context,
        '예약 또는 대기 중인 회원이 있는 수업은 삭제할 수 없습니다.',
        isError: true,
      );
      return;
    }

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: _AdminDialogTitle(
          title: '수업을 삭제할까요?',
          onClose: () => Navigator.of(dialogContext).pop(false),
        ),
        content: Text(
          '${Formatters.monthDay(session.sessionDate)} ${Formatters.time(session.startAt)} ${session.className} 수업을 완전히 삭제합니다.\n'
          '예약 내역이나 예약 취소 내역이 없는 수업만 삭제할 수 있습니다.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (shouldCancel != true || !mounted) {
      return;
    }

    final repository = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repository.deleteSession(sessionId: session.id);
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, '수업을 삭제했습니다.');
      await _refresh();
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

  Future<void> _openTemplateFilterDialog() async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => _TemplateFilterDialog(
        templates: _filterTemplates,
        selectedTemplateIds: _selectedTemplateIds,
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedTemplateIds = selected;
      _didCustomizeTemplateFilter =
          selected.length != _filterTemplates.length ||
          _filterTemplates.any((template) => !selected.contains(template.id));
    });
  }

  Future<void> _showSessionAttendeesDialog(
    AdminSessionSchedule session, {
    _SessionAttendeeFilter initialFilter = _SessionAttendeeFilter.all,
    bool lockFilter = false,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SessionAttendeesDialog(
        session: session,
        initialFilter: initialFilter,
        lockFilter: lockFilter,
        onChanged: _refresh,
      ),
    );
  }
}

class _AdminScheduleDayCell extends StatelessWidget {
  const _AdminScheduleDayCell({
    required this.day,
    required this.sessions,
    required this.isToday,
    required this.isPast,
    required this.isSelected,
  });

  final DateTime day;
  final List<AdminSessionSchedule> sessions;
  final bool isToday;
  final bool isPast;
  final bool isSelected;

  static const double _markerAreaHeight = 104;

  @override
  Widget build(BuildContext context) {
    final waitlistedSessionCount = sessions
        .where((session) => session.waitlistCount > 0)
        .length;
    final actionableWaitlistSessionCount = sessions
        .where(_hasProcessableWaitlist)
        .length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primarySoft.withValues(alpha: 0.10)
            : (isPast
                  ? AppColors.surfaceMuted.withValues(alpha: 0.72)
                  : Colors.transparent),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : (isToday
                    ? AppColors.infoForeground.withValues(alpha: 0.45)
                    : AppColors.border),
          width: isSelected ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? AppColors.primaryStrong
                        : AppColors.title,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.infoBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '오늘',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.infoForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (waitlistedSessionCount > 0) ...[
                  const Spacer(),
                  _WaitlistAttentionBadge(
                    label: actionableWaitlistSessionCount > 0
                        ? '처리 $actionableWaitlistSessionCount건'
                        : '대기 $waitlistedSessionCount건',
                    icon: actionableWaitlistSessionCount > 0
                        ? Icons.notification_important_rounded
                        : Icons.hourglass_top_rounded,
                    compact: true,
                    emphasized: actionableWaitlistSessionCount > 0,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: _markerAreaHeight,
              child: _AdminScheduleMarkerList(sessions: sessions),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminScheduleMarkerList extends StatelessWidget {
  const _AdminScheduleMarkerList({required this.sessions});

  final List<AdminSessionSchedule> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRect(
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < sessions.length; index++) ...[
                _AdminScheduleMarkerTile(session: sessions[index]),
                if (index < sessions.length - 1) const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminScheduleMarkerTile extends StatelessWidget {
  const _AdminScheduleMarkerTile({required this.session});

  final AdminSessionSchedule session;

  @override
  Widget build(BuildContext context) {
    final foreground = _sessionTemplateForeground(session.classTemplateId);
    final hasWaitlist = session.waitlistCount > 0;
    final needsWaitlistAction = _hasProcessableWaitlist(session);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: _sessionTemplateBackground(session.classTemplateId),
        borderRadius: BorderRadius.circular(10),
        border: hasWaitlist
            ? Border.all(
                color: AppColors.waitlistForeground.withValues(
                  alpha: needsWaitlistAction ? 0.92 : 0.52,
                ),
                width: needsWaitlistAction ? 1.4 : 1,
              )
            : null,
      ),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${Formatters.time(session.startAt)} · 신청 ${session.reservedCount}/${session.capacity}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasWaitlist) ...[
                  const SizedBox(width: 6),
                  _WaitlistAttentionBadge(
                    label: needsWaitlistAction
                        ? '처리'
                        : '대기 ${session.waitlistCount}',
                    icon: needsWaitlistAction
                        ? Icons.notification_important_rounded
                        : Icons.hourglass_top_rounded,
                    compact: true,
                    emphasized: needsWaitlistAction,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.className,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (session.instructorName?.isNotEmpty == true) ...[
                  const SizedBox(width: 6),
                  StudioAvatar(
                    name: session.instructorName!,
                    imageUrl: session.instructorImageUrl,
                    size: 18,
                    borderRadius: 6,
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

class _AdminWeeklyScheduleView extends StatefulWidget {
  const _AdminWeeklyScheduleView({
    required this.weekStart,
    required this.selectedDay,
    required this.sessions,
    required this.onSelectDay,
  });

  static const _timeColumnWidth = 64.0;
  static const _hourHeight = 58.0;
  static const _viewportHeight = 720.0;

  final DateTime weekStart;
  final DateTime selectedDay;
  final List<AdminSessionSchedule> sessions;
  final ValueChanged<DateTime> onSelectDay;

  @override
  State<_AdminWeeklyScheduleView> createState() =>
      _AdminWeeklyScheduleViewState();
}

class _AdminWeeklyScheduleViewState extends State<_AdminWeeklyScheduleView> {
  late final ScrollController _verticalScrollController;

  @override
  void initState() {
    super.initState();
    _verticalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = List<DateTime>.generate(
      7,
      (index) => DateTime(
        widget.weekStart.year,
        widget.weekStart.month,
        widget.weekStart.day + index,
      ),
    );
    final sessionsByDay = <String, List<AdminSessionSchedule>>{
      for (final day in weekDays)
        _calendarDayKey(day): <AdminSessionSchedule>[],
    };
    for (final session in widget.sessions) {
      sessionsByDay[_calendarDayKey(session.sessionDate)]?.add(session);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = math.max(constraints.maxWidth, 1120.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: _AdminWeeklyScheduleView._timeColumnWidth,
                    ),
                    ...weekDays.map(
                      (day) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _AdminWeeklyDayHeader(
                            day: day,
                            isToday: _isSameCalendarDay(day, DateTime.now()),
                            isSelected: _isSameCalendarDay(
                              day,
                              widget.selectedDay,
                            ),
                            onTap: () => widget.onSelectDay(day),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: _AdminWeeklyScheduleView._viewportHeight,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Scrollbar(
                    controller: _verticalScrollController,
                    child: SingleChildScrollView(
                      controller: _verticalScrollController,
                      child: SizedBox(
                        height: _AdminWeeklyScheduleView._hourHeight * 24,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: _AdminWeeklyScheduleView._timeColumnWidth,
                              child: _AdminWeeklyTimeColumn(
                                hourHeight:
                                    _AdminWeeklyScheduleView._hourHeight,
                              ),
                            ),
                            const SizedBox(width: 8),
                            for (final day in weekDays)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _AdminWeeklyDayColumn(
                                    day: day,
                                    sessions:
                                        sessionsByDay[_calendarDayKey(day)] ??
                                        const <AdminSessionSchedule>[],
                                    isToday: _isSameCalendarDay(
                                      day,
                                      DateTime.now(),
                                    ),
                                    isSelected: _isSameCalendarDay(
                                      day,
                                      widget.selectedDay,
                                    ),
                                    hourHeight:
                                        _AdminWeeklyScheduleView._hourHeight,
                                    onTap: () => widget.onSelectDay(day),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminWeeklyDayHeader extends StatelessWidget {
  const _AdminWeeklyDayHeader({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primarySoft.withValues(alpha: 0.10)
                : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isToday
                        ? AppColors.todayBadgeForeground.withValues(alpha: 0.4)
                        : AppColors.border),
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                _weekdayLabelForDate(day),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSelected ? AppColors.primaryStrong : AppColors.body,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${day.month}.${day.day}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.subtle,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isToday) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.todayBadgeBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '오늘',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.todayBadgeForeground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminWeeklyTimeColumn extends StatelessWidget {
  const _AdminWeeklyTimeColumn({required this.hourHeight});

  final double hourHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var hour = 0; hour <= 24; hour++)
          Positioned(
            top: hour * hourHeight,
            left: 0,
            right: 0,
            child: Container(height: 1, color: AppColors.border),
          ),
        for (var hour = 0; hour < 24; hour++)
          Positioned(
            top: math.max(0, hour * hourHeight - 10),
            left: 0,
            right: 10,
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.subtle,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminWeeklyDayColumn extends StatelessWidget {
  const _AdminWeeklyDayColumn({
    required this.day,
    required this.sessions,
    required this.isToday,
    required this.isSelected,
    required this.hourHeight,
    required this.onTap,
  });

  final DateTime day;
  final List<AdminSessionSchedule> sessions;
  final bool isToday;
  final bool isSelected;
  final double hourHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final placements = _buildWeeklySessionPlacements(
      sessions,
      hourHeight: hourHeight,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primarySoft.withValues(alpha: 0.05)
              : (isToday
                    ? AppColors.todayBadgeBackground.withValues(alpha: 0.28)
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (var hour = 0; hour <= 24; hour++)
                  Positioned(
                    top: hour * hourHeight,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: hour == 0
                          ? Colors.transparent
                          : AppColors.border.withValues(alpha: 0.85),
                    ),
                  ),
                for (final placement in placements)
                  Positioned(
                    top: placement.top,
                    left: _weeklyPlacementLeft(
                      width: availableWidth,
                      placement: placement,
                    ),
                    width: _weeklyPlacementWidth(
                      width: availableWidth,
                      placement: placement,
                    ),
                    height: placement.height,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTap,
                      child: _AdminWeeklySessionBlock(
                        session: placement.session,
                        height: placement.height,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AdminWeeklySessionBlock extends StatelessWidget {
  const _AdminWeeklySessionBlock({required this.session, required this.height});

  final AdminSessionSchedule session;
  final double height;

  @override
  Widget build(BuildContext context) {
    final foreground = _sessionTemplateForeground(session.classTemplateId);
    final hasInstructor = session.instructorName?.isNotEmpty == true;
    final hasWaitlist = session.waitlistCount > 0;
    final needsWaitlistAction = _hasProcessableWaitlist(session);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = height < 82;
        final veryCompact = height < 60;
        final narrow = constraints.maxWidth < 136;
        final reservationLabel =
            '신청 ${session.reservedCount}/${session.capacity}';
        final timeLabel = veryCompact
            ? Formatters.time(session.startAt)
            : '${Formatters.time(session.startAt)} - ${Formatters.time(session.endAt)}';
        final labelSmall = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        );
        final labelMedium = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
          height: 1.2,
        );
        final avatarSize = veryCompact ? 16.0 : (compact ? 18.0 : 20.0);

        Widget buildWaitlistBadge() => _WaitlistAttentionBadge(
          label: needsWaitlistAction ? '처리' : '대기 ${session.waitlistCount}',
          icon: needsWaitlistAction
              ? Icons.notification_important_rounded
              : Icons.hourglass_top_rounded,
          compact: true,
          emphasized: needsWaitlistAction,
        );

        Widget buildInstructorRow({required bool showName}) {
          if (!hasInstructor) {
            return const SizedBox.shrink();
          }
          return Row(
            children: [
              StudioAvatar(
                name: session.instructorName!,
                imageUrl: session.instructorImageUrl,
                size: avatarSize,
                borderRadius: 6,
              ),
              if (showName) ...[
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    session.instructorName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelSmall,
                  ),
                ),
              ],
            ],
          );
        }

        Widget content;
        if (veryCompact) {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '$timeLabel · $reservationLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasWaitlist) ...[
                    const SizedBox(width: 6),
                    buildWaitlistBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      session.className,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelMedium,
                    ),
                  ),
                  if (hasInstructor) ...[
                    const SizedBox(width: 4),
                    StudioAvatar(
                      name: session.instructorName!,
                      imageUrl: session.instructorImageUrl,
                      size: avatarSize,
                      borderRadius: 6,
                    ),
                  ],
                ],
              ),
            ],
          );
        } else {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      timeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasWaitlist) ...[
                    const SizedBox(width: 6),
                    buildWaitlistBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                reservationLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelSmall,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  session.className,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: labelMedium,
                ),
              ),
              if (hasInstructor) ...[
                const SizedBox(height: 4),
                buildInstructorRow(showName: !narrow),
              ],
            ],
          );
        }

        return Container(
          padding: EdgeInsets.fromLTRB(
            veryCompact ? 8 : 10,
            veryCompact ? 6 : 8,
            veryCompact ? 8 : 10,
            veryCompact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: _sessionTemplateBackground(session.classTemplateId),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasWaitlist
                  ? AppColors.waitlistForeground.withValues(
                      alpha: needsWaitlistAction ? 0.92 : 0.5,
                    )
                  : foreground.withValues(alpha: 0.28),
              width: hasWaitlist && needsWaitlistAction ? 1.4 : 1,
            ),
            boxShadow: [
              const BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
              if (hasWaitlist)
                BoxShadow(
                  color: AppColors.waitlistForeground.withValues(
                    alpha: needsWaitlistAction ? 0.18 : 0.08,
                  ),
                  blurRadius: needsWaitlistAction ? 18 : 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: DefaultTextStyle(
            style: labelSmall!,
            child: content,
          ),
        );
      },
    );
  }
}

class _TemplateFilterDialog extends StatefulWidget {
  const _TemplateFilterDialog({
    required this.templates,
    required this.selectedTemplateIds,
  });

  final List<AdminClassTemplate> templates;
  final Set<String> selectedTemplateIds;

  @override
  State<_TemplateFilterDialog> createState() => _TemplateFilterDialogState();
}

class _TemplateFilterDialogState extends State<_TemplateFilterDialog> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.selectedTemplateIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '수업 템플릿 필터',
        onClose: () => Navigator.of(context).pop(widget.selectedTemplateIds),
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '선택한 수업 템플릿만 달력과 일정 리스트에 표시합니다.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilterChip(
                  selected:
                      widget.templates.isNotEmpty &&
                      _selectedIds.length == widget.templates.length,
                  label: const Text('전체'),
                  showCheckmark: false,
                  backgroundColor: AppColors.surfaceAlt,
                  selectedColor: AppColors.primarySoft.withValues(alpha: 0.14),
                  onSelected: (_) {
                    setState(() {
                      _selectedIds = widget.templates
                          .map((template) => template.id)
                          .toSet();
                    });
                  },
                ),
                ...widget.templates.map((template) {
                  final isSelected = _selectedIds.contains(template.id);
                  final background = _sessionTemplateBackground(template.id);
                  final foreground = _sessionTemplateForeground(template.id);
                  return FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    backgroundColor: background.withValues(alpha: 0.48),
                    selectedColor: background,
                    side: BorderSide(
                      color: foreground.withValues(
                        alpha: isSelected ? 0.96 : 0.36,
                      ),
                      width: isSelected ? 1.4 : 1,
                    ),
                    labelStyle: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                    avatar: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: foreground,
                        shape: BoxShape.circle,
                      ),
                    ),
                    label: Text(template.name),
                    onSelected: (selected) {
                      setState(() {
                        final next = Set<String>.from(_selectedIds);
                        if (selected) {
                          next.add(template.id);
                        } else {
                          next.remove(template.id);
                        }
                        _selectedIds = next;
                      });
                    },
                  );
                }),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _selectedIds = <String>{};
            });
          },
          child: const Text('전체 해제'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedIds),
          child: const Text('적용'),
        ),
      ],
    );
  }
}

class _SessionStatChip extends StatelessWidget {
  const _SessionStatChip({
    required this.label,
    required this.value,
    this.icon,
    this.backgroundColor = AppColors.surfaceAlt,
    this.labelColor = AppColors.subtle,
    this.valueColor = AppColors.title,
    this.borderColor = AppColors.border,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color backgroundColor;
  final Color labelColor;
  final Color valueColor;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: labelColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: child,
      ),
    );
  }
}

class _WaitlistAttentionBadge extends StatelessWidget {
  const _WaitlistAttentionBadge({
    required this.label,
    required this.icon,
    this.compact = false,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final bool compact;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final background = emphasized
        ? AppColors.waitlistForeground
        : AppColors.waitlistBackground;
    final foreground = emphasized
        ? AppColors.onPrimary
        : AppColors.waitlistForeground;
    final showIcon = !compact;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.waitlistForeground,
          width: emphasized ? 1.3 : 1,
        ),
        boxShadow: emphasized
            ? [
                BoxShadow(
                  color: AppColors.waitlistForeground.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitlistActionCard extends StatelessWidget {
  const _WaitlistActionCard({
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.emphasized = false,
  });

  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final indicatorColor = emphasized
        ? AppColors.onPrimary
        : AppColors.waitlistForeground;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.waitlistBackground
            : AppColors.waitlistBackground.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.waitlistForeground,
          width: emphasized ? 1.5 : 1,
        ),
        boxShadow: emphasized
            ? [
                BoxShadow(
                  color: AppColors.waitlistForeground.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: emphasized
                  ? AppColors.waitlistForeground
                  : AppColors.waitlistForeground.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: 12,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.title,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.body,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 12),
            emphasized
                ? FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.waitlistForeground,
                      foregroundColor: AppColors.onPrimary,
                    ),
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.waitlistForeground,
                      side: const BorderSide(
                        color: AppColors.waitlistForeground,
                      ),
                    ),
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
          ],
        ],
      ),
    );
  }
}

class _SessionActionChip extends StatelessWidget {
  const _SessionActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primarySoft.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddMemberToSessionDialog extends StatefulWidget {
  const _AddMemberToSessionDialog({required this.session});

  final AdminSessionSchedule session;

  @override
  State<_AddMemberToSessionDialog> createState() =>
      _AddMemberToSessionDialogState();
}

class _AddMemberToSessionDialogState extends State<_AddMemberToSessionDialog> {
  final _memberCodeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _memberCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.session.className} 회원 추가'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${Formatters.monthDay(widget.session.sessionDate)} ${Formatters.time(widget.session.startAt)} - ${Formatters.time(widget.session.endAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _memberCodeController,
              enabled: !_submitting,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '회원 ID',
                hintText: '학생 앱의 회원 ID 입력',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 10),
            Text(
              '사용 가능한 수강권이 남아 있는 회원만 직접 추가할 수 있습니다. 정원이 모두 찬 수업은 이 화면에서 비활성화되며, 동시에 다른 예약이 들어오면 대기로 등록될 수 있습니다.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.errorForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '추가 중...' : '추가'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final memberCode = _memberCodeController.text.trim();
    if (memberCode.isEmpty) {
      setState(() {
        _error = '회원 ID를 입력하세요.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final status = await context.read<AdminRepository>().addMemberToSession(
        sessionId: widget.session.id,
        memberCode: memberCode,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        status == 'waitlisted'
            ? '정원이 가득 차서 회원을 대기자로 등록했습니다.'
            : '회원을 수업에 추가했습니다.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _submitting = false;
      });
    }
  }
}

enum _SessionAttendeeFilter { all, reserved, waitlisted }

class _SessionAttendeesDialog extends StatefulWidget {
  const _SessionAttendeesDialog({
    required this.session,
    required this.initialFilter,
    required this.lockFilter,
    this.onChanged,
  });

  final AdminSessionSchedule session;
  final _SessionAttendeeFilter initialFilter;
  final bool lockFilter;
  final Future<void> Function()? onChanged;

  @override
  State<_SessionAttendeesDialog> createState() =>
      _SessionAttendeesDialogState();
}

class _SessionAttendeesDialogState extends State<_SessionAttendeesDialog> {
  bool _loading = true;
  bool _mutating = false;
  String? _error;
  List<AdminSessionAttendee> _attendees = const [];
  late _SessionAttendeeFilter _selectedFilter;

  bool get _waitlistOnlyMode =>
      widget.lockFilter &&
      widget.initialFilter == _SessionAttendeeFilter.waitlisted;

  bool get _reservedOnlyMode =>
      widget.lockFilter &&
      widget.initialFilter == _SessionAttendeeFilter.reserved;

  int get _reservedCount => _attendees
      .where((attendee) => _isReservedBucketStatus(attendee.status))
      .length;

  int get _waitlistCount =>
      _attendees.where((attendee) => attendee.status == 'waitlisted').length;

  List<AdminSessionAttendee> get _waitlistedAttendees =>
      _attendees
          .where((attendee) => attendee.status == 'waitlisted')
          .toList(growable: false)
        ..sort((left, right) {
          final byOrder = (left.waitlistOrder ?? 999999).compareTo(
            right.waitlistOrder ?? 999999,
          );
          if (byOrder != 0) {
            return byOrder;
          }
          return left.createdAt.compareTo(right.createdAt);
        });

  int get _availableSeatCount =>
      math.max(widget.session.capacity - _reservedCount, 0);

  bool get _canProcessWaitlist =>
      widget.session.status == 'scheduled' &&
      widget.session.startAt.isAfter(DateTime.now()) &&
      _waitlistCount > 0;

  bool get _needsImmediateWaitlistAction =>
      _canProcessWaitlist && _availableSeatCount > 0;

  String? get _topWaitlistedReservationId => _waitlistedAttendees.isEmpty
      ? null
      : _waitlistedAttendees.first.reservationId;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: _waitlistOnlyMode
            ? '대기'
            : _reservedOnlyMode
            ? '예약'
            : '예약 회원 관리',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: _waitlistOnlyMode ? 620 : 560,
        child: _buildContent(context),
      ),
      actions: [
        TextButton(
          onPressed: _mutating ? null : () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Text(
            _error!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.errorForeground),
          ),
        ),
      );
    }

    final filteredAttendees = _filteredAttendees();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 540),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.session.className}\n${Formatters.monthDay(widget.session.sessionDate)} ${Formatters.time(widget.session.startAt)} · 총 ${_attendees.length}명 · 예약 $_reservedCount명 · 대기 $_waitlistCount명',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
          ),
          if (_waitlistCount > 0) ...[
            const SizedBox(height: 12),
            _WaitlistActionCard(
              title: _needsImmediateWaitlistAction
                  ? '대기 $_waitlistCount명, 승급 처리 필요'
                  : '대기 $_waitlistCount명',
              description: _needsImmediateWaitlistAction
                  ? '빈 자리가 $_availableSeatCount석 생겨 순번대로 예약 승급 또는 대기 취소를 진행해야 합니다.'
                  : (_selectedFilter == _SessionAttendeeFilter.waitlisted
                        ? '현재는 빈 자리가 없어 예약으로 변경할 수 없습니다. 빈 자리가 생기면 상위 순번부터 순서대로 연락 후 처리하세요.'
                        : '이 수업에 대기 회원이 있습니다. 필요하면 대기 섹션으로 이동해 순번과 연락처를 확인하세요.'),
              actionLabel:
                  !widget.lockFilter &&
                      _selectedFilter != _SessionAttendeeFilter.waitlisted
                  ? '대기 보기'
                  : null,
              onAction:
                  !widget.lockFilter &&
                      _selectedFilter != _SessionAttendeeFilter.waitlisted
                  ? () {
                      setState(() {
                        _selectedFilter = _SessionAttendeeFilter.waitlisted;
                      });
                    }
                  : null,
              emphasized: _needsImmediateWaitlistAction,
            ),
          ],
          const SizedBox(height: 14),
          if (!widget.lockFilter) ...[
            FilledButton.tonalIcon(
              onPressed:
                  _mutating ||
                      widget.session.status != 'scheduled' ||
                      _availableSeatCount <= 0
                  ? null
                  : _openAddMemberDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('+ 회원 직접 추가'),
            ),
            if (widget.session.status == 'scheduled' &&
                _availableSeatCount <= 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '정원이 모두 차서 회원 직접 추가는 비활성화됩니다. 대기 관리는 대기 섹션에서 처리하세요.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.subtle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text('전체 ${_attendees.length}'),
                  selected: _selectedFilter == _SessionAttendeeFilter.all,
                  onSelected: (_) {
                    setState(() {
                      _selectedFilter = _SessionAttendeeFilter.all;
                    });
                  },
                ),
                ChoiceChip(
                  label: Text('예약 $_reservedCount'),
                  selected: _selectedFilter == _SessionAttendeeFilter.reserved,
                  onSelected: (_) {
                    setState(() {
                      _selectedFilter = _SessionAttendeeFilter.reserved;
                    });
                  },
                ),
                ChoiceChip(
                  label: Text('대기 $_waitlistCount'),
                  selected:
                      _selectedFilter == _SessionAttendeeFilter.waitlisted,
                  onSelected: (_) {
                    setState(() {
                      _selectedFilter = _SessionAttendeeFilter.waitlisted;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Expanded(
            child: filteredAttendees.isEmpty
                ? Center(child: Text(_emptyAttendeeMessage()))
                : ListView.separated(
                    itemCount: filteredAttendees.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final attendee = filteredAttendees[index];
                      if (attendee.status == 'waitlisted') {
                        return _buildWaitlistedAttendeeRow(context, attendee);
                      }
                      return _buildStandardAttendeeRow(context, attendee);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<AdminSessionAttendee> _filteredAttendees() {
    switch (_selectedFilter) {
      case _SessionAttendeeFilter.all:
        return _attendees;
      case _SessionAttendeeFilter.reserved:
        return _attendees
            .where((attendee) => _isReservedBucketStatus(attendee.status))
            .toList(growable: false);
      case _SessionAttendeeFilter.waitlisted:
        return _waitlistedAttendees;
    }
  }

  String _emptyAttendeeMessage() {
    switch (_selectedFilter) {
      case _SessionAttendeeFilter.all:
      case _SessionAttendeeFilter.reserved:
        return '예약한 회원이 없습니다.';
      case _SessionAttendeeFilter.waitlisted:
        return '대기 중인 회원이 없습니다.';
    }
  }

  Widget _buildStandardAttendeeRow(
    BuildContext context,
    AdminSessionAttendee attendee,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      attendee.name?.trim().isNotEmpty == true
                          ? attendee.name!
                          : attendee.memberCode,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    StatusPill(
                      label: '회원 ID ${attendee.memberCode}',
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primaryStrong,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  attendee.memberPhone?.trim().isNotEmpty == true
                      ? Formatters.phone(attendee.memberPhone)
                      : '핸드폰 번호 없음',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.subtle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StatusPill(
            label: _attendeeStatusLabel(attendee.status),
            backgroundColor: _attendeeStatusBackground(attendee.status),
            foregroundColor: _attendeeStatusForeground(attendee.status),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _mutating || widget.session.status != 'scheduled'
                ? null
                : () => _removeAttendee(attendee),
            tooltip: widget.session.status == 'scheduled'
                ? '스튜디오 취소'
                : '예정 수업에서만 제외할 수 있습니다',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.errorBackground,
              foregroundColor: AppColors.errorForeground,
            ),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitlistedAttendeeRow(
    BuildContext context,
    AdminSessionAttendee attendee,
  ) {
    final isTopWaitlisted =
        attendee.reservationId == _topWaitlistedReservationId;
    final canCancel =
        isTopWaitlisted &&
        _canProcessWaitlist &&
        !_mutating &&
        widget.session.status == 'scheduled' &&
        widget.session.startAt.isAfter(DateTime.now());
    final canApprove = canCancel && _availableSeatCount > 0;
    final helperText = !isTopWaitlisted
        ? '앞 순번을 먼저 처리해야 이 회원을 진행할 수 있습니다.'
        : _availableSeatCount > 0
        ? '전화로 참여 의사를 확인한 뒤 예약으로 변경하거나 대기 취소를 진행하세요.'
        : '현재 빈 자리가 없어 예약으로 변경할 수 없습니다. 필요 시 대기 취소만 처리하세요.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                attendee.name?.trim().isNotEmpty == true
                    ? attendee.name!
                    : attendee.memberCode,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              StatusPill(
                label: '회원 ID ${attendee.memberCode}',
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.primaryStrong,
              ),
              StatusPill(
                label: '${attendee.waitlistOrder ?? 0}순번',
                backgroundColor: isTopWaitlisted
                    ? AppColors.waitlistBackground
                    : AppColors.neutralBackground,
                foregroundColor: isTopWaitlisted
                    ? AppColors.waitlistForeground
                    : AppColors.neutralForeground,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildWaitlistContactRow(
            context,
            icon: Icons.phone_rounded,
            value: attendee.memberPhone?.trim().isNotEmpty == true
                ? Formatters.phone(attendee.memberPhone)
                : '핸드폰 번호 없음',
          ),
          const SizedBox(height: 6),
          _buildWaitlistContactRow(
            context,
            icon: Icons.mail_outline_rounded,
            value: attendee.memberEmail?.trim().isNotEmpty == true
                ? attendee.memberEmail!
                : '이메일 없음',
          ),
          const SizedBox(height: 10),
          Text(
            helperText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.subtle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: canCancel ? () => _removeAttendee(attendee) : null,
                child: const Text('대기 취소'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: canApprove
                    ? () => _approveWaitlistedAttendee(attendee)
                    : null,
                child: const Text('예약으로 변경'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaitlistContactRow(
    BuildContext context, {
    required IconData icon,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.subtle),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.title,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openAddMemberDialog() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          _AddMemberToSessionDialog(session: widget.session),
    );

    if (added != true || !mounted) {
      return;
    }

    await widget.onChanged?.call();
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final attendees = await context
          .read<AdminRepository>()
          .fetchSessionAttendees(sessionId: widget.session.id);
      if (!mounted) {
        return;
      }
      final sortedAttendees = [...attendees]
        ..sort((left, right) {
          final byStatus = _attendeeStatusOrder(
            left.status,
          ).compareTo(_attendeeStatusOrder(right.status));
          if (byStatus != 0) {
            return byStatus;
          }
          if (left.status == 'waitlisted' && right.status == 'waitlisted') {
            final byOrder = (left.waitlistOrder ?? 999999).compareTo(
              right.waitlistOrder ?? 999999,
            );
            if (byOrder != 0) {
              return byOrder;
            }
            return left.createdAt.compareTo(right.createdAt);
          }
          return (left.name ?? left.memberCode).compareTo(
            right.name ?? right.memberCode,
          );
        });
      setState(() {
        _attendees = sortedAttendees;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _removeAttendee(AdminSessionAttendee attendee) async {
    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _StudioCancelCommentDialog(
        memberName: attendee.name ?? attendee.memberCode,
        className: widget.session.className,
      ),
    );

    if (comment == null || !mounted) {
      return;
    }

    setState(() {
      _mutating = true;
    });

    try {
      await context.read<AdminRepository>().removeMemberFromSession(
        reservationId: attendee.reservationId,
        comment: comment,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        attendee.status == 'waitlisted'
            ? '대기 회원을 스튜디오 취소 처리했습니다.'
            : '회원을 스튜디오 취소 처리했습니다.',
      );
      await widget.onChanged?.call();
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, error.toString(), isError: true);
      setState(() {
        _mutating = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _mutating = false;
      });
    }
  }

  Future<void> _approveWaitlistedAttendee(AdminSessionAttendee attendee) async {
    setState(() {
      _mutating = true;
    });

    try {
      await context.read<AdminRepository>().approveWaitlistedReservation(
        reservationId: attendee.reservationId,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, '대기 회원을 예약으로 변경했습니다.');
      await widget.onChanged?.call();
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, error.toString(), isError: true);
      setState(() {
        _mutating = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _mutating = false;
      });
    }
  }
}

class _EditSessionPassProductsDialog extends StatefulWidget {
  const _EditSessionPassProductsDialog({
    required this.session,
    required this.products,
    required this.initialPassProductIds,
  });

  final AdminSessionSchedule session;
  final List<AdminPassProduct> products;
  final Set<String> initialPassProductIds;

  @override
  State<_EditSessionPassProductsDialog> createState() =>
      _EditSessionPassProductsDialogState();
}

class _EditSessionPassProductsDialogState
    extends State<_EditSessionPassProductsDialog> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.initialPassProductIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '수강 가능 수강권 수정',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.session.className}\n${Formatters.monthDay(widget.session.sessionDate)} ${Formatters.time(widget.session.startAt)} - ${Formatters.time(widget.session.endAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
            ),
            const SizedBox(height: 16),
            Text(
              '이 수업에 연결할 수강권을 선택하세요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.session.category != '일회성') ...[
              const SizedBox(height: 6),
              Text(
                '반복 수업은 같은 수업 템플릿으로 개설된 다른 회차에도 함께 반영됩니다.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.products
                  .map(
                    (product) => FilterChip(
                      selected: _selectedIds.contains(product.id),
                      label: Text(product.name),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedIds = {..._selectedIds, product.id};
                          } else {
                            _selectedIds = {..._selectedIds}
                              ..remove(product.id);
                          }
                        });
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
            if (_selectedIds.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '수강권 상품을 한 개 이상 선택해야 합니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.errorForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.of(
                  context,
                ).pop(_selectedIds.toList(growable: false)),
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _EditSessionCapacityDialog extends StatefulWidget {
  const _EditSessionCapacityDialog({required this.session});

  final AdminSessionSchedule session;

  @override
  State<_EditSessionCapacityDialog> createState() =>
      _EditSessionCapacityDialogState();
}

class _EditSessionCapacityDialogState
    extends State<_EditSessionCapacityDialog> {
  late final TextEditingController _capacityController;

  int get _reservedCount => widget.session.reservedCount;

  int? get _parsedCapacity => int.tryParse(_capacityController.text.trim());

  String? get _errorText {
    final capacity = _parsedCapacity;
    if (capacity == null) {
      return '예약 가능 인원수를 숫자로 입력하세요.';
    }
    if (capacity <= 0) {
      return '예약 가능 인원수는 1명 이상이어야 합니다.';
    }
    if (capacity < _reservedCount) {
      return '현재 예약 $_reservedCount명보다 작게 설정할 수 없습니다.';
    }
    return null;
  }

  bool get _canSave => _errorText == null;

  @override
  void initState() {
    super.initState();
    _capacityController = TextEditingController(
      text: '${widget.session.capacity}',
    );
  }

  @override
  void dispose() {
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '예약 가능 인원수 수정',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.session.className}\n${Formatters.monthDay(widget.session.sessionDate)} ${Formatters.time(widget.session.startAt)} - ${Formatters.time(widget.session.endAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
            ),
            const SizedBox(height: 16),
            Text(
              '현재 예약 $_reservedCount명 · 현재 정원 ${widget.session.capacity}명',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _capacityController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '예약 가능 인원수',
                helperText: _errorText,
                helperStyle: TextStyle(
                  color: _errorText == null
                      ? AppColors.subtle
                      : AppColors.errorForeground,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: _canSave
              ? () => Navigator.of(context).pop(_parsedCapacity)
              : null,
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _StudioCancelCommentDialog extends StatefulWidget {
  const _StudioCancelCommentDialog({
    required this.memberName,
    required this.className,
  });

  final String memberName;
  final String className;

  @override
  State<_StudioCancelCommentDialog> createState() =>
      _StudioCancelCommentDialogState();
}

class _StudioCancelCommentDialogState
    extends State<_StudioCancelCommentDialog> {
  final TextEditingController _commentController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '스튜디오 취소 사유',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.memberName} 회원을 ${widget.className} 수업에서 스튜디오 취소 처리합니다.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '취소 사유',
                hintText: '회원 앱에 표시할 사유를 입력하세요.',
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.errorForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [FilledButton(onPressed: _submit, child: const Text('저장'))],
    );
  }

  void _submit() {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      setState(() {
        _error = '취소 사유를 입력하세요.';
      });
      return;
    }

    Navigator.of(context).pop(comment);
  }
}

class _CancelRequestsPage extends StatefulWidget {
  const _CancelRequestsPage({
    required this.isActive,
    this.onAttentionChanged,
  });

  final bool isActive;
  final VoidCallback? onAttentionChanged;

  @override
  State<_CancelRequestsPage> createState() => _CancelRequestsPageState();
}

class _CancelRequestsPageState extends State<_CancelRequestsPage> {
  List<AdminCancelRequest> _pendingRequests = const [];
  List<AdminCancelRequest> _requests = const [];
  bool _loading = false;
  bool _updatingCancelInquiry = false;
  String? _error;
  String? _studioId;
  String? _memberFilter;
  int? _monthsFilter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final studioId = context.read<AdminSessionController>().profile?.studioId;
    if (studioId != null && studioId != _studioId) {
      _studioId = studioId;
      Future<void>.microtask(_refresh);
    }
  }

  @override
  void didUpdateWidget(covariant _CancelRequestsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      Future<void>.microtask(_refresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AdminSessionController>().profile!;
    final pendingRequests = _pendingRequests;
    final processedRequests = _filteredProcessedRequests;

    return _AdminPageFrame(
      title: '취소 관리',
      subtitle: '취소 정책/요청 처리',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonalIcon(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('새로고침'),
          ),
        ],
      ),
      child: _error != null
          ? ErrorSection(message: _error!, onRetry: _refresh)
          : _loading && _requests.isEmpty
          ? const LoadingSection()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '취소 정책 처리',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '현재 적용된 취소 정책',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: AppColors.subtle,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _cancelPolicySummary(profile.studio),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.body,
                                        height: 1.5,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              _openCancelPolicyDialog(profile.studio);
                            },
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text('취소 정책 수정'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SurfaceCard(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      profile.studio.cancelInquiryEnabled
                          ? '취소 문의 앱 내 허용'
                          : '취소 문의 앱 내 비허용',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      profile.studio.cancelInquiryEnabled
                          ? '직접 취소 마감 이후에도 회원이 앱에서 취소 문의를 보낼 수 있습니다.'
                          : '직접 취소 마감 이후에는 앱 문의를 막고 스튜디오 직접 문의 안내만 노출합니다.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                    value: profile.studio.cancelInquiryEnabled,
                    onChanged: _updatingCancelInquiry
                        ? null
                        : (value) {
                            _updateCancelInquiryPolicy(
                              studio: profile.studio,
                              enabled: value,
                            );
                          },
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '대기 중인 취소 요청',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SurfaceCard(
                  child: pendingRequests.isEmpty
                      ? const Text('대기 중인 취소 요청이 없습니다')
                      : Column(
                          children: [
                            for (
                              var index = 0;
                              index < pendingRequests.length;
                              index++
                            ) ...[
                              _PendingCancelRequestCard(
                                request: pendingRequests[index],
                                onApprove: () {
                                  _respondToCancelRequest(
                                    pendingRequests[index],
                                    approve: true,
                                  );
                                },
                                onReject: () {
                                  _respondToCancelRequest(
                                    pendingRequests[index],
                                    approve: false,
                                  );
                                },
                              ),
                              if (index < pendingRequests.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '처리 완료 이력',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _openProcessedHistoryFilterDialog,
                      tooltip: '처리 완료 이력 필터',
                      style: IconButton.styleFrom(
                        backgroundColor:
                            _memberFilter != null || _monthsFilter != null
                            ? AppColors.infoBackground
                            : AppColors.surfaceAlt,
                        foregroundColor:
                            _memberFilter != null || _monthsFilter != null
                            ? AppColors.infoForeground
                            : AppColors.title,
                      ),
                      icon: const Icon(Icons.filter_alt_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (processedRequests.isEmpty)
                  const EmptySection(
                    title: '처리 완료 이력이 없습니다',
                    description: '조건에 맞는 승인/거절 이력이 여기에 표시됩니다.',
                  )
                else
                  ...processedRequests.map(
                    (request) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${request.memberName ?? request.memberCode} · ${request.className}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${request.memberCode} · ${Formatters.full(request.startAt)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: AppColors.subtle),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusPill(
                                  label: _processedStatusLabel(request),
                                  backgroundColor: request.isApproved
                                      ? AppColors.successBackground
                                      : AppColors.neutralBackground,
                                  foregroundColor: request.isApproved
                                      ? AppColors.successForeground
                                      : AppColors.neutralForeground,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _CancelDetailRow(
                              label: '회원 요청',
                              value: request.requestCancelReason ?? '사유 없음',
                            ),
                            const SizedBox(height: 8),
                            _CancelDetailRow(
                              label: '관리자 코멘트',
                              value: request.responseComment ?? '코멘트 없음',
                            ),
                            const SizedBox(height: 8),
                            _CancelDetailRow(
                              label: '처리 정보',
                              value:
                                  '${request.processedAdminName ?? '관리자'} · ${request.processedAt != null ? Formatters.full(request.processedAt!) : '처리 시각 없음'}',
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

  Future<void> _refresh() async {
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        context.read<AdminRepository>().fetchPendingCancelRequests(studioId),
        context.read<AdminRepository>().fetchCancelRequests(studioId),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingRequests = results[0];
        _requests = results[1];
      });
      widget.onAttentionChanged?.call();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _respondToCancelRequest(
    AdminCancelRequest request, {
    required bool approve,
  }) async {
    final repository = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _CancelDecisionDialog(approve: approve),
    );

    if (comment == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (!approve && comment.trim().isEmpty) {
      showAppSnackBar(context, '거절 사유를 입력하세요.', isError: true);
      return;
    }

    try {
      if (approve) {
        await repository.approveCancelRequest(
          reservationId: request.id,
          comment: comment,
        );
      } else {
        await repository.rejectCancelRequest(
          reservationId: request.id,
          comment: comment,
        );
      }
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(
        messenger,
        approve ? '취소 요청을 승인했습니다.' : '취소 요청을 거절했습니다.',
      );
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, error.toString(), isError: true);
    }
  }

  Future<void> _openCancelPolicyDialog(AdminStudioSummary studio) async {
    final formData = await showDialog<_StudioCancelPolicyFormData>(
      context: context,
      builder: (dialogContext) =>
          _StudioCancelPolicyDialog(initialStudio: studio),
    );

    if (formData == null || !mounted) {
      return;
    }

    final repository = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repository.updateStudioCancelPolicy(
        studioId: studio.id,
        cancelPolicyMode: formData.cancelPolicyMode,
        cancelPolicyHoursBefore: formData.cancelPolicyHoursBefore,
        cancelPolicyDaysBefore: formData.cancelPolicyDaysBefore,
        cancelPolicyCutoffTime: formData.cancelPolicyCutoffTime,
        cancelInquiryEnabled: studio.cancelInquiryEnabled,
      );
      if (!mounted) {
        return;
      }
      await context.read<AdminSessionController>().refresh();
      await _refresh();
      showAppSnackBarWithMessenger(messenger, '취소 정책을 저장했습니다.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, error.toString(), isError: true);
    }
  }

  Future<void> _updateCancelInquiryPolicy({
    required AdminStudioSummary studio,
    required bool enabled,
  }) async {
    setState(() {
      _updatingCancelInquiry = true;
    });

    final repository = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repository.updateStudioCancelPolicy(
        studioId: studio.id,
        cancelPolicyMode: studio.cancelPolicyMode,
        cancelPolicyHoursBefore: studio.cancelPolicyHoursBefore,
        cancelPolicyDaysBefore: studio.cancelPolicyDaysBefore,
        cancelPolicyCutoffTime: studio.cancelPolicyCutoffTime,
        cancelInquiryEnabled: enabled,
      );
      if (!mounted) {
        return;
      }
      await context.read<AdminSessionController>().refresh();
      await _refresh();
      showAppSnackBarWithMessenger(
        messenger,
        enabled ? '취소 문의를 앱에서 허용했습니다.' : '취소 문의를 앱에서 비허용으로 변경했습니다.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _updatingCancelInquiry = false;
        });
      }
    }
  }

  Future<void> _openProcessedHistoryFilterDialog() async {
    final formData = await showDialog<_ProcessedCancelHistoryFilterFormData>(
      context: context,
      builder: (dialogContext) => _ProcessedCancelHistoryFilterDialog(
        memberFilter: _memberFilter,
        monthsFilter: _monthsFilter,
        availableMembers: _availableMemberFilters,
      ),
    );

    if (formData == null || !mounted) {
      return;
    }

    setState(() {
      _memberFilter = formData.memberFilter;
      _monthsFilter = formData.monthsFilter;
    });
  }

  List<String> get _availableMemberFilters {
    final values =
        _requests
            .map((request) => request.memberName ?? request.memberCode)
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return values;
  }

  List<AdminCancelRequest> get _filteredProcessedRequests {
    final cutoff = _monthsFilter == null
        ? null
        : DateTime.now().subtract(Duration(days: _monthsFilter! * 30));

    return _requests
        .where((request) {
          if (request.isPending) {
            return false;
          }

          final memberLabel = request.memberName ?? request.memberCode;
          final matchesMember =
              _memberFilter == null || _memberFilter == memberLabel;
          final referenceDate =
              request.processedAt ??
              request.requestedCancelAt ??
              request.startAt;
          final matchesPeriod =
              cutoff == null || !referenceDate.isBefore(cutoff);
          return matchesMember && matchesPeriod;
        })
        .toList(growable: false)
      ..sort((left, right) {
        final leftDate =
            left.processedAt ?? left.requestedCancelAt ?? left.startAt;
        final rightDate =
            right.processedAt ?? right.requestedCancelAt ?? right.startAt;
        return rightDate.compareTo(leftDate);
      });
  }

  String _processedStatusLabel(AdminCancelRequest request) {
    if (request.isApproved) {
      return '승인';
    }
    if (request.isRejected) {
      return '거절';
    }
    return Formatters.reservationStatus(request.status);
  }
}

class _AdminGuidePage extends StatelessWidget {
  const _AdminGuidePage();

  @override
  Widget build(BuildContext context) {
    return _AdminPageFrame(
      title: '사용법 설명',
      subtitle: '수업 템플릿, 수강권, 회원 노출, 취소 정책까지 실제 운영 흐름 기준으로 정리했습니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DashboardSectionHeading(
            icon: Icons.account_tree_rounded,
            title: '한눈에 보는 운영 흐름',
            description:
                '먼저 템플릿을 만들고, 그 템플릿을 수강권에 연결한 뒤, 회원에게 수강권을 발급하고 수업을 개설하는 순서로 운영합니다.',
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              children: const [
                _GuideFlowStep(
                  step: '1',
                  icon: Icons.view_week_rounded,
                  title: '수업 템플릿 만들기',
                  description: '반복 수업 규칙을 등록합니다. 실제 수업 개설의 기준이 됩니다.',
                ),
                _GuideFlowArrow(),
                _GuideFlowStep(
                  step: '2',
                  icon: Icons.confirmation_num_rounded,
                  title: '수강권 상품 만들기',
                  description: '이 수강권으로 어떤 수업 템플릿을 예약할 수 있는지 연결합니다.',
                ),
                _GuideFlowArrow(),
                _GuideFlowStep(
                  step: '3',
                  icon: Icons.groups_rounded,
                  title: '회원에게 수강권 발급',
                  description: '회원 관리에서 실제 결제 금액과 유효기간을 설정해 발급합니다.',
                ),
                _GuideFlowArrow(),
                _GuideFlowStep(
                  step: '4',
                  icon: Icons.calendar_month_rounded,
                  title: '수업 개설 및 앱 노출',
                  description: '회원은 자신이 가진 수강권으로 예약 가능한 수업만 앱 달력에서 보게 됩니다.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _DashboardSectionHeading(
            icon: Icons.link_rounded,
            title: '1. 수업 템플릿과 수강권의 관계',
            description:
                '이 앱에서 가장 중요한 구조입니다. 템플릿과 수강권 연결이 잘 되어야 학생 앱에서 수업이 올바르게 보입니다.',
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _GuideTag(label: '수업 템플릿'),
                    _GuideTag(label: '수강권 상품'),
                    _GuideTag(label: '회원 관리'),
                    _GuideTag(label: '학생 앱 달력'),
                  ],
                ),
                SizedBox(height: 14),
                _GuideBulletList(
                  items: [
                    '수업 템플릿은 실제 수업 관리 페이지에서 회차를 개설하기 위한 기준입니다.',
                    '수강권 상품을 만들 때 이 수강권으로 예약 가능한 수업 템플릿을 선택합니다.',
                    '수강권 상품은 만든 뒤 끝이 아니라, 회원 관리 탭에서 실제 회원에게 발급해야 효력이 생깁니다.',
                    '특정 수강권을 받은 회원은 그 수강권으로 예약 가능한 수업만 앱 내 달력에서 보게 됩니다.',
                  ],
                ),
                SizedBox(height: 16),
                _GuideCallout(
                  icon: Icons.lightbulb_rounded,
                  title: '예시: 성인 발레 수강권',
                  items: [
                    '수강권 상품 이름을 성인 발레 수강권으로 만듭니다.',
                    '예약 가능한 수업으로 성인 발레 Lv.1, 성인 발레 Lv.2 템플릿을 연결합니다.',
                    '이 수강권을 발급받은 회원은 앱 달력에서 성인 발레 Lv.1, 성인 발레 Lv.2 수업을 보게 됩니다.',
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _DashboardSectionHeading(
            icon: Icons.auto_awesome_motion_rounded,
            title: '2. 특강·이벤트 수업은 일회성 수업으로 개설',
            description:
                '특강이나 이벤트 수업은 템플릿 반복 개설이 아니라 수업 관리의 일회성 수업 생성으로 만드는 것이 자연스럽습니다.',
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GuideBulletList(
                  items: [
                    '수업 관리 > 수업 개설 > 일회성 수업 생성에서 특강, 워크숍, 이벤트성 수업을 등록할 수 있습니다.',
                    '이때 노출 수강권을 반드시 선택해야 어떤 회원에게 이 수업이 보일지 결정됩니다.',
                    '선택한 수강권을 가진 회원에게만 해당 일회성 수업이 앱 달력에 노출됩니다.',
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: const [
                    SizedBox(
                      width: 320,
                      child: _GuideCallout(
                        icon: Icons.self_improvement_rounded,
                        title: '발레 특강 예시',
                        items: [
                          '발레 특강을 개설할 때 발레 수강권을 노출 수강권으로 선택합니다.',
                          '그러면 발레 수강권이 있는 회원 달력에만 이 특강이 보입니다.',
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: _GuideCallout(
                        icon: Icons.fitness_center_rounded,
                        title: '필라테스 특강 예시',
                        items: [
                          '필라테스 특강을 개설할 때 필라테스 수강권을 노출 수강권으로 선택합니다.',
                          '발레 회원이 아니라 필라테스 수강권 보유 회원에게만 수업이 노출됩니다.',
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _DashboardSectionHeading(
            icon: Icons.badge_rounded,
            title: '3. 강사 등록과 스케줄 확인',
            description: '강사를 등록해 두면 월별 스케줄과 진행 수업 내역을 한눈에 확인할 수 있습니다.',
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _GuideBulletList(
                  items: [
                    '강사 관리에서 강사를 먼저 등록합니다.',
                    '수업 관리에서 각 수업 회차에 실제 강사를 배정해야 강사 스케줄과 진행 수업 수가 정확히 집계됩니다.',
                    '강사가 등록되어 있기만 한 것은 집계 기준이 아니고, 수업 관리에서 그 강사가 선택된 회차만 카운팅됩니다.',
                  ],
                ),
                SizedBox(height: 16),
                _GuideCallout(
                  icon: Icons.event_note_rounded,
                  title: '운영 팁',
                  items: [
                    '강사 스케줄이 중요하다면 수업 개설 후 강사 배정을 빠뜨리지 않는 것이 좋습니다.',
                    '강사 변경이 생기면 수업 관리에서 해당 회차를 수정해야 월별 기록이 맞게 보입니다.',
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _DashboardSectionHeading(
            icon: Icons.pending_actions_rounded,
            title: '4. 취소 정책과 취소 요청 흐름',
            description:
                '학생은 자유롭게 신청과 취소를 할 수 있지만, 취소 관리에서 설정한 정책 시간 안으로 들어오면 처리 방식이 달라집니다.',
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: const [
                    SizedBox(
                      width: 300,
                      child: _GuideDecisionCard(
                        icon: Icons.check_circle_outline_rounded,
                        title: '취소 가능 시간 이전',
                        description: '학생이 앱에서 직접 취소할 수 있습니다.',
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: _GuideDecisionCard(
                        icon: Icons.mark_email_read_rounded,
                        title: '취소 가능 시간 이후 + 앱 문의 허용',
                        description:
                            '학생이 앱에서 취소 요청을 보내고, 관리자는 취소 관리 탭에서 승인 또는 거절합니다.',
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: _GuideDecisionCard(
                        icon: Icons.phone_disabled_rounded,
                        title: '취소 가능 시간 이후 + 앱 문의 비허용',
                        description:
                            '학생은 앱에서 더 이상 취소 요청을 보내지 못하고 스튜디오에 직접 문의해야 합니다.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _GuideBulletList(
                  items: [
                    '취소 관리 페이지에서 직접 취소 가능 시간과 취소 문의 앱 내 허용 여부를 함께 운영합니다.',
                    '취소 문의를 허용하면 학생은 정책 마감 후에도 앱에서 요청을 보낼 수 있습니다.',
                    '취소 문의를 비허용으로 두면 앱 내 요청은 막히고 직접 연락 안내만 남습니다.',
                  ],
                ),
                const SizedBox(height: 16),
                const _GuideCallout(
                  icon: Icons.queue_rounded,
                  title: '대기 처리: 관리자가 직접 승인',
                  items: [
                    '수업 관리에서 각 수업 카드의 대기 버튼을 누르면 순번대로 대기 명단을 확인할 수 있습니다.',
                    '대기 회원은 자동으로 예약 확정되지 않습니다.',
                    '관리자가 직접 전화로 참여 의사를 확인한 뒤 예약으로 변경하거나 대기 취소를 처리합니다.',
                    '앞 순번 대기를 먼저 처리해야 다음 순번 버튼이 활성화되므로, 반드시 순서대로 안내하고 처리해야 합니다.',
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _DashboardSectionHeading(
            icon: Icons.manage_accounts_rounded,
            title: '5. 회원에게 수강권 발급하고, 필요하면 나중에 수정',
            description:
                '수강권은 회원 관리 탭에서 발급하고, 실제 수납 금액이나 프로모션 조건에 맞춰 유연하게 조정할 수 있습니다.',
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GuideBulletList(
                  items: [
                    '회원 관리 탭에서 회원을 검색하고 원하는 수강권을 발급할 수 있습니다.',
                    '발급 시 실제로 받은 금액을 입력해 수납 금액을 다르게 기록할 수 있습니다.',
                    '프로모션이나 보상으로 기간을 다르게 줘야 하면 수강권 이력 팝업에서 시작일과 종료일을 수정하면 됩니다.',
                    '중간 환불 처리나 홀딩 처리도 수강권 이력 팝업에서 계속 관리할 수 있습니다.',
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: const [
                    SizedBox(
                      width: 320,
                      child: _GuideCallout(
                        icon: Icons.payments_rounded,
                        title: '금액 조정',
                        items: [
                          '정가와 다른 금액으로 판매했다면 발급 시 실제 결제 금액을 입력합니다.',
                          '이 기록은 나중에 운영 내역을 확인할 때 기준이 됩니다.',
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: _GuideCallout(
                        icon: Icons.event_repeat_rounded,
                        title: '기간·환불·홀딩 조정',
                        items: [
                          '수강권 이력에서 시작일과 종료일을 수정할 수 있습니다.',
                          '부분 환불, 전액 환불, 홀딩도 같은 팝업에서 처리 가능합니다.',
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _DashboardSectionHeading(
                  icon: Icons.flag_rounded,
                  title: '추천 운영 순서',
                  description: '처음 세팅할 때는 아래 순서대로 진행하면 가장 헷갈리지 않습니다.',
                ),
                SizedBox(height: 12),
                _GuideBulletList(
                  items: [
                    '수업 템플릿 탭에서 반복 수업 규칙을 먼저 만듭니다.',
                    '수강권 상품 탭에서 각 상품이 예약 가능한 수업 템플릿을 연결합니다.',
                    '회원 관리 탭에서 회원에게 수강권을 발급합니다.',
                    '수업 관리 탭에서 실제 회차를 개설하고 필요하면 강사를 배정합니다.',
                    '대기가 생긴 수업은 수업 카드의 대기 버튼에서 순번대로 직접 처리합니다.',
                    '취소 관리 탭에서 취소 마감 시간과 취소 문의 허용 여부를 맞춰 둡니다.',
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _DashboardSectionHeading(
            icon: Icons.tips_and_updates_rounded,
            title: '운영 꿀팁',
            description:
                '자주 놓치기 쉬운 운영 포인트를 미리 챙겨 두면 재등록 관리와 정산, 공지 전달이 훨씬 수월해집니다.',
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: const [
                    SizedBox(
                      width: 320,
                      child: _GuideCallout(
                        icon: Icons.dashboard_customize_rounded,
                        title: '대시보드로 운영 흐름 보기',
                        items: [
                          '대시보드 탭에서 운영 중 발생하는 주요 지표를 빠르게 확인할 수 있습니다.',
                          '매출과 환불은 전월과 비교한 그래프도 볼 수 있어 월별 흐름 파악에 유용합니다.',
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: _GuideCallout(
                        icon: Icons.campaign_rounded,
                        title: '공지·이벤트는 앱 알림으로 연결',
                        items: [
                          '콘텐츠 관리 탭에서 공지사항과 이벤트를 등록하면 사용자 앱 내 인앱 알림으로 전달됩니다.',
                          '중요 공지를 선택하면 푸시 알림으로도 발송되어 앱이 꺼져 있어도 새 공지나 이벤트 등록 사실을 알릴 수 있습니다.',
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: _GuideCallout(
                        icon: Icons.badge_rounded,
                        title: '강사 정산은 강사 배정이 기준',
                        items: [
                          '강사를 등록해 두면 월말에 강사별 진행 수업 수를 기준으로 정산하기 편합니다.',
                          '강사 스케줄이 바뀌면 반드시 수업 관리 달력에서 해당 회차 강사도 함께 변경해야 집계가 정확합니다.',
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: _GuideCallout(
                        icon: Icons.favorite_border_rounded,
                        title: '재등록 대상 회원 먼저 챙기기',
                        items: [
                          '회원 관리의 수강권 있는 회원에서는 만료 14일 이내 회원이 보이므로 미리 재신청을 안내하기 좋습니다.',
                          '수강권 만료 후 1달 이내 회원도 다시 수강을 권유하면 사용자 이탈을 줄이는 데 도움이 됩니다.',
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _GuideBulletList(
                  items: [
                    '월말 정산 전에는 대시보드의 매출·환불 흐름과 강사별 진행 수업 수를 함께 확인하면 운영 판단이 빨라집니다.',
                    '새 공지나 이벤트가 중요한 일정이라면 중요 공지 여부를 확인해 앱 밖에서도 회원이 놓치지 않게 안내하는 것이 좋습니다.',
                    '재등록 가능성이 높은 회원은 만료 직전 14일, 만료 후 1달 이내 구간을 나눠서 관리하면 후속 안내가 수월합니다.',
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

class _GuideFlowStep extends StatelessWidget {
  const _GuideFlowStep({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String step;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.infoBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                step,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.infoForeground,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primaryStrong),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideFlowArrow extends StatelessWidget {
  const _GuideFlowArrow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Icon(Icons.south_rounded, color: AppColors.subtle, size: 22),
    );
  }
}

class _GuideTag extends StatelessWidget {
  const _GuideTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: label,
      backgroundColor: AppColors.surfaceAlt,
      foregroundColor: AppColors.primaryStrong,
    );
  }
}

class _GuideBulletList extends StatelessWidget {
  const _GuideBulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: AppColors.infoBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: AppColors.infoForeground,
                  size: 14,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  items[index],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.body,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
          if (index < items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _GuideCallout extends StatelessWidget {
  const _GuideCallout({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.highlightBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.highlightForeground),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GuideBulletList(items: items),
        ],
      ),
    );
  }
}

class _GuideDecisionCard extends StatelessWidget {
  const _GuideDecisionCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryStrong),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.subtle,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingCancelRequestCard extends StatelessWidget {
  const _PendingCancelRequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final AdminCancelRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.memberName ?? request.memberCode,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.className,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const StatusPill(
                label: '대기중',
                backgroundColor: AppColors.highlightBackground,
                foregroundColor: AppColors.highlightForeground,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CancelDetailRow(label: '회원 ID', value: request.memberCode),
          const SizedBox(height: 8),
          _CancelDetailRow(
            label: '핸드폰 번호',
            value: Formatters.phone(
              request.memberPhone,
              fallback: '등록된 핸드폰 번호 없음',
            ),
          ),
          const SizedBox(height: 8),
          _CancelDetailRow(
            label: '수업 일정',
            value: Formatters.full(request.startAt),
          ),
          const SizedBox(height: 8),
          _CancelDetailRow(
            label: '취소 사유',
            value: request.requestCancelReason ?? '사유 없음',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 132,
                child: FilledButton.tonal(
                  onPressed: onReject,
                  child: const Text('거절'),
                ),
              ),
              SizedBox(
                width: 132,
                child: ElevatedButton(
                  onPressed: onApprove,
                  child: const Text('승인'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancelDetailRow extends StatelessWidget {
  const _CancelDetailRow({required this.label, required this.value});

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
            color: AppColors.subtle,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }
}

class _PeriodFilterChip extends StatelessWidget {
  const _PeriodFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text(label),
    );
  }
}

class _ProcessedCancelHistoryFilterDialog extends StatefulWidget {
  const _ProcessedCancelHistoryFilterDialog({
    required this.memberFilter,
    required this.monthsFilter,
    required this.availableMembers,
  });

  final String? memberFilter;
  final int? monthsFilter;
  final List<String> availableMembers;

  @override
  State<_ProcessedCancelHistoryFilterDialog> createState() =>
      _ProcessedCancelHistoryFilterDialogState();
}

class _ProcessedCancelHistoryFilterDialogState
    extends State<_ProcessedCancelHistoryFilterDialog> {
  late String? _memberFilter;
  late int? _monthsFilter;

  @override
  void initState() {
    super.initState();
    _memberFilter = widget.memberFilter;
    _monthsFilter = widget.monthsFilter;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '처리 완료 이력 필터',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String?>(
              value: _memberFilter,
              decoration: const InputDecoration(labelText: '회원'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('전체 회원'),
                ),
                ...widget.availableMembers.map(
                  (member) => DropdownMenuItem<String?>(
                    value: member,
                    child: Text(member),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _memberFilter = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              '기간',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PeriodFilterChip(
                  label: '전체',
                  selected: _monthsFilter == null,
                  onTap: () {
                    setState(() {
                      _monthsFilter = null;
                    });
                  },
                ),
                for (final months in const [1, 3, 6, 12])
                  _PeriodFilterChip(
                    label: '$months개월',
                    selected: _monthsFilter == months,
                    onTap: () {
                      setState(() {
                        _monthsFilter = months;
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _memberFilter = null;
              _monthsFilter = null;
            });
          },
          child: const Text('초기화'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _ProcessedCancelHistoryFilterFormData(
                memberFilter: _memberFilter,
                monthsFilter: _monthsFilter,
              ),
            );
          },
          child: const Text('적용'),
        ),
      ],
    );
  }
}

class _ProcessedCancelHistoryFilterFormData {
  const _ProcessedCancelHistoryFilterFormData({
    required this.memberFilter,
    required this.monthsFilter,
  });

  final String? memberFilter;
  final int? monthsFilter;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.note,
    this.onTap,
  });

  final String label;
  final String value;
  final String note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = SizedBox(
      width: 210,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.subtle,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              note,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
            ),
            if (onTap != null) ...[
              const SizedBox(height: 10),
              Text(
                '눌러서 보기',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primaryStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) {
      return card;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: card,
    );
  }
}

class _DashboardStatChip extends StatelessWidget {
  const _DashboardStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.subtle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.title,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyReservationOverviewDialog extends StatelessWidget {
  const _MonthlyReservationOverviewDialog({
    required this.summaries,
    required this.totalReservationCount,
  });

  final List<AdminMonthlyReservationSummary> summaries;
  final int totalReservationCount;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('이번달 총 예약 수'),
      content: SizedBox(
        width: 560,
        child: summaries.isEmpty
            ? SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    '이번달 예약 내역이 없습니다.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                  ),
                ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '총 $totalReservationCount건',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.title,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '날짜 순으로 수업별 예약 수를 확인합니다. 완료된 예약도 포함됩니다.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.separated(
                        itemCount: summaries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final summary = summaries[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        summary.className,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${Formatters.date(summary.sessionDate)} ${Formatters.time(summary.startAt)} - ${Formatters.time(summary.endAt)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: AppColors.subtle),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _DashboardStatChip(
                                  label: '예약',
                                  value:
                                      '${summary.reservationCount}/${summary.capacity}',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _FinancialTrendDialog extends StatefulWidget {
  const _FinancialTrendDialog({
    required this.title,
    required this.description,
    required this.metricLabel,
    required this.color,
    required this.future,
    required this.valueSelector,
  });

  final String title;
  final String description;
  final String metricLabel;
  final Color color;
  final Future<List<AdminMonthlyFinancialMetric>> future;
  final double Function(AdminMonthlyFinancialMetric metric) valueSelector;

  @override
  State<_FinancialTrendDialog> createState() => _FinancialTrendDialogState();
}

class _FinancialTrendDialogState extends State<_FinancialTrendDialog> {
  int? _selectedMonths = 3;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 640,
        child: FutureBuilder<List<AdminMonthlyFinancialMetric>>(
          future: widget.future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return SizedBox(
                height: 220,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '추이 데이터를 불러오지 못했습니다.',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                  ],
                ),
              );
            }

            final metrics =
                snapshot.data ?? const <AdminMonthlyFinancialMetric>[];
            final visibleMetrics = _visibleMetrics(metrics);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.subtle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<int?>(
                        value: _selectedMonths,
                        decoration: const InputDecoration(labelText: '기간'),
                        items: const [
                          DropdownMenuItem<int?>(value: 1, child: Text('1개월')),
                          DropdownMenuItem<int?>(value: 3, child: Text('3개월')),
                          DropdownMenuItem<int?>(value: 6, child: Text('6개월')),
                          DropdownMenuItem<int?>(
                            value: 12,
                            child: Text('12개월'),
                          ),
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text('전체'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedMonths = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (visibleMetrics.isEmpty)
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        '표시할 ${widget.metricLabel} 데이터가 없습니다.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.subtle,
                        ),
                      ),
                    ),
                  )
                else
                  _MonthlyTrendChart(
                    metrics: visibleMetrics,
                    metricLabel: widget.metricLabel,
                    color: widget.color,
                    valueSelector: widget.valueSelector,
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  List<AdminMonthlyFinancialMetric> _visibleMetrics(
    List<AdminMonthlyFinancialMetric> metrics,
  ) {
    if (_selectedMonths == null) {
      return metrics;
    }

    final monthCount = _selectedMonths!;
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final metricByMonth = {
      for (final metric in metrics) _monthKey(metric.monthStart): metric,
    };
    final studioId = metrics.isEmpty ? '' : metrics.last.studioId;

    return List<AdminMonthlyFinancialMetric>.generate(monthCount, (index) {
      final offset = monthCount - index - 1;
      final monthStart = DateTime(
        currentMonth.year,
        currentMonth.month - offset,
      );
      return metricByMonth[_monthKey(monthStart)] ??
          AdminMonthlyFinancialMetric(
            studioId: studioId,
            monthStart: monthStart,
            salesAmount: 0,
            refundAmount: 0,
          );
    });
  }

  String _monthKey(DateTime value) => '${value.year}-${value.month}';
}

class _MonthlyTrendChart extends StatelessWidget {
  const _MonthlyTrendChart({
    required this.metrics,
    required this.metricLabel,
    required this.color,
    required this.valueSelector,
  });

  final List<AdminMonthlyFinancialMetric> metrics;
  final String metricLabel;
  final Color color;
  final double Function(AdminMonthlyFinancialMetric metric) valueSelector;

  @override
  Widget build(BuildContext context) {
    final values = metrics.map(valueSelector).toList(growable: false);
    final maxValue = values.fold<double>(0, math.max);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final firstValue = values.first;
    final lastValue = values.last;
    final diff = lastValue - firstValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 230,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: metrics
                  .map(
                    (metric) => Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _MonthlyTrendBar(
                        monthLabel: DateFormat(
                          'yy.MM',
                        ).format(metric.monthStart),
                        valueLabel: _currency(valueSelector(metric)),
                        ratio: valueSelector(metric) / safeMax,
                        color: color,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '$metricLabel 변화 ${_currency(diff.abs())} ${diff >= 0 ? '증가' : '감소'}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
        ),
      ],
    );
  }
}

class _MonthlyTrendBar extends StatelessWidget {
  const _MonthlyTrendBar({
    required this.monthLabel,
    required this.valueLabel,
    required this.ratio,
    required this.color,
  });

  final String monthLabel;
  final String valueLabel;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clampedRatio = ratio.clamp(0.04, 1.0);

    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            valueLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.subtle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: clampedRatio,
                widthFactor: 0.78,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                      bottom: Radius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            monthLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.title,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberPassHistoryDialog extends StatefulWidget {
  const _MemberPassHistoryDialog({
    required this.member,
    required this.historyFuture,
  });

  final AdminMember member;
  final Future<List<AdminMemberPassHistory>> historyFuture;

  @override
  State<_MemberPassHistoryDialog> createState() =>
      _MemberPassHistoryDialogState();
}

class _MemberPassHistoryDialogState extends State<_MemberPassHistoryDialog> {
  late Future<List<AdminMemberPassHistory>> _historyFuture;
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _historyFuture = widget.historyFuture;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.member.name ?? widget.member.memberCode} 님 수강권 이력'),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<List<AdminMemberPassHistory>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return SizedBox(
                height: 220,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '수강권 이력을 불러오지 못했습니다.',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                  ],
                ),
              );
            }

            final histories = snapshot.data ?? const <AdminMemberPassHistory>[];
            if (histories.isEmpty) {
              return SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    '발급된 수강권 이력이 없습니다.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                  ),
                ),
              );
            }

            final activeHistories = histories
                .where(_isActiveHistory)
                .toList(growable: false);
            final expiredHistories = histories
                .where((history) => !_isActiveHistory(history))
                .toList(growable: false);

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHistorySection(
                      context,
                      title: '사용중인 수강권',
                      histories: activeHistories,
                      emptyText: '사용중인 수강권이 없습니다.',
                    ),
                    const SizedBox(height: 20),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 20),
                    _buildHistorySection(
                      context,
                      title: '만료 수강권',
                      histories: expiredHistories,
                      emptyText: '만료 수강권이 없습니다.',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_didChange),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  bool _isActiveHistory(AdminMemberPassHistory history) {
    final today = _normalizedDate(DateTime.now());
    return history.status == 'active' &&
        !history.isRefunded &&
        !history.isExhausted &&
        !_normalizedDate(history.validUntil).isBefore(today);
  }

  Widget _buildHistorySection(
    BuildContext context, {
    required String title,
    required List<AdminMemberPassHistory> histories,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        if (histories.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              emptyText,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
            ),
          )
        else
          Column(
            children: histories
                .map(
                  (history) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildHistoryCard(context, history),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    AdminMemberPassHistory history,
  ) {
    final statusLabel = _memberPassHistoryStatusLabel(history);
    final expiringSoonDays = _memberPassHistoryExpiringSoonDays(history);
    final actionButtons = <Widget>[
      _buildHistoryActionButton(
        context,
        icon: Icons.edit_rounded,
        label: '수정',
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryStrong,
        onPressed: () => _editHistory(history),
      ),
      if (!history.isRefunded)
        _buildHistoryActionButton(
          context,
          icon: Icons.payments_outlined,
          label: '환불처리',
          backgroundColor: AppColors.errorBackground,
          foregroundColor: AppColors.errorForeground,
          onPressed: () => _refundHistory(history),
        ),
      if (!history.isRefunded && history.status == 'active')
        _buildHistoryActionButton(
          context,
          icon: Icons.pause_circle_outline_rounded,
          label: _memberPassHoldButtonLabel(history),
          backgroundColor: AppColors.infoBackground,
          foregroundColor: AppColors.infoForeground,
          onPressed: () => _holdHistory(history),
        ),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
                bottom: Radius.circular(14),
              ),
              onTap: () => _openHistoryReservations(history),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                history.passName,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '발급 ${Formatters.date(history.issuedAt)} · 사용기간 ${Formatters.date(history.validFrom)} - ${Formatters.date(history.validUntil)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.subtle),
                              ),
                            ],
                          ),
                        ),
                        if (expiringSoonDays != null ||
                            statusLabel != null) ...[
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (expiringSoonDays != null)
                                Text(
                                  '만료임박 $expiringSoonDays일',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              if (expiringSoonDays != null &&
                                  statusLabel != null)
                                const SizedBox(height: 6),
                              if (statusLabel != null)
                                StatusPill(
                                  label: statusLabel,
                                  backgroundColor:
                                      _memberPassHistoryStatusBackground(
                                        history,
                                      ),
                                  foregroundColor:
                                      _memberPassHistoryStatusForeground(
                                        history,
                                      ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HistoryMetricChip(
                          label: '총',
                          value: '${history.totalCount}회',
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.title,
                        ),
                        _HistoryMetricChip(
                          label: '잔여',
                          value: '${history.remainingCount}회',
                          backgroundColor: AppColors.infoBackground,
                          foregroundColor: AppColors.infoForeground,
                        ),
                        _HistoryMetricChip(
                          label: '예정',
                          value: '${history.plannedCount}회',
                          backgroundColor: AppColors.waitlistBackground,
                          foregroundColor: AppColors.waitlistForeground,
                        ),
                        _HistoryMetricChip(
                          label: '완료',
                          value: '${history.completedCount}회',
                          backgroundColor: AppColors.successBackground,
                          foregroundColor: AppColors.successForeground,
                        ),
                        _HistoryMetricChip(
                          label: '결제',
                          value: _currency(history.paidAmount),
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.body,
                        ),
                        if (history.refundedAmount > 0)
                          _HistoryMetricChip(
                            label: '환불',
                            value: _currency(history.refundedAmount),
                            backgroundColor: AppColors.errorBackground,
                            foregroundColor: AppColors.errorForeground,
                          ),
                      ],
                    ),
                    if (history.latestRefundedAt != null ||
                        history.latestRefundReason != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        [
                          if (history.latestRefundedAt != null)
                            '최근 환불 ${Formatters.date(history.latestRefundedAt!)}',
                          if ((history.latestRefundReason ?? '')
                              .trim()
                              .isNotEmpty)
                            history.latestRefundReason!.trim(),
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.subtle,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: AppColors.primaryStrong,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '카드를 눌러 이 수강권의 예약 이력을 확인하세요',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.primaryStrong,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                for (var index = 0; index < actionButtons.length; index++) ...[
                  Expanded(child: actionButtons[index]),
                  if (index < actionButtons.length - 1)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback onPressed,
  }) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        textStyle: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }

  Future<void> _editHistory(AdminMemberPassHistory history) async {
    final formData = await showDialog<_EditUserPassFormData>(
      context: context,
      builder: (dialogContext) => _EditUserPassDialog(history: history),
    );

    if (formData == null || !mounted) {
      return;
    }

    final repository = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repository.updateUserPass(
        userPassId: history.id,
        totalCount: formData.totalCount,
        paidAmount: formData.paidAmount,
        validFrom: formData.validFrom,
        validUntil: formData.validUntil,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _didChange = true;
        _historyFuture = repository.fetchMemberPassHistories(
          studioId: widget.member.studioId,
          userId: widget.member.userId,
        );
      });
      showAppSnackBarWithMessenger(messenger, '수강권 정보를 수정했습니다.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, error.toString(), isError: true);
    }
  }

  Future<void> _refundHistory(AdminMemberPassHistory history) async {
    if (history.plannedCount > 0) {
      showAppSnackBar(context, '예정된 예약이 있는 수강권은 환불 처리할 수 없습니다.', isError: true);
      return;
    }

    final formData = await showDialog<_RefundUserPassFormData>(
      context: context,
      builder: (dialogContext) => _RefundUserPassDialog(history: history),
    );

    if (formData == null || !mounted) {
      return;
    }

    final repository = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repository.refundUserPass(
        userPassId: history.id,
        refundAmount: formData.refundAmount,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _didChange = true;
        _historyFuture = repository.fetchMemberPassHistories(
          studioId: widget.member.studioId,
          userId: widget.member.userId,
        );
      });
      showAppSnackBarWithMessenger(messenger, '환불 처리 완료로 변경했습니다.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, error.toString(), isError: true);
    }
  }

  Future<void> _holdHistory(AdminMemberPassHistory history) async {
    final formData = await showDialog<_HoldUserPassFormData>(
      context: context,
      builder: (dialogContext) => _HoldUserPassDialog(history: history),
    );

    if (formData == null || !mounted) {
      return;
    }

    final repository = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (formData.action == _HoldUserPassAction.cancel) {
        await repository.cancelUserPassHold(userPassId: history.id);
      } else {
        await repository.holdUserPass(
          userPassId: history.id,
          holdFrom: formData.holdFrom!,
          holdUntil: formData.holdUntil!,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _didChange = true;
        _historyFuture = repository.fetchMemberPassHistories(
          studioId: widget.member.studioId,
          userId: widget.member.userId,
        );
      });
      showAppSnackBarWithMessenger(
        messenger,
        formData.action == _HoldUserPassAction.cancel
            ? '수강권 홀딩을 취소했습니다.'
            : '수강권 홀딩 정보를 저장했습니다.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(messenger, error.toString(), isError: true);
    }
  }

  Future<void> _openHistoryReservations(AdminMemberPassHistory history) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _MemberPassReservationHistoryDialog(
        member: widget.member,
        history: history,
        reservationsFuture: context
            .read<AdminRepository>()
            .fetchMemberPassReservations(
              studioId: widget.member.studioId,
              userId: widget.member.userId,
              userPassId: history.id,
            ),
      ),
    );
  }
}

enum _MemberPassReservationBucket { upcoming, waitlist, completed, cancelled }

class _MemberPassReservationHistoryDialog extends StatelessWidget {
  const _MemberPassReservationHistoryDialog({
    required this.member,
    required this.history,
    required this.reservationsFuture,
  });

  final AdminMember member;
  final AdminMemberPassHistory history;
  final Future<List<ReservationItem>> reservationsFuture;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '${history.passName} 예약 이력',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 760,
        height: 680,
        child: FutureBuilder<List<ReservationItem>>(
          future: reservationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingSection();
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '수강권 예약 이력을 불러오지 못했습니다.',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ErrorText.format(
                        snapshot.error ?? StateError('알 수 없는 오류'),
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                  ],
                ),
              );
            }

            final reservations = snapshot.data ?? const <ReservationItem>[];
            final upcomingReservations = _memberPassReservationsForBucket(
              reservations,
              _MemberPassReservationBucket.upcoming,
            );
            final waitlistReservations = _memberPassReservationsForBucket(
              reservations,
              _MemberPassReservationBucket.waitlist,
            );
            final completedReservations = _memberPassReservationsForBucket(
              reservations,
              _MemberPassReservationBucket.completed,
            );
            final cancelledReservations = _memberPassReservationsForBucket(
              reservations,
              _MemberPassReservationBucket.cancelled,
            );

            return DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  _MemberPassReservationSummaryCard(
                    member: member,
                    history: history,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TabBar(
                      padding: EdgeInsets.zero,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: AppColors.title,
                      unselectedLabelColor: AppColors.subtle,
                      indicatorColor: AppColors.primaryStrong,
                      dividerColor: Colors.transparent,
                      tabs: [
                        _MemberPassReservationTab(
                          label: '예정',
                          count: upcomingReservations.length,
                        ),
                        _MemberPassReservationTab(
                          label: '대기',
                          count: waitlistReservations.length,
                        ),
                        _MemberPassReservationTab(
                          label: '완료',
                          count: completedReservations.length,
                        ),
                        _MemberPassReservationTab(
                          label: '취소',
                          count: cancelledReservations.length,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _MemberPassReservationBucketView(
                          bucket: _MemberPassReservationBucket.upcoming,
                          items: upcomingReservations,
                        ),
                        _MemberPassReservationBucketView(
                          bucket: _MemberPassReservationBucket.waitlist,
                          items: waitlistReservations,
                        ),
                        _MemberPassReservationBucketView(
                          bucket: _MemberPassReservationBucket.completed,
                          items: completedReservations,
                        ),
                        _MemberPassReservationBucketView(
                          bucket: _MemberPassReservationBucket.cancelled,
                          items: cancelledReservations,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MemberPassReservationSummaryCard extends StatelessWidget {
  const _MemberPassReservationSummaryCard({
    required this.member,
    required this.history,
  });

  final AdminMember member;
  final AdminMemberPassHistory history;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            history.passName,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${member.name ?? member.memberCode} · 회원 ID ${member.memberCode}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
          ),
          const SizedBox(height: 6),
          Text(
            '${Formatters.date(history.validFrom)} ~ ${Formatters.date(history.validUntil)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HistoryMetricChip(
                label: '총',
                value: '${history.totalCount}회',
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.title,
              ),
              _HistoryMetricChip(
                label: '잔여',
                value: '${history.remainingCount}회',
                backgroundColor: AppColors.infoBackground,
                foregroundColor: AppColors.infoForeground,
              ),
              _HistoryMetricChip(
                label: '예정',
                value: '${history.plannedCount}회',
                backgroundColor: AppColors.waitlistBackground,
                foregroundColor: AppColors.waitlistForeground,
              ),
              _HistoryMetricChip(
                label: '완료',
                value: '${history.completedCount}회',
                backgroundColor: AppColors.successBackground,
                foregroundColor: AppColors.successForeground,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberPassReservationTab extends StatelessWidget {
  const _MemberPassReservationTab({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.title,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberPassReservationBucketView extends StatelessWidget {
  const _MemberPassReservationBucketView({
    required this.bucket,
    required this.items,
  });

  final _MemberPassReservationBucket bucket;
  final List<ReservationItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptySection(
        title: _memberPassReservationEmptyTitle(bucket),
        description: _memberPassReservationEmptyDescription(bucket),
        icon: _memberPassReservationEmptyIcon(bucket),
      );
    }

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _MemberPassReservationCard(item: items[index]),
      ),
    );
  }
}

class _MemberPassReservationCard extends StatelessWidget {
  const _MemberPassReservationCard({required this.item});

  final ReservationItem item;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _memberPassReservationStatusStyle(item.status);
    final canShowReason =
        item.status == 'studio_cancelled' ||
        item.status == 'studio_rejected' ||
        item.isApprovedCancel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.className,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.title,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (canShowReason)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      if (item.status == 'studio_rejected') {
                        showStudioRejectReasonDialog(
                          context,
                          reason: item.cancelRequestResponseComment,
                          adminName: item.cancelRequestProcessedAdminName,
                          processedAt: item.cancelRequestProcessedAt,
                        );
                        return;
                      }
                      showStudioCancelReasonDialog(
                        context,
                        reason: item.approvedCancelComment,
                        adminName: item.approvedCancelAdminName,
                        processedAt: item.isApprovedCancel
                            ? item.approvedCancelAt
                            : item.cancelRequestProcessedAt,
                      );
                    },
                    child: StatusPill(
                      label: _memberPassReservationStatusLabel(item),
                      backgroundColor: statusStyle.backgroundColor,
                      foregroundColor: statusStyle.foregroundColor,
                    ),
                  ),
                )
              else
                StatusPill(
                  label: _memberPassReservationStatusLabel(item),
                  backgroundColor: statusStyle.backgroundColor,
                  foregroundColor: statusStyle.foregroundColor,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${Formatters.monthDay(item.startAt)} · ${Formatters.time(item.startAt)}-${Formatters.time(item.endAt)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.body),
              ),
              Text(
                '|',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.body),
              ),
              if ((item.instructorName ?? '').trim().isNotEmpty) ...[
                StudioAvatar(
                  name: item.instructorName!.trim(),
                  imageUrl: item.instructorImageUrl,
                  size: 18,
                  borderRadius: 999,
                ),
                Text(
                  item.instructorName!.trim(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.body),
                ),
              ] else
                Text(
                  '강사 정보 없음',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.body),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _memberPassReservationSummary(item),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.body,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

List<ReservationItem> _memberPassReservationsForBucket(
  List<ReservationItem> reservations,
  _MemberPassReservationBucket bucket,
) {
  final now = DateTime.now();
  final filtered = reservations
      .where((reservation) {
        switch (bucket) {
          case _MemberPassReservationBucket.upcoming:
            return isReservationUpcomingStatus(
              reservation.status,
              reservation.startAt,
              now,
            );
          case _MemberPassReservationBucket.waitlist:
            return isReservationWaitlistedStatus(reservation.status);
          case _MemberPassReservationBucket.completed:
            return isReservationCompletedStatus(
              reservation.status,
              reservation.startAt,
              now,
            );
          case _MemberPassReservationBucket.cancelled:
            return isReservationCancelledStatus(
              reservation.status,
              approvedCancelAt: reservation.approvedCancelAt,
            );
        }
      })
      .toList(growable: false);

  filtered.sort((left, right) {
    if (bucket == _MemberPassReservationBucket.completed ||
        bucket == _MemberPassReservationBucket.cancelled) {
      return right.startAt.compareTo(left.startAt);
    }
    return left.startAt.compareTo(right.startAt);
  });

  return filtered;
}

String _memberPassReservationEmptyTitle(_MemberPassReservationBucket bucket) {
  switch (bucket) {
    case _MemberPassReservationBucket.upcoming:
      return '예정된 수업이 없습니다';
    case _MemberPassReservationBucket.waitlist:
      return '대기 중인 수업이 없습니다';
    case _MemberPassReservationBucket.completed:
      return '완료한 수업이 없습니다';
    case _MemberPassReservationBucket.cancelled:
      return '취소된 수업이 없습니다';
  }
}

String _memberPassReservationEmptyDescription(
  _MemberPassReservationBucket bucket,
) {
  switch (bucket) {
    case _MemberPassReservationBucket.upcoming:
      return '이 수강권으로 예약된 예정 수업이 생기면 여기에 표시됩니다.';
    case _MemberPassReservationBucket.waitlist:
      return '이 수강권으로 대기 신청한 수업이 생기면 여기에 표시됩니다.';
    case _MemberPassReservationBucket.completed:
      return '이 수강권으로 완료한 수업 이력이 쌓이면 여기에 표시됩니다.';
    case _MemberPassReservationBucket.cancelled:
      return '이 수강권으로 취소되거나 스튜디오 처리된 수업이 있으면 여기에 표시됩니다.';
  }
}

IconData _memberPassReservationEmptyIcon(_MemberPassReservationBucket bucket) {
  switch (bucket) {
    case _MemberPassReservationBucket.upcoming:
      return Icons.event_note_outlined;
    case _MemberPassReservationBucket.waitlist:
      return Icons.hourglass_top_rounded;
    case _MemberPassReservationBucket.completed:
      return Icons.check_circle_outline_rounded;
    case _MemberPassReservationBucket.cancelled:
      return Icons.remove_circle_outline_rounded;
  }
}

_MemberPassReservationStatusStyle _memberPassReservationStatusStyle(
  String status,
) {
  switch (status) {
    case 'reserved':
      return const _MemberPassReservationStatusStyle(
        backgroundColor: AppColors.infoBackground,
        foregroundColor: AppColors.infoForeground,
      );
    case 'waitlisted':
      return const _MemberPassReservationStatusStyle(
        backgroundColor: AppColors.waitlistBackground,
        foregroundColor: AppColors.waitlistForeground,
      );
    case 'completed':
      return const _MemberPassReservationStatusStyle(
        backgroundColor: AppColors.successBackground,
        foregroundColor: AppColors.successForeground,
      );
    case 'cancel_requested':
      return const _MemberPassReservationStatusStyle(
        backgroundColor: AppColors.highlightBackground,
        foregroundColor: AppColors.highlightForeground,
      );
    case 'cancelled':
    case 'studio_cancelled':
    case 'studio_rejected':
      return const _MemberPassReservationStatusStyle(
        backgroundColor: AppColors.neutralBackground,
        foregroundColor: AppColors.neutralForeground,
      );
    default:
      return const _MemberPassReservationStatusStyle(
        backgroundColor: AppColors.neutralBackground,
        foregroundColor: AppColors.neutralForeground,
      );
  }
}

String _memberPassReservationStatusLabel(ReservationItem item) {
  if (item.isApprovedCancel) {
    return '취소 요청 승인';
  }
  return Formatters.reservationStatus(item.status);
}

String _memberPassReservationSummary(ReservationItem item) {
  final isLockedReservation =
      item.status == 'reserved' &&
      (item.isCancelLocked ||
          (!item.canRequestCancel && !item.canCancelDirectly));
  if (item.status == 'studio_rejected') {
    return '스튜디오에서 취소 요청을 거절했습니다. 상태 라벨을 눌러 사유를 확인하세요.';
  }
  if (item.isApprovedCancel) {
    return '스튜디오에서 취소 요청을 승인했습니다. 상태 라벨을 눌러 사유를 확인하세요.';
  }
  if (item.status == 'studio_cancelled') {
    return '스튜디오에서 예약을 취소했습니다. 상태 라벨을 눌러 사유를 확인하세요.';
  }
  if (item.status == 'cancel_requested') {
    return '스튜디오에서 취소 요청을 검토 중입니다.';
  }
  if (isLockedReservation) {
    return '취소 정책 내 기간이라 스튜디오에 직접 문의가 필요합니다.';
  }
  if (item.canRequestCancel) {
    return '취소 정책 내 기간이라 앱에서 취소 요청을 보낼 수 있습니다.';
  }
  if (item.canCancelDirectly) {
    return '취소 정책 외 기간이라 앱에서 직접 취소할 수 있습니다.';
  }
  return '상태를 확인하세요.';
}

class _MemberPassReservationStatusStyle {
  const _MemberPassReservationStatusStyle({
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
}

class _MemberConsultNotesDialog extends StatefulWidget {
  const _MemberConsultNotesDialog({
    required this.member,
    required this.notesFuture,
  });

  final AdminMember member;
  final Future<List<AdminMemberConsultNote>> notesFuture;

  @override
  State<_MemberConsultNotesDialog> createState() =>
      _MemberConsultNotesDialogState();
}

class _MemberConsultNotesDialogState extends State<_MemberConsultNotesDialog> {
  late Future<List<AdminMemberConsultNote>> _notesFuture;
  late DateTime _consultedOn;
  late final TextEditingController _consultedOnController;
  late final TextEditingController _noteController;
  bool _submitting = false;
  String? _deletingNoteId;
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _notesFuture = widget.notesFuture;
    _consultedOn = _normalizedDate(DateTime.now());
    _consultedOnController = TextEditingController(
      text: _adminDateInputValue(_consultedOn),
    );
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _consultedOnController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '${widget.member.name ?? widget.member.memberCode} 님 상담 노트',
        onClose: () => Navigator.of(context).pop(_didChange),
      ),
      content: SizedBox(
        width: 620,
        height: 560,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _AdminDateInputField(
                          controller: _consultedOnController,
                          label: '상담 날짜',
                          onTap: _pickConsultedOn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submitNote,
                        icon: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_rounded),
                        label: Text(_submitting ? '등록 중' : '노트 등록'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '상담 내용',
                      hintText: '상담 내용을 간단히 입력하세요.',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<AdminMemberConsultNote>>(
                future: _notesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '상담 노트를 불러오지 못했습니다.',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.subtle),
                          ),
                        ],
                      ),
                    );
                  }

                  final notes =
                      snapshot.data ?? const <AdminMemberConsultNote>[];
                  if (notes.isEmpty) {
                    return Center(
                      child: Text(
                        '등록된 상담 노트가 없습니다.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.subtle,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      final isDeleting = _deletingNoteId == note.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _openConsultNoteDetail(note),
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              StatusPill(
                                                label:
                                                    '상담 ${Formatters.date(note.consultedOn)}',
                                                backgroundColor:
                                                    AppColors.infoBackground,
                                                foregroundColor:
                                                    AppColors.infoForeground,
                                              ),
                                              if ((note.createdByAdminName ??
                                                      '')
                                                  .trim()
                                                  .isNotEmpty)
                                                Text(
                                                  '작성 ${note.createdByAdminName!.trim()}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: AppColors.subtle,
                                                      ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            note.note,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '등록 ${Formatters.date(note.createdAt)}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: AppColors.subtle,
                                                      ),
                                                ),
                                              ),
                                              if (_isConsultNoteExpandable(
                                                note.note,
                                              ))
                                                Text(
                                                  '눌러서 전체 보기',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: AppColors
                                                            .primaryStrong,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: isDeleting
                                    ? null
                                    : () => _deleteNote(note),
                                tooltip: '삭제',
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.surface,
                                  foregroundColor: AppColors.errorForeground,
                                ),
                                icon: isDeleting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickConsultedOn() async {
    final picked = await _pickAdminDate(
      context,
      initialDate: _consultedOn,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _consultedOn = _normalizedDate(picked);
      _consultedOnController.text = _adminDateInputValue(_consultedOn);
    });
  }

  Future<void> _submitNote() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      showAppSnackBar(context, '상담 내용을 입력하세요.', isError: true);
      return;
    }

    final repository = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _submitting = true;
    });

    try {
      await repository.addMemberConsultNote(
        userId: widget.member.userId,
        consultedOn: _consultedOn,
        note: note,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _didChange = true;
        _noteController.clear();
        _notesFuture = repository.fetchMemberConsultNotes(
          studioId: widget.member.studioId,
          userId: widget.member.userId,
        );
      });
      showAppSnackBarWithMessenger(messenger, '상담 노트를 등록했습니다.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(
        messenger,
        ErrorText.format(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  bool _isConsultNoteExpandable(String note) {
    final trimmed = note.trim();
    return trimmed.length > 90 || '\n'.allMatches(trimmed).length >= 2;
  }

  Future<void> _openConsultNoteDetail(AdminMemberConsultNote note) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: _AdminDialogTitle(
          title: '상담 노트 상세',
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(
                      label: '상담 ${Formatters.date(note.consultedOn)}',
                      backgroundColor: AppColors.infoBackground,
                      foregroundColor: AppColors.infoForeground,
                    ),
                    if ((note.createdByAdminName ?? '').trim().isNotEmpty)
                      Text(
                        '작성 ${note.createdByAdminName!.trim()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.subtle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '등록 ${Formatters.date(note.createdAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  note.note,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteNote(AdminMemberConsultNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: _AdminDialogTitle(
          title: '상담 노트 삭제',
          onClose: () => Navigator.of(dialogContext).pop(false),
        ),
        content: Text('${Formatters.date(note.consultedOn)} 상담 노트를 삭제하시겠습니까?'),
        actions: [
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('유지'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorForeground,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final repository = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _deletingNoteId = note.id;
    });

    try {
      await repository.deleteMemberConsultNote(noteId: note.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _didChange = true;
        _notesFuture = repository.fetchMemberConsultNotes(
          studioId: widget.member.studioId,
          userId: widget.member.userId,
        );
      });
      showAppSnackBarWithMessenger(messenger, '상담 노트를 삭제했습니다.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBarWithMessenger(
        messenger,
        ErrorText.format(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingNoteId = null;
        });
      }
    }
  }
}

class _EditUserPassDialog extends StatefulWidget {
  const _EditUserPassDialog({required this.history});

  final AdminMemberPassHistory history;

  @override
  State<_EditUserPassDialog> createState() => _EditUserPassDialogState();
}

class _EditUserPassDialogState extends State<_EditUserPassDialog> {
  late DateTime _validFrom;
  late DateTime _validUntil;
  late final TextEditingController _validFromController;
  late final TextEditingController _validUntilController;
  late final TextEditingController _totalCountController;
  late final TextEditingController _paidAmountController;

  @override
  void initState() {
    super.initState();
    _validFrom = _normalizedDate(widget.history.validFrom);
    _validUntil = _normalizedDate(widget.history.validUntil);
    _validFromController = TextEditingController(
      text: _adminDateInputValue(_validFrom),
    );
    _validUntilController = TextEditingController(
      text: _adminDateInputValue(_validUntil),
    );
    _totalCountController = TextEditingController(
      text: '${widget.history.totalCount}',
    );
    _paidAmountController = TextEditingController(
      text:
          widget.history.paidAmount == widget.history.paidAmount.roundToDouble()
          ? widget.history.paidAmount.toStringAsFixed(0)
          : widget.history.paidAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _validFromController.dispose();
    _validUntilController.dispose();
    _totalCountController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '수강권 수정',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.history.passName,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _totalCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '총 횟수'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _paidAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '결제 금액'),
            ),
            const SizedBox(height: 12),
            _AdminDateInputField(
              controller: _validFromController,
              label: '시작일',
              onTap: _pickValidFrom,
            ),
            const SizedBox(height: 12),
            _AdminDateInputField(
              controller: _validUntilController,
              label: '종료일',
              onTap: _pickValidUntil,
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            final totalCount = int.tryParse(_totalCountController.text.trim());
            final paidAmount = double.tryParse(
              _paidAmountController.text.trim(),
            );
            final reservedOrCompletedCount =
                widget.history.plannedCount + widget.history.completedCount;

            if (totalCount == null || totalCount <= 0) {
              showAppSnackBar(context, '총 횟수는 1회 이상이어야 합니다.', isError: true);
              return;
            }
            if (totalCount < reservedOrCompletedCount) {
              showAppSnackBar(
                context,
                '총 횟수는 예정/완료된 수업 수보다 작을 수 없습니다.',
                isError: true,
              );
              return;
            }
            if (paidAmount == null || paidAmount < 0) {
              showAppSnackBar(context, '결제 금액은 0 이상이어야 합니다.', isError: true);
              return;
            }
            if (_validUntil.isBefore(_validFrom)) {
              showAppSnackBar(context, '종료일은 시작일보다 빠를 수 없습니다.', isError: true);
              return;
            }

            Navigator.of(context).pop(
              _EditUserPassFormData(
                totalCount: totalCount,
                paidAmount: paidAmount,
                validFrom: _validFrom,
                validUntil: _validUntil,
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _pickValidFrom() async {
    final picked = await _pickAdminDate(context, initialDate: _validFrom);
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _validFrom = picked;
      if (_validUntil.isBefore(picked)) {
        _validUntil = picked;
        _validUntilController.text = _adminDateInputValue(picked);
      }
      _validFromController.text = _adminDateInputValue(picked);
    });
  }

  Future<void> _pickValidUntil() async {
    final picked = await _pickAdminDate(
      context,
      initialDate: _validUntil,
      firstDate: _validFrom,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _validUntil = picked;
      _validUntilController.text = _adminDateInputValue(picked);
    });
  }
}

class _RefundUserPassDialog extends StatefulWidget {
  const _RefundUserPassDialog({required this.history});

  final AdminMemberPassHistory history;

  @override
  State<_RefundUserPassDialog> createState() => _RefundUserPassDialogState();
}

class _RefundUserPassDialogState extends State<_RefundUserPassDialog> {
  late final TextEditingController _refundAmountController;

  @override
  void initState() {
    super.initState();
    final defaultAmount = widget.history.paidAmount;
    _refundAmountController = TextEditingController(
      text: defaultAmount == defaultAmount.roundToDouble()
          ? defaultAmount.toStringAsFixed(0)
          : defaultAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _refundAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '환불 처리',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.history.passName,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '환불 처리 시 상태가 환불 처리 완료로 바뀌고 종료일은 오늘로 변경됩니다.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _refundAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: '환불 금액',
                helperText: '결제 금액 ${_currency(widget.history.paidAmount)} 이하',
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            final refundAmount = double.tryParse(
              _refundAmountController.text.trim(),
            );
            if (refundAmount == null || refundAmount <= 0) {
              showAppSnackBar(context, '환불 금액은 0보다 커야 합니다.', isError: true);
              return;
            }
            if (refundAmount > widget.history.paidAmount) {
              showAppSnackBar(
                context,
                '환불 금액은 결제 금액을 초과할 수 없습니다.',
                isError: true,
              );
              return;
            }

            Navigator.of(
              context,
            ).pop(_RefundUserPassFormData(refundAmount: refundAmount));
          },
          child: const Text('환불 처리'),
        ),
      ],
    );
  }
}

class _HoldUserPassDialog extends StatefulWidget {
  const _HoldUserPassDialog({required this.history});

  final AdminMemberPassHistory history;

  @override
  State<_HoldUserPassDialog> createState() => _HoldUserPassDialogState();
}

class _HoldUserPassDialogState extends State<_HoldUserPassDialog> {
  late DateTime _holdFrom;
  late DateTime _holdUntil;
  late final TextEditingController _holdFromController;
  late final TextEditingController _holdUntilController;

  DateTime? get _existingHoldFrom =>
      widget.history.activeHoldFrom ?? widget.history.latestHoldFrom;

  DateTime? get _existingHoldUntil =>
      widget.history.activeHoldUntil ?? widget.history.latestHoldUntil;

  bool get _hasExistingHold =>
      _existingHoldFrom != null && _existingHoldUntil != null;

  bool get _canCancelExistingHold {
    if (!_hasExistingHold) {
      return false;
    }
    final today = _normalizedDate(DateTime.now());
    return !_normalizedDate(_existingHoldUntil!).isBefore(today);
  }

  int get _cancelAdvanceDays {
    if (!_canCancelExistingHold) {
      return 0;
    }
    final today = _normalizedDate(DateTime.now());
    final effectiveFrom = _normalizedDate(
      _existingHoldFrom!.isAfter(today) ? _existingHoldFrom! : today,
    );
    return _normalizedDate(
          _existingHoldUntil!,
        ).difference(effectiveFrom).inDays +
        1;
  }

  DateTime get _baseValidUntil {
    final normalizedValidUntil = _normalizedDate(widget.history.validUntil);
    if (widget.history.totalHoldDays <= 0) {
      return normalizedValidUntil;
    }
    final baseValidUntil = normalizedValidUntil.subtract(
      Duration(days: widget.history.totalHoldDays),
    );
    final normalizedValidFrom = _normalizedDate(widget.history.validFrom);
    return baseValidUntil.isBefore(normalizedValidFrom)
        ? normalizedValidFrom
        : baseValidUntil;
  }

  @override
  void initState() {
    super.initState();
    final normalizedToday = _normalizedDate(DateTime.now());
    final normalizedValidFrom = _normalizedDate(widget.history.validFrom);
    final firstSelectableDate = _hasExistingHold
        ? normalizedValidFrom
        : (normalizedValidFrom.isAfter(normalizedToday)
              ? normalizedValidFrom
              : normalizedToday);
    final initialFrom = _existingHoldFrom != null
        ? _normalizedDate(_existingHoldFrom!)
        : firstSelectableDate;
    final initialUntil = _existingHoldUntil != null
        ? _normalizedDate(_existingHoldUntil!)
        : initialFrom;
    _holdFrom = initialFrom.isBefore(firstSelectableDate)
        ? firstSelectableDate
        : initialFrom;
    if (_holdFrom.isAfter(_baseValidUntil)) {
      _holdFrom = _baseValidUntil;
    }
    _holdUntil = initialUntil.isBefore(_holdFrom) ? _holdFrom : initialUntil;
    if (_holdUntil.isAfter(_baseValidUntil)) {
      _holdUntil = _baseValidUntil;
    }
    _holdFromController = TextEditingController(
      text: _adminDateInputValue(_holdFrom),
    );
    _holdUntilController = TextEditingController(
      text: _adminDateInputValue(_holdUntil),
    );
  }

  @override
  void dispose() {
    _holdFromController.dispose();
    _holdUntilController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '수강권 홀딩',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.history.passName,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '홀딩 기간만큼 종료일이 뒤로 연장되고, 홀딩 기간에는 앱에서 해당 날짜 수업이 보이지 않습니다.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _AdminDateInputField(
                    controller: _holdFromController,
                    label: '홀딩 시작일',
                    onTap: _pickHoldRange,
                    showCalendarIcon: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AdminDateInputField(
                    controller: _holdUntilController,
                    label: '홀딩 종료일',
                    onTap: _pickHoldRange,
                    showCalendarIcon: false,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: _pickHoldRange,
                  icon: const Icon(Icons.date_range_rounded),
                  label: const Text('기간 선택'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (_canCancelExistingHold)
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorBackground,
              foregroundColor: AppColors.errorForeground,
            ),
            onPressed: _confirmCancelHold,
            child: const Text('홀딩 취소'),
          ),
        FilledButton(
          onPressed: () {
            if (_holdUntil.isBefore(_holdFrom)) {
              showAppSnackBar(
                context,
                '홀딩 종료일은 시작일보다 빠를 수 없습니다.',
                isError: true,
              );
              return;
            }
            Navigator.of(context).pop(
              _HoldUserPassFormData(holdFrom: _holdFrom, holdUntil: _holdUntil),
            );
          },
          child: const Text('홀딩 적용'),
        ),
      ],
    );
  }

  Future<void> _pickHoldRange() async {
    final normalizedToday = _normalizedDate(DateTime.now());
    final normalizedValidFrom = _normalizedDate(widget.history.validFrom);
    final firstSelectableDate = _hasExistingHold
        ? normalizedValidFrom
        : (normalizedValidFrom.isAfter(normalizedToday)
              ? normalizedValidFrom
              : normalizedToday);
    final lastSelectableDate = _baseValidUntil.isBefore(firstSelectableDate)
        ? firstSelectableDate
        : _baseValidUntil;
    final picked = await _pickAdminDateRange(
      context,
      initialStartDate: _holdFrom,
      initialEndDate: _holdUntil,
      firstDate: firstSelectableDate,
      lastDate: lastSelectableDate,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _holdFrom = picked.start;
      _holdUntil = picked.end;
      _holdFromController.text = _adminDateInputValue(_holdFrom);
      _holdUntilController.text = _adminDateInputValue(_holdUntil);
    });
  }

  Future<void> _confirmCancelHold() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: _AdminDialogTitle(
          title: '홀딩 취소',
          onClose: () => Navigator.of(dialogContext).pop(false),
        ),
        content: SizedBox(
          width: 420,
          child: Text(
            '홀딩 중간 취소 시에는 수강권 종료일은 홀딩 종료일 - 오늘 날짜(혹은 홀딩 시작일) 로 계산되어 총 $_cancelAdvanceDays일 당겨집니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        actions: [
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('유지'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorForeground,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('홀딩 취소'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    Navigator.of(context).pop(
      const _HoldUserPassFormData(
        action: _HoldUserPassAction.cancel,
        holdFrom: null,
        holdUntil: null,
      ),
    );
  }
}

class _DashboardPassesDialog extends StatelessWidget {
  const _DashboardPassesDialog({
    required this.title,
    required this.emptyMessage,
    required this.errorMessage,
    required this.passesFuture,
    required this.detailBuilder,
    this.statusLabelBuilder,
  });

  final String title;
  final String emptyMessage;
  final String errorMessage;
  final Future<List<AdminDashboardPass>> passesFuture;
  final String Function(AdminDashboardPass pass) detailBuilder;
  final String? Function(AdminDashboardPass pass)? statusLabelBuilder;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: FutureBuilder<List<AdminDashboardPass>>(
          future: passesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return SizedBox(
                height: 220,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      errorMessage,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                  ],
                ),
              );
            }

            final passes = snapshot.data ?? const <AdminDashboardPass>[];
            if (passes.isEmpty) {
              return SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    emptyMessage,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                  ),
                ),
              );
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 460),
              child: SingleChildScrollView(
                child: Column(
                  children: passes
                      .map(
                        (pass) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.highlightBackground,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.event_busy_rounded,
                                    color: AppColors.highlightForeground,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pass.passName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${pass.memberName ?? pass.memberCode} · ${Formatters.phone(pass.memberPhone, fallback: '연락처 없음')}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '회원 ID ${pass.memberCode}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.subtle,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        detailBuilder(pass),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: AppColors.subtle),
                                      ),
                                    ],
                                  ),
                                ),
                                if (statusLabelBuilder != null) ...[
                                  const SizedBox(width: 12),
                                  StatusPill(
                                    label: statusLabelBuilder!(pass) ?? '',
                                    backgroundColor: AppColors.infoBackground,
                                    foregroundColor: AppColors.infoForeground,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _MonthlyTemplateOverviewDialog extends StatelessWidget {
  const _MonthlyTemplateOverviewDialog({required this.metrics});

  final List<AdminMonthlyClassMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final appliedMetrics = metrics
        .where((metric) => metric.openedSessionCount > 0)
        .toList(growable: false);

    return AlertDialog(
      title: const Text('이번 달 적용 템플릿'),
      content: SizedBox(
        width: 520,
        child: appliedMetrics.isEmpty
            ? SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    '이번 달 개설된 템플릿이 없습니다.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                  ),
                ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 460),
                child: SingleChildScrollView(
                  child: Column(
                    children: appliedMetrics
                        .map(
                          (metric) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          metric.className,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _DashboardStatChip(
                                    label: '개설',
                                    value: '${metric.openedSessionCount}개',
                                  ),
                                  const SizedBox(width: 8),
                                  _DashboardStatChip(
                                    label: '정원',
                                    value: '${metric.capacity}명',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _HistoryMetricChip extends StatelessWidget {
  const _HistoryMetricChip({
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
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminContentSection extends StatelessWidget {
  const _AdminContentSection({
    required this.title,
    required this.subtitle,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.children,
  });

  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptyDescription;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
        ),
        const SizedBox(height: 14),
        SurfaceCard(
          child: children.isEmpty
              ? EmptySection(title: emptyTitle, description: emptyDescription)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
        ),
      ],
    );
  }
}

class _AdminStatusBucketSection extends StatelessWidget {
  const _AdminStatusBucketSection({
    required this.title,
    required this.subtitle,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.children,
    this.isCollapsed = false,
    this.onToggleCollapsed,
  });

  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptyDescription;
  final List<Widget> children;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final canToggle = onToggleCollapsed != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (canToggle)
              TextButton.icon(
                onPressed: onToggleCollapsed,
                icon: Icon(
                  isCollapsed
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                ),
                label: Text(isCollapsed ? '열기' : '접기'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
        ),
        if (isCollapsed) ...[
          const SizedBox(height: 6),
          Text(
            children.isEmpty ? '보관된 항목이 없습니다.' : '${children.length}개 항목이 숨겨져 있습니다.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
          ),
        ] else ...[
          const SizedBox(height: 14),
          SurfaceCard(
            child: children.isEmpty
                ? EmptySection(title: emptyTitle, description: emptyDescription)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
          ),
        ],
      ],
    );
  }
}

class _AdminDialogTitle extends StatelessWidget {
  const _AdminDialogTitle({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          onPressed: onClose,
          tooltip: '닫기',
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _AdminContentTile extends StatelessWidget {
  const _AdminContentTile({
    required this.title,
    required this.body,
    required this.meta,
    required this.badges,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String body;
  final String meta;
  final List<Widget> badges;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meta,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: badges),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(onPressed: onEdit, child: const Text('수정')),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.errorBackground,
                    foregroundColor: AppColors.errorForeground,
                  ),
                  onPressed: onDelete,
                  child: const Text('삭제'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentBadge extends StatelessWidget {
  const _ContentBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: label,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );
  }
}

class _StudioCancelPolicyDialog extends StatefulWidget {
  const _StudioCancelPolicyDialog({required this.initialStudio});

  final AdminStudioSummary initialStudio;

  @override
  State<_StudioCancelPolicyDialog> createState() =>
      _StudioCancelPolicyDialogState();
}

class _StudioCancelPolicyDialogState extends State<_StudioCancelPolicyDialog> {
  late String _mode;
  late final TextEditingController _hoursController;
  late final TextEditingController _daysController;
  late final TextEditingController _timeController;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialStudio.cancelPolicyMode;
    _hoursController = TextEditingController(
      text: '${widget.initialStudio.cancelPolicyHoursBefore}',
    );
    _daysController = TextEditingController(
      text: '${widget.initialStudio.cancelPolicyDaysBefore}',
    );
    _timeController = TextEditingController(
      text: widget.initialStudio.cancelPolicyCutoffTime,
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _daysController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '스튜디오 취소 정책',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'hours_before',
                    label: Text('x시간 전'),
                    icon: Icon(Icons.schedule_rounded),
                  ),
                  ButtonSegment<String>(
                    value: 'days_before_time',
                    label: Text('x일 전 특정시간'),
                    icon: Icon(Icons.event_available_rounded),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (value) {
                  setState(() {
                    _mode = value.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                _mode == 'hours_before'
                    ? '수업 시작 x시간 전까지는 학생이 직접 취소할 수 있습니다.'
                    : '수업 x일 전 특정 시각까지는 학생이 직접 취소할 수 있습니다.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.body),
              ),
              const SizedBox(height: 16),
              if (_mode == 'hours_before')
                TextField(
                  controller: _hoursController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '직접 취소 가능 시간',
                    suffixText: '시간 전',
                  ),
                )
              else ...[
                TextField(
                  controller: _daysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '직접 취소 가능 일수',
                    suffixText: '일 전',
                  ),
                ),
                const SizedBox(height: 12),
                _AdminTimeInputField(
                  controller: _timeController,
                  label: '마감 시각',
                  onTap: _pickCutoffTime,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            final hours = int.tryParse(_hoursController.text.trim()) ?? 24;
            final days = int.tryParse(_daysController.text.trim()) ?? 1;
            final time = _timeController.text.trim().isEmpty
                ? '18:00'
                : _timeController.text.trim();
            if (_mode == 'hours_before' && hours < 0) {
              return;
            }
            if (_mode == 'days_before_time' &&
                (days < 0 || !_isSimpleTimeFormat(time))) {
              return;
            }
            Navigator.of(context).pop(
              _StudioCancelPolicyFormData(
                cancelPolicyMode: _mode,
                cancelPolicyHoursBefore: hours,
                cancelPolicyDaysBefore: days,
                cancelPolicyCutoffTime: time,
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _pickCutoffTime() async {
    final initialTime =
        _parseAdminTimeOfDay(_timeController.text) ??
        const TimeOfDay(hour: 18, minute: 0);
    final picked = await _pickAdminTime(context, initialTime: initialTime);
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _timeController.text = _adminTimeInputValue(picked);
    });
  }
}

class _StudioSettingsDialog extends StatefulWidget {
  const _StudioSettingsDialog({required this.profile});

  final AdminProfile profile;

  @override
  State<_StudioSettingsDialog> createState() => _StudioSettingsDialogState();
}

class _StudioSettingsDialogState extends State<_StudioSettingsDialog> {
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  PickedImageFile? _selectedImageFile;
  bool _removeImage = false;

  bool get _isUpdatingPassword =>
      _passwordController.text.trim().isNotEmpty ||
      _confirmPasswordController.text.trim().isNotEmpty;

  bool get _passwordsMatch =>
      _passwordController.text == _confirmPasswordController.text;

  bool get _isPhoneValid => Formatters.isMobilePhone(_phoneController.text);

  bool get _canSave {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    if (!_isPhoneValid) {
      return false;
    }
    if (password.isEmpty && confirmPassword.isEmpty) {
      return true;
    }
    if (password.length < 6) {
      return false;
    }
    return password == confirmPassword;
  }

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: Formatters.editablePhone(widget.profile.studio.contactPhone),
    );
    _addressController = TextEditingController(
      text: widget.profile.studio.address ?? '',
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '스튜디오 정보 수정',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.profile.studio.name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
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
                controller: _addressController,
                decoration: const InputDecoration(labelText: '주소'),
              ),
              const SizedBox(height: 12),
              ImageUploadField(
                name: widget.profile.studio.name,
                label: '대표 이미지',
                currentImageUrl: _removeImage
                    ? null
                    : widget.profile.studio.imageUrl,
                selectedImageBytes: _selectedImageFile?.bytes,
                helperText: _removeImage ? '저장 시 기존 이미지가 삭제됩니다.' : null,
                onPick: _pickStudioImage,
                showPickButton: false,
                onClear:
                    _selectedImageFile != null ||
                        _removeImage ||
                        (!_removeImage &&
                            (widget.profile.studio.imageUrl?.isNotEmpty ??
                                false))
                    ? _clearStudioImageSelection
                    : null,
                clearLabel: _selectedImageFile != null
                    ? '선택 취소'
                    : (_removeImage ? '삭제 취소' : '이미지 제거'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: '새 비밀번호',
                  hintText: '변경하지 않으면 비워두세요',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '새 비밀번호 확인',
                  errorText: _isUpdatingPassword && !_passwordsMatch
                      ? '비밀번호가 일치하지 않습니다.'
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _canSave
              ? () {
                  final password = _passwordController.text.trim();
                  if (password.isNotEmpty && password.length < 6) {
                    showAppSnackBar(
                      context,
                      '비밀번호는 6자 이상이어야 합니다.',
                      isError: true,
                    );
                    return;
                  }
                  if (_isUpdatingPassword && !_passwordsMatch) {
                    showAppSnackBar(context, '비밀번호가 일치하지 않습니다.', isError: true);
                    return;
                  }
                  Navigator.of(context).pop(
                    _StudioSettingsFormData(
                      contactPhone: Formatters.storagePhone(
                        _phoneController.text,
                      ),
                      address: _addressController.text,
                      imageFile: _selectedImageFile,
                      removeImage: _removeImage,
                      password: password,
                    ),
                  );
                }
              : null,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _pickStudioImage() async {
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
      showAppSnackBar(context, ErrorText.format(error), isError: true);
    }
  }

  void _clearStudioImageSelection() {
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

class _NoticeDialog extends StatefulWidget {
  const _NoticeDialog({this.initialValue});

  final AdminNotice? initialValue;

  @override
  State<_NoticeDialog> createState() => _NoticeDialogState();
}

class _NoticeDialogState extends State<_NoticeDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _visibleFromController;
  late DateTime? _visibleFrom;
  late bool _isImportant;
  late bool _isPublished;
  late String _status;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _bodyController = TextEditingController(text: initial?.body ?? '');
    _visibleFrom = initial?.visibleFrom == null
        ? null
        : _normalizedDate(initial!.visibleFrom!);
    _visibleFromController = TextEditingController(
      text: _visibleFrom == null ? '' : _adminDateInputValue(_visibleFrom!),
    );
    _isImportant = initial?.isImportant ?? false;
    _isPublished = initial?.isPublished ?? false;
    _status = 'active';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _visibleFromController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: widget.initialValue == null ? '새 공지' : '공지 수정',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '제목'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                maxLines: 6,
                decoration: const InputDecoration(labelText: '내용'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AdminDateInputField(
                      controller: _visibleFromController,
                      label: '노출 시작',
                      onTap: _pickVisibleFrom,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _visibleFrom == null
                        ? null
                        : () {
                            setState(() {
                              _visibleFrom = null;
                              _visibleFromController.clear();
                            });
                          },
                    icon: const Icon(Icons.clear_rounded),
                    tooltip: '노출 시작 지우기',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                value: _isPublished,
                contentPadding: EdgeInsets.zero,
                title: const Text('사용자 앱에 공개'),
                onChanged: (value) {
                  setState(() {
                    _isPublished = value;
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Text(
                  '사용자 앱에 공개 전 충분히 확인하시고 공개해주세요.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                ),
              ),
              SwitchListTile.adaptive(
                value: _isImportant,
                contentPadding: EdgeInsets.zero,
                title: const Text('중요 공지'),
                onChanged: (value) {
                  setState(() {
                    _isImportant = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            final body = _bodyController.text.trim();
            if (title.isEmpty || body.isEmpty) {
              showAppSnackBar(context, '제목과 내용을 입력하세요.', isError: true);
              return;
            }
            Navigator.of(context).pop(
              _NoticeFormData(
                title: title,
                body: body,
                isImportant: _isImportant,
                isPublished: _isPublished,
                status: _status,
                visibleFrom: _visibleFrom == null
                    ? null
                    : _startOfAdminDay(_visibleFrom!),
                visibleUntil: null,
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _pickVisibleFrom() async {
    final picked = await _pickAdminDate(
      context,
      initialDate: _visibleFrom ?? DateTime.now(),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _visibleFrom = picked;
      _visibleFromController.text = _adminDateInputValue(picked);
    });
  }
}

class _EventDialog extends StatefulWidget {
  const _EventDialog({this.initialValue});

  final AdminEvent? initialValue;

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _visibleFromController;
  DateTime? _visibleFrom;
  late bool _isImportant;
  late bool _isPublished;
  late String _status;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    final initialVisibleFrom = initial?.visibleFrom;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _bodyController = TextEditingController(text: initial?.body ?? '');
    _visibleFrom = initialVisibleFrom == null
        ? null
        : DateTime(
            initialVisibleFrom.year,
            initialVisibleFrom.month,
            initialVisibleFrom.day,
          );
    _visibleFromController = TextEditingController(
      text: _visibleFrom == null ? '' : _adminDateInputValue(_visibleFrom!),
    );
    _isImportant = initial?.isImportant ?? false;
    _isPublished = initial?.isPublished ?? true;
    _status = 'active';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _visibleFromController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: widget.initialValue == null ? '새 이벤트' : '이벤트 수정',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '제목'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                maxLines: 6,
                decoration: const InputDecoration(labelText: '내용'),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _pickVisibleFrom,
                child: AbsorbPointer(
                  child: TextField(
                    controller: _visibleFromController,
                    decoration: InputDecoration(
                      labelText: '노출 시작',
                      hintText: '날짜를 선택하세요',
                      suffixIcon: IconButton(
                        onPressed: _pickVisibleFrom,
                        icon: const Icon(Icons.calendar_today_rounded),
                        tooltip: '노출 시작일 선택',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                value: _isPublished,
                contentPadding: EdgeInsets.zero,
                title: const Text('사용자 앱에 공개'),
                onChanged: (value) {
                  setState(() {
                    _isPublished = value;
                  });
                },
              ),
              SwitchListTile.adaptive(
                value: _isImportant,
                contentPadding: EdgeInsets.zero,
                title: const Text('중요 이벤트'),
                onChanged: (value) {
                  setState(() {
                    _isImportant = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            final body = _bodyController.text.trim();
            if (title.isEmpty || body.isEmpty) {
              showAppSnackBar(context, '제목과 내용을 입력하세요.', isError: true);
              return;
            }
            Navigator.of(context).pop(
              _EventFormData(
                title: title,
                body: body,
                isImportant: _isImportant,
                isPublished: _isPublished,
                status: _status,
                visibleFrom: _visibleFrom == null
                    ? null
                    : _startOfAdminDay(_visibleFrom!),
                visibleUntil: null,
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _pickVisibleFrom() async {
    final picked = await _pickAdminDate(
      context,
      initialDate: _visibleFrom ?? DateTime.now(),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _visibleFrom = picked;
      _visibleFromController.text = _adminDateInputValue(picked);
    });
  }
}

class _TemplateDialog extends StatefulWidget {
  const _TemplateDialog({required this.instructors, this.initialValue});

  final AdminClassTemplate? initialValue;
  final List<AdminInstructor> instructors;

  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late final TextEditingController _capacityController;
  late List<String> _selectedDays;
  late String? _selectedInstructorId;
  late String _status;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _startTimeController = TextEditingController(
      text: initial?.startTime ?? '19:00',
    );
    _endTimeController = TextEditingController(
      text: initial?.endTime ?? '20:20',
    );
    _capacityController = TextEditingController(
      text: '${initial?.capacity ?? 10}',
    );
    _selectedDays = List<String>.from(initial?.dayOfWeekMask ?? const ['tue']);
    _selectedInstructorId = initial?.defaultInstructorId;
    _status = initial?.status ?? 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: widget.initialValue == null ? '새 수업 템플릿' : '수업 템플릿 수정',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '수업명'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '설명'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value:
                    widget.instructors.any(
                      (instructor) => instructor.id == _selectedInstructorId,
                    )
                    ? _selectedInstructorId
                    : null,
                decoration: const InputDecoration(labelText: '기본 강사 (선택)'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('기본 강사 미지정'),
                  ),
                  ...widget.instructors.map(
                    (instructor) => DropdownMenuItem<String?>(
                      value: instructor.id,
                      child: Text(instructor.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedInstructorId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AdminTimeInputField(
                      controller: _startTimeController,
                      label: '시작 시간',
                      onTap: _pickStartTime,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AdminTimeInputField(
                      controller: _endTimeController,
                      label: '종료 시간',
                      onTap: _pickEndTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '정원'),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '요일 선택',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _dayOptions.entries
                    .map(
                      (entry) => FilterChip(
                        selected: _selectedDays.contains(entry.key),
                        label: Text(entry.value),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedDays = [..._selectedDays, entry.key];
                            } else {
                              _selectedDays = _selectedDays
                                  .where((day) => day != entry.key)
                                  .toList(growable: false);
                            }
                          });
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: '상태'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('활성')),
                  DropdownMenuItem(value: 'inactive', child: Text('비활성')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _status = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final capacity = int.tryParse(_capacityController.text.trim());
            final parsedStartTime = _parseAdminTimeInput(
              _startTimeController.text,
            );
            final parsedEndTime = _parseAdminTimeInput(_endTimeController.text);
            if (name.isEmpty) {
              showAppSnackBar(context, '수업명을 입력하세요.', isError: true);
              return;
            }
            if (capacity == null || capacity <= 0) {
              showAppSnackBar(context, '정원은 1명 이상이어야 합니다.', isError: true);
              return;
            }
            if (_selectedDays.isEmpty) {
              showAppSnackBar(context, '적용 요일을 한 개 이상 선택하세요.', isError: true);
              return;
            }
            if (parsedStartTime == null || parsedEndTime == null) {
              showAppSnackBar(context, '시간을 시계에서 선택하세요.', isError: true);
              return;
            }
            if (_compareAdminTime(parsedStartTime, parsedEndTime) >= 0) {
              showAppSnackBar(
                context,
                '종료 시간은 시작 시간보다 늦어야 합니다.',
                isError: true,
              );
              return;
            }
            Navigator.of(context).pop(
              _TemplateFormData(
                name: name,
                description: _descriptionController.text.trim(),
                dayOfWeekMask: _selectedDays,
                startTime: _startTimeController.text.trim(),
                endTime: _endTimeController.text.trim(),
                defaultInstructorId: _selectedInstructorId,
                capacity: capacity,
                status: _status,
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _pickStartTime() async {
    final currentStart =
        _parseAdminTimeOfDay(_startTimeController.text) ??
        const TimeOfDay(hour: 19, minute: 0);
    final pickedStart = await _pickAdminTime(
      context,
      initialTime: currentStart,
    );
    if (pickedStart == null || !mounted) {
      return;
    }

    setState(() {
      _startTimeController.text = _adminTimeInputValue(pickedStart);
    });

    final currentEnd = _parseAdminTimeOfDay(_endTimeController.text);
    final initialEnd =
        currentEnd != null &&
            _compareAdminTimeOfDay(currentEnd, pickedStart) > 0
        ? currentEnd
        : _addMinutesToTimeOfDay(pickedStart, 80);
    final pickedEnd = await _pickAdminTime(context, initialTime: initialEnd);
    if (pickedEnd == null || !mounted) {
      return;
    }

    setState(() {
      _endTimeController.text = _adminTimeInputValue(pickedEnd);
    });
  }

  Future<void> _pickEndTime() async {
    final currentEnd =
        _parseAdminTimeOfDay(_endTimeController.text) ??
        const TimeOfDay(hour: 20, minute: 20);
    final pickedEnd = await _pickAdminTime(context, initialTime: currentEnd);
    if (pickedEnd == null || !mounted) {
      return;
    }
    setState(() {
      _endTimeController.text = _adminTimeInputValue(pickedEnd);
    });
  }
}

class _PassProductDialog extends StatefulWidget {
  const _PassProductDialog({required this.templates, this.initialValue});

  final List<AdminClassTemplate> templates;
  final AdminPassProduct? initialValue;

  @override
  State<_PassProductDialog> createState() => _PassProductDialogState();
}

class _PassProductDialogState extends State<_PassProductDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _countController;
  late final TextEditingController _validDaysController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late List<String> _templateIds;
  late String _status;

  List<AdminClassTemplate> get _selectableTemplates => widget.templates
      .where((template) => template.category != '일회성')
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _countController = TextEditingController(
      text: '${initial?.totalCount ?? 10}',
    );
    _validDaysController = TextEditingController(
      text: '${initial?.validDays ?? 90}',
    );
    _priceController = TextEditingController(
      text: '${initial?.priceAmount ?? 220000}',
    );
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    final selectableTemplateIds = _selectableTemplates
        .map((template) => template.id)
        .toSet();
    _templateIds = List<String>.from(
      initial?.allowedTemplateIds ?? const [],
    ).where(selectableTemplateIds.contains).toList(growable: false);
    _status = initial?.status ?? 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countController.dispose();
    _validDaysController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final totalCount = int.tryParse(_countController.text.trim());
    final validDays = int.tryParse(_validDaysController.text.trim());
    final priceAmount = double.tryParse(_priceController.text.trim());
    return _nameController.text.trim().isNotEmpty &&
        totalCount != null &&
        validDays != null &&
        priceAmount != null &&
        _templateIds.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: widget.initialValue == null ? '새 수강권 상품' : '수강권 상품 수정',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: '상품명'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _countController,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '횟수'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _validDaysController,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '유효일수'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '판매 금액'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '설명'),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '예약 가능한 수업',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 10),
              if (_selectableTemplates.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    "예약 가능한 수업이 개설되지 않았습니다. '수업 템플릿'을 먼저 생성하세요",
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                  ),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectableTemplates
                      .map(
                        (template) => FilterChip(
                          selected: _templateIds.contains(template.id),
                          label: Text(template.name),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _templateIds = [..._templateIds, template.id];
                              } else {
                                _templateIds = _templateIds
                                    .where((id) => id != template.id)
                                    .toList(growable: false);
                              }
                            });
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
                if (_templateIds.isEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '예약 가능한 수업을 1개 이상 선택해야 저장할 수 있습니다.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.errorForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: '상태'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('활성')),
                  DropdownMenuItem(value: 'inactive', child: Text('비활성')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _status = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: !_canSubmit
              ? null
              : () {
                  final totalCount = int.tryParse(_countController.text.trim());
                  final validDays = int.tryParse(
                    _validDaysController.text.trim(),
                  );
                  final priceAmount = double.tryParse(
                    _priceController.text.trim(),
                  );
                  if (_nameController.text.trim().isEmpty ||
                      totalCount == null ||
                      validDays == null ||
                      priceAmount == null ||
                      _templateIds.isEmpty) {
                    return;
                  }
                  Navigator.of(context).pop(
                    _PassProductFormData(
                      name: _nameController.text.trim(),
                      totalCount: totalCount,
                      validDays: validDays,
                      priceAmount: priceAmount,
                      description: _descriptionController.text.trim(),
                      status: _status,
                      templateIds: _templateIds,
                    ),
                  );
                },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _IssuePassDialog extends StatefulWidget {
  const _IssuePassDialog({required this.products});

  final List<AdminPassProduct> products;

  @override
  State<_IssuePassDialog> createState() => _IssuePassDialogState();
}

class _IssuePassDialogState extends State<_IssuePassDialog> {
  late String _selectedProductId;
  late DateTime _validFrom;
  late final TextEditingController _validFromController;
  late final TextEditingController _paidAmountController;

  AdminPassProduct get _selectedProduct =>
      widget.products.firstWhere((item) => item.id == _selectedProductId);

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.products.first.id;
    _validFrom = _normalizedDate(DateTime.now());
    _validFromController = TextEditingController(
      text: _adminDateInputValue(_validFrom),
    );
    _paidAmountController = TextEditingController(
      text: '${widget.products.first.priceAmount}',
    );
  }

  @override
  void dispose() {
    _validFromController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProduct = _selectedProduct;
    final allowedTemplateNames = selectedProduct.allowedTemplateNames;
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '수강권 발급',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedProductId,
              decoration: const InputDecoration(labelText: '수강권 상품'),
              items: widget.products
                  .map(
                    (product) => DropdownMenuItem(
                      value: product.id,
                      child: Text(product.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                final product = widget.products.firstWhere(
                  (item) => item.id == value,
                );
                setState(() {
                  _selectedProductId = value;
                  _paidAmountController.text = '${product.priceAmount}';
                });
              },
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이 수강권으로 예약 가능한 정규 강좌',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (allowedTemplateNames.isEmpty)
                    Text(
                      '현재 연결된 정규 수업 템플릿이 없습니다.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.errorForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allowedTemplateNames
                          .map(
                            (name) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.infoBackground,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                name,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: AppColors.infoForeground,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AdminDateInputField(
              controller: _validFromController,
              label: '시작일',
              onTap: _pickValidFrom,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _paidAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '결제 금액'),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            final paidAmount = double.tryParse(
              _paidAmountController.text.trim(),
            );
            Navigator.of(context).pop(
              _IssuePassFormData(
                passProductId: _selectedProductId,
                validFrom: _validFrom,
                paidAmount: paidAmount,
              ),
            );
          },
          child: const Text('발급'),
        ),
      ],
    );
  }

  Future<void> _pickValidFrom() async {
    final picked = await _pickAdminDate(context, initialDate: _validFrom);
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _validFrom = picked;
      _validFromController.text = _adminDateInputValue(picked);
    });
  }
}

class _CreateSessionDialog extends StatefulWidget {
  const _CreateSessionDialog({
    required this.templates,
    required this.products,
    required this.instructors,
  });

  final List<AdminClassTemplate> templates;
  final List<AdminPassProduct> products;
  final List<AdminInstructor> instructors;

  @override
  State<_CreateSessionDialog> createState() => _CreateSessionDialogState();
}

enum _CreateSessionMode { templateApplied, oneOff }

class _CreateSessionDialogState extends State<_CreateSessionDialog> {
  late _CreateSessionMode _mode;
  late List<String> _selectedTemplateIds;
  DateTime? _templateStartDate;
  DateTime? _templateEndDate;
  late DateTime _oneOffDate;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _oneOffDateController;
  final TextEditingController _oneOffNameController = TextEditingController();
  final TextEditingController _oneOffDescriptionController =
      TextEditingController();
  final TextEditingController _oneOffStartTimeController =
      TextEditingController(text: '19:00');
  final TextEditingController _oneOffEndTimeController = TextEditingController(
    text: '20:20',
  );
  final TextEditingController _oneOffCapacityController = TextEditingController(
    text: '10',
  );
  String? _selectedOneOffInstructorId;
  late List<String> _selectedPassProductIds;

  @override
  void initState() {
    super.initState();
    _mode = widget.templates.isEmpty
        ? _CreateSessionMode.oneOff
        : _CreateSessionMode.templateApplied;
    _selectedTemplateIds = <String>[];
    final now = _normalizedDate(DateTime.now());
    _oneOffDate = now;
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    _oneOffDateController = TextEditingController(
      text: _adminDateInputValue(now),
    );
    _selectedPassProductIds = widget.products
        .map((product) => product.id)
        .toList(growable: false);
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _oneOffDateController.dispose();
    _oneOffNameController.dispose();
    _oneOffDescriptionController.dispose();
    _oneOffStartTimeController.dispose();
    _oneOffEndTimeController.dispose();
    _oneOffCapacityController.dispose();
    super.dispose();
  }

  bool get _canSubmitTemplateApplied {
    final startDate = _templateStartDate;
    final endDate = _templateEndDate;
    if (_selectedTemplateIds.isEmpty || startDate == null || endDate == null) {
      return false;
    }
    return !endDate.isBefore(startDate);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '수업 개설',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('수업 템플릿 적용'),
                    selected: _mode == _CreateSessionMode.templateApplied,
                    onSelected: widget.templates.isEmpty
                        ? null
                        : (selected) {
                            if (!selected) {
                              return;
                            }
                            setState(() {
                              _mode = _CreateSessionMode.templateApplied;
                            });
                          },
                  ),
                  ChoiceChip(
                    label: const Text('일회성 수업 생성'),
                    selected: _mode == _CreateSessionMode.oneOff,
                    onSelected: (selected) {
                      if (!selected) {
                        return;
                      }
                      setState(() {
                        _mode = _CreateSessionMode.oneOff;
                      });
                    },
                  ),
                ],
              ),
              if (widget.templates.isEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '활성 수업 템플릿이 없어 현재는 일회성 수업만 생성할 수 있습니다.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_mode == _CreateSessionMode.templateApplied) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '수업 템플릿',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '버튼을 눌러 여러 템플릿을 함께 선택할 수 있습니다.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.templates
                      .map(
                        (template) => FilterChip(
                          selected: _selectedTemplateIds.contains(template.id),
                          label: Text(template.name),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTemplateIds = [
                                  ..._selectedTemplateIds,
                                  template.id,
                                ];
                              } else {
                                _selectedTemplateIds = _selectedTemplateIds
                                    .where((id) => id != template.id)
                                    .toList(growable: false);
                              }
                            });
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
                if (_selectedTemplateIds.isEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '수업 템플릿을 1개 이상 선택해야 합니다.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.errorForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _AdminDateInputField(
                        controller: _startDateController,
                        label: '시작일',
                        onTap: _pickTemplateStartDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AdminDateInputField(
                        controller: _endDateController,
                        label: '종료일',
                        onTap: _pickTemplateEndDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      onPressed: _pickTemplateDateRange,
                      tooltip: '기간 선택',
                      icon: const Icon(Icons.calendar_month_rounded),
                    ),
                  ],
                ),
                if (_templateStartDate == null || _templateEndDate == null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '시작일과 종료일을 모두 선택해야 합니다.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.errorForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ] else if (_templateEndDate!.isBefore(_templateStartDate!)) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '종료일은 시작일보다 빠를 수 없습니다.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.errorForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                TextField(
                  controller: _oneOffNameController,
                  decoration: const InputDecoration(labelText: '수업명'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _oneOffDescriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '설명'),
                ),
                const SizedBox(height: 12),
                _AdminDateInputField(
                  controller: _oneOffDateController,
                  label: '날짜',
                  onTap: _pickOneOffDate,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _AdminTimeInputField(
                        controller: _oneOffStartTimeController,
                        label: '시작 시간',
                        onTap: _pickOneOffStartTime,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AdminTimeInputField(
                        controller: _oneOffEndTimeController,
                        label: '종료 시간',
                        onTap: _pickOneOffEndTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value:
                      widget.instructors.any(
                        (instructor) =>
                            instructor.id == _selectedOneOffInstructorId,
                      )
                      ? _selectedOneOffInstructorId
                      : null,
                  decoration: const InputDecoration(labelText: '강사 (선택)'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('강사 미지정'),
                    ),
                    ...widget.instructors.map(
                      (instructor) => DropdownMenuItem<String?>(
                        value: instructor.id,
                        child: Text(instructor.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedOneOffInstructorId = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _oneOffCapacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '정원'),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '노출 수강권',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '선택한 수강권을 가진 회원에게만 이 일회성 수업이 보입니다.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                  ),
                ),
                const SizedBox(height: 10),
                if (widget.products.isEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '활성 수강권 상품이 없어 일회성 수업에 연결할 수 없습니다.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.errorForeground,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.products
                        .map(
                          (product) => FilterChip(
                            selected: _selectedPassProductIds.contains(
                              product.id,
                            ),
                            label: Text(product.name),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedPassProductIds = [
                                    ..._selectedPassProductIds,
                                    product.id,
                                  ];
                                } else {
                                  _selectedPassProductIds =
                                      _selectedPassProductIds
                                          .where((id) => id != product.id)
                                          .toList(growable: false);
                                }
                              });
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed:
              _mode == _CreateSessionMode.templateApplied &&
                  !_canSubmitTemplateApplied
              ? null
              : () {
                  if (_mode == _CreateSessionMode.templateApplied) {
                    if (_selectedTemplateIds.isEmpty) {
                      showAppSnackBar(
                        context,
                        '수업 템플릿을 한 개 이상 선택하세요.',
                        isError: true,
                      );
                      return;
                    }
                    if (_templateStartDate == null ||
                        _templateEndDate == null) {
                      showAppSnackBar(
                        context,
                        '시작일과 종료일을 모두 선택하세요.',
                        isError: true,
                      );
                      return;
                    }
                    if (_templateEndDate!.isBefore(_templateStartDate!)) {
                      showAppSnackBar(
                        context,
                        '종료일은 시작일보다 빠를 수 없습니다.',
                        isError: true,
                      );
                      return;
                    }
                    Navigator.of(context).pop(
                      _CreateSessionFormData.template(
                        templateIds: _selectedTemplateIds,
                        startDate: _templateStartDate!,
                        endDate: _templateEndDate!,
                      ),
                    );
                    return;
                  }

                  final name = _oneOffNameController.text.trim();
                  final capacity = int.tryParse(
                    _oneOffCapacityController.text.trim(),
                  );
                  final startTime = _oneOffStartTimeController.text.trim();
                  final endTime = _oneOffEndTimeController.text.trim();
                  final parsedStartTime = _parseAdminTimeInput(startTime);
                  final parsedEndTime = _parseAdminTimeInput(endTime);
                  if (name.isEmpty) {
                    showAppSnackBar(context, '수업명을 입력하세요.', isError: true);
                    return;
                  }
                  if (capacity == null || capacity <= 0) {
                    showAppSnackBar(
                      context,
                      '정원은 1명 이상이어야 합니다.',
                      isError: true,
                    );
                    return;
                  }
                  if (parsedStartTime == null || parsedEndTime == null) {
                    showAppSnackBar(
                      context,
                      '시간은 HH:mm 형식으로 입력하세요.',
                      isError: true,
                    );
                    return;
                  }
                  if (_compareAdminTime(parsedStartTime, parsedEndTime) >= 0) {
                    showAppSnackBar(
                      context,
                      '종료 시간은 시작 시간보다 늦어야 합니다.',
                      isError: true,
                    );
                    return;
                  }
                  final passProductIds = _selectedPassProductIds.toSet().toList(
                    growable: false,
                  );
                  if (passProductIds.isEmpty) {
                    showAppSnackBar(
                      context,
                      '노출할 수강권을 한 개 이상 선택하세요.',
                      isError: true,
                    );
                    return;
                  }
                  Navigator.of(context).pop(
                    _CreateSessionFormData.oneOff(
                      name: name,
                      description: _oneOffDescriptionController.text.trim(),
                      sessionDate: _oneOffDate,
                      startTime: startTime,
                      endTime: endTime,
                      capacity: capacity,
                      passProductIds: passProductIds,
                      instructorId: _selectedOneOffInstructorId,
                    ),
                  );
                },
          child: const Text('개설'),
        ),
      ],
    );
  }

  Future<void> _pickTemplateStartDate() async {
    final initialDate =
        _templateStartDate ??
        _templateEndDate ??
        _normalizedDate(DateTime.now());
    final picked = await _pickAdminDate(context, initialDate: initialDate);
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _templateStartDate = _normalizedDate(picked);
      _startDateController.text = _adminDateInputValue(_templateStartDate!);
    });
  }

  Future<void> _pickTemplateEndDate() async {
    final initialDate =
        _templateEndDate ??
        _templateStartDate ??
        _normalizedDate(DateTime.now());
    final picked = await _pickAdminDate(context, initialDate: initialDate);
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _templateEndDate = _normalizedDate(picked);
      _endDateController.text = _adminDateInputValue(_templateEndDate!);
    });
  }

  Future<void> _pickTemplateDateRange() async {
    final picked = await _pickAdminDateRange(
      context,
      initialStartDate: _templateStartDate ?? _normalizedDate(DateTime.now()),
      initialEndDate:
          _templateEndDate ??
          _templateStartDate ??
          _normalizedDate(DateTime.now()),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _templateStartDate = _normalizedDate(picked.start);
      _templateEndDate = _normalizedDate(picked.end);
      _startDateController.text = _adminDateInputValue(_templateStartDate!);
      _endDateController.text = _adminDateInputValue(_templateEndDate!);
    });
  }

  Future<void> _pickOneOffDate() async {
    final picked = await _pickAdminDate(context, initialDate: _oneOffDate);
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _oneOffDate = picked;
      _oneOffDateController.text = _adminDateInputValue(picked);
    });
  }

  Future<void> _pickOneOffStartTime() async {
    final currentStart =
        _parseAdminTimeOfDay(_oneOffStartTimeController.text) ??
        const TimeOfDay(hour: 19, minute: 0);
    final pickedStart = await _pickAdminTime(
      context,
      initialTime: currentStart,
    );
    if (pickedStart == null || !mounted) {
      return;
    }

    setState(() {
      _oneOffStartTimeController.text = _adminTimeInputValue(pickedStart);
    });

    final currentEnd = _parseAdminTimeOfDay(_oneOffEndTimeController.text);
    final initialEnd =
        currentEnd != null &&
            _compareAdminTimeOfDay(currentEnd, pickedStart) > 0
        ? currentEnd
        : _addMinutesToTimeOfDay(pickedStart, 80);
    final pickedEnd = await _pickAdminTime(context, initialTime: initialEnd);
    if (pickedEnd == null || !mounted) {
      return;
    }

    setState(() {
      _oneOffEndTimeController.text = _adminTimeInputValue(pickedEnd);
    });
  }

  Future<void> _pickOneOffEndTime() async {
    final currentEnd =
        _parseAdminTimeOfDay(_oneOffEndTimeController.text) ??
        const TimeOfDay(hour: 20, minute: 20);
    final pickedEnd = await _pickAdminTime(context, initialTime: currentEnd);
    if (pickedEnd == null || !mounted) {
      return;
    }
    setState(() {
      _oneOffEndTimeController.text = _adminTimeInputValue(pickedEnd);
    });
  }
}

class _InstructorDialog extends StatefulWidget {
  const _InstructorDialog({this.initialValue});

  final AdminInstructor? initialValue;

  @override
  State<_InstructorDialog> createState() => _InstructorDialogState();
}

class _InstructorDialogState extends State<_InstructorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  PickedImageFile? _selectedImageFile;
  bool _removeImage = false;

  bool get _isPhoneValid => Formatters.isMobilePhone(_phoneController.text);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialValue?.name ?? '',
    );
    _phoneController = TextEditingController(
      text: Formatters.editablePhone(widget.initialValue?.phone),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: widget.initialValue == null ? '새 강사 등록' : '강사 정보 수정',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ImageUploadField(
                name: _nameController.text.trim().isEmpty
                    ? (widget.initialValue?.name ?? '강사')
                    : _nameController.text.trim(),
                label: '강사 대표 이미지',
                currentImageUrl: _removeImage
                    ? null
                    : widget.initialValue?.imageUrl,
                selectedImageBytes: _selectedImageFile?.bytes,
                helperText: _removeImage ? '저장 시 기존 이미지가 삭제됩니다.' : null,
                onPick: _pickInstructorImage,
                showPickButton: false,
                previewOverlayLabel: widget.initialValue == null ? '업로드' : null,
                onClear:
                    _selectedImageFile != null ||
                        _removeImage ||
                        (!_removeImage &&
                            (widget.initialValue?.imageUrl?.isNotEmpty ??
                                false))
                    ? _clearInstructorImageSelection
                    : null,
                clearLabel: _selectedImageFile != null
                    ? '선택 취소'
                    : (_removeImage ? '삭제 취소' : '이미지 제거'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '강사 이름'),
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
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _nameController.text.trim().isNotEmpty && _isPhoneValid
              ? () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) {
                    showAppSnackBar(context, '강사 이름을 입력하세요.', isError: true);
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
                  Navigator.of(context).pop(
                    _InstructorFormData(
                      name: name,
                      phone: Formatters.storagePhone(_phoneController.text),
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

  Future<void> _pickInstructorImage() async {
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
      showAppSnackBar(context, ErrorText.format(error), isError: true);
    }
  }

  void _clearInstructorImageSelection() {
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

class _InstructorSessionsDialog extends StatefulWidget {
  const _InstructorSessionsDialog({
    required this.studioId,
    required this.instructor,
  });

  final String studioId;
  final AdminInstructor instructor;

  @override
  State<_InstructorSessionsDialog> createState() =>
      _InstructorSessionsDialogState();
}

class _InstructorSessionsDialogState extends State<_InstructorSessionsDialog> {
  List<AdminSessionSchedule> _sessions = const [];
  bool _loading = false;
  String? _error;
  late DateTime _visibleMonth;
  late Set<String> _selectedStatuses;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedStatuses = {'completed', 'scheduled', 'cancelled'};
    Future<void>.microtask(_refresh);
  }

  @override
  Widget build(BuildContext context) {
    final instructorSessions = _sessions
        .where((session) => session.instructorId == widget.instructor.id)
        .toList(growable: false);
    final filteredSessions =
        instructorSessions.where(_matchesSelectedStatus).toList(growable: false)
          ..sort((left, right) => left.startAt.compareTo(right.startAt));
    final stats = _InstructorMonthlyStats.fromSessions(instructorSessions);
    final availableYears = List<int>.generate(
      math.max(DateTime.now().year + 3, _visibleMonth.year + 3) - 2020 + 1,
      (index) => 2020 + index,
      growable: false,
    );

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.instructor.name} 강의 내역',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '월별로 진행/예정/취소된 수업 배정 내역을 확인합니다.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: DropdownButtonFormField<int>(
              value: _visibleMonth.year,
              isDense: true,
              decoration: const InputDecoration(
                labelText: '연도',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: availableYears
                  .map(
                    (year) => DropdownMenuItem<int>(
                      value: year,
                      child: Text('$year년'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (year) {
                if (year == null || year == _visibleMonth.year) {
                  return;
                }
                _updateVisibleMonth(year: year, month: _visibleMonth.month);
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: DropdownButtonFormField<int>(
              value: _visibleMonth.month,
              isDense: true,
              decoration: const InputDecoration(
                labelText: '월',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: List<int>.generate(12, (index) => index + 1)
                  .map(
                    (month) => DropdownMenuItem<int>(
                      value: month,
                      child: Text('$month월'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (month) {
                if (month == null || month == _visibleMonth.month) {
                  return;
                }
                _updateVisibleMonth(year: _visibleMonth.year, month: month);
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '닫기',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 760,
        height: 520,
        child: _error != null
            ? ErrorSection(message: _error!, onRetry: _refresh)
            : _loading && _sessions.isEmpty
            ? const LoadingSection()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SurfaceCard(
                    child: Row(
                      children: [
                        StudioAvatar(
                          name: widget.instructor.name,
                          imageUrl: widget.instructor.imageUrl,
                          size: 54,
                          borderRadius: 18,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.instructor.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.instructor.phone?.isNotEmpty == true
                                    ? Formatters.phone(widget.instructor.phone)
                                    : '핸드폰 번호 없음',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.body),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              selected: _selectedStatuses.contains('completed'),
                              label: Text('진행 ${stats.completedCount}'),
                              onSelected: (_) {
                                _toggleStatusFilter('completed');
                              },
                            ),
                            FilterChip(
                              selected: _selectedStatuses.contains('scheduled'),
                              label: Text('예정 ${stats.scheduledCount}'),
                              onSelected: (_) {
                                _toggleStatusFilter('scheduled');
                              },
                            ),
                            FilterChip(
                              selected: _selectedStatuses.contains('cancelled'),
                              label: Text('취소 ${stats.cancelledCount}'),
                              onSelected: (_) {
                                _toggleStatusFilter('cancelled');
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: instructorSessions.isEmpty
                        ? const EmptySection(
                            title: '선택한 달에 배정된 수업이 없습니다',
                            description: '다른 달을 선택하거나 수업 관리에서 강사를 배정하세요.',
                          )
                        : _selectedStatuses.isEmpty
                        ? const EmptySection(
                            title: '표시할 강의 상태를 선택하세요',
                            description: '상단의 진행, 예정, 취소 필터를 한 개 이상 선택하세요.',
                          )
                        : filteredSessions.isEmpty
                        ? const EmptySection(
                            title: '선택한 필터에 해당하는 강의 내역이 없습니다',
                            description: '상단 필터를 조정하거나 다른 달을 선택하세요.',
                          )
                        : ListView.separated(
                            itemCount: filteredSessions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final session = filteredSessions[index];
                              return SurfaceCard(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            session.className,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${Formatters.monthDay(session.sessionDate)} · ${Formatters.time(session.startAt)} - ${Formatters.time(session.endAt)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: AppColors.body,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    StatusPill(
                                      label: _sessionStatusLabel(
                                        session.status,
                                      ),
                                      backgroundColor: AppColors.surfaceAlt,
                                      foregroundColor:
                                          AppColors.neutralForeground,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      actions: const [],
    );
  }

  bool _matchesSelectedStatus(AdminSessionSchedule session) {
    switch (session.status) {
      case 'completed':
        return _selectedStatuses.contains('completed');
      case 'cancelled':
        return _selectedStatuses.contains('cancelled');
      default:
        return _selectedStatuses.contains('scheduled');
    }
  }

  Future<void> _refresh() async {
    final monthStart = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final monthEnd = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sessions = await context.read<AdminRepository>().fetchSessions(
        studioId: widget.studioId,
        startDate: monthStart,
        endDate: monthEnd,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sessions = sessions;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = ErrorText.format(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _toggleStatusFilter(String status) {
    setState(() {
      if (_selectedStatuses.contains(status)) {
        _selectedStatuses.remove(status);
      } else {
        _selectedStatuses.add(status);
      }
    });
  }

  Future<void> _updateVisibleMonth({
    required int year,
    required int month,
  }) async {
    setState(() {
      _visibleMonth = DateTime(year, month);
    });
    await _refresh();
  }
}

class _AssignSessionInstructorDialog extends StatefulWidget {
  const _AssignSessionInstructorDialog({
    required this.session,
    required this.instructors,
  });

  final AdminSessionSchedule session;
  final List<AdminInstructor> instructors;

  @override
  State<_AssignSessionInstructorDialog> createState() =>
      _AssignSessionInstructorDialogState();
}

class _AssignSessionInstructorDialogState
    extends State<_AssignSessionInstructorDialog> {
  late String? _selectedInstructorId;

  @override
  void initState() {
    super.initState();
    _selectedInstructorId =
        widget.instructors.any(
          (instructor) => instructor.id == widget.session.instructorId,
        )
        ? widget.session.instructorId
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: '강사 지정',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.session.className,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${Formatters.monthDay(widget.session.sessionDate)} · ${Formatters.time(widget.session.startAt)} - ${Formatters.time(widget.session.endAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              value: _selectedInstructorId,
              decoration: const InputDecoration(labelText: '강사'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('강사 미지정'),
                ),
                ...widget.instructors.map(
                  (instructor) => DropdownMenuItem<String?>(
                    value: instructor.id,
                    child: Text(instructor.name),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedInstructorId = value;
                });
              },
            ),
            if (widget.instructors.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '등록된 강사가 없어 지금은 미지정만 선택할 수 있습니다.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _AssignSessionInstructorFormData(
                instructorId: _selectedInstructorId,
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _AdminDateInputField extends StatelessWidget {
  const _AdminDateInputField({
    required this.controller,
    required this.label,
    required this.onTap,
    this.showCalendarIcon = true,
  });

  final TextEditingController controller;
  final String label;
  final Future<void> Function() onTap;
  final bool showCalendarIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: showCalendarIcon
            ? IconButton(
                onPressed: onTap,
                icon: const Icon(Icons.calendar_month_rounded),
              )
            : null,
      ),
    );
  }
}

class _AdminTimeInputField extends StatelessWidget {
  const _AdminTimeInputField({
    required this.controller,
    required this.label,
    required this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.schedule_rounded),
        ),
      ),
    );
  }
}

class _CancelDecisionDialog extends StatefulWidget {
  const _CancelDecisionDialog({required this.approve});

  final bool approve;

  @override
  State<_CancelDecisionDialog> createState() => _CancelDecisionDialogState();
}

class _CancelDecisionDialogState extends State<_CancelDecisionDialog> {
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _AdminDialogTitle(
        title: widget.approve ? '취소 승인' : '취소 거절',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 440,
        child: TextField(
          controller: _commentController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: widget.approve ? '회원에게 전달할 코멘트' : '거절 사유',
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(_commentController.text.trim());
          },
          child: Text(widget.approve ? '승인' : '거절'),
        ),
      ],
    );
  }
}

class _StudioSettingsFormData {
  const _StudioSettingsFormData({
    required this.contactPhone,
    required this.address,
    required this.imageFile,
    required this.removeImage,
    required this.password,
  });

  final String contactPhone;
  final String address;
  final PickedImageFile? imageFile;
  final bool removeImage;
  final String password;
}

class _StudioCancelPolicyFormData {
  const _StudioCancelPolicyFormData({
    required this.cancelPolicyMode,
    required this.cancelPolicyHoursBefore,
    required this.cancelPolicyDaysBefore,
    required this.cancelPolicyCutoffTime,
  });

  final String cancelPolicyMode;
  final int cancelPolicyHoursBefore;
  final int cancelPolicyDaysBefore;
  final String cancelPolicyCutoffTime;
}

class _NoticeFormData {
  const _NoticeFormData({
    required this.title,
    required this.body,
    required this.isImportant,
    required this.isPublished,
    required this.status,
    required this.visibleFrom,
    required this.visibleUntil,
  });

  final String title;
  final String body;
  final bool isImportant;
  final bool isPublished;
  final String status;
  final DateTime? visibleFrom;
  final DateTime? visibleUntil;
}

class _EventFormData {
  const _EventFormData({
    required this.title,
    required this.body,
    required this.isImportant,
    required this.isPublished,
    required this.status,
    required this.visibleFrom,
    required this.visibleUntil,
  });

  final String title;
  final String body;
  final bool isImportant;
  final bool isPublished;
  final String status;
  final DateTime? visibleFrom;
  final DateTime? visibleUntil;
}

class _TemplateFormData {
  const _TemplateFormData({
    required this.name,
    required this.description,
    required this.dayOfWeekMask,
    required this.startTime,
    required this.endTime,
    required this.defaultInstructorId,
    required this.capacity,
    required this.status,
  });

  final String name;
  final String description;
  final List<String> dayOfWeekMask;
  final String startTime;
  final String endTime;
  final String? defaultInstructorId;
  final int capacity;
  final String status;
}

class _PassProductFormData {
  const _PassProductFormData({
    required this.name,
    required this.totalCount,
    required this.validDays,
    required this.priceAmount,
    required this.description,
    required this.status,
    required this.templateIds,
  });

  final String name;
  final int totalCount;
  final int validDays;
  final double priceAmount;
  final String description;
  final String status;
  final List<String> templateIds;
}

class _IssuePassFormData {
  const _IssuePassFormData({
    required this.passProductId,
    required this.validFrom,
    required this.paidAmount,
  });

  final String passProductId;
  final DateTime validFrom;
  final double? paidAmount;
}

class _InstructorFormData {
  const _InstructorFormData({
    required this.name,
    required this.phone,
    required this.imageFile,
    required this.removeImage,
  });

  final String name;
  final String phone;
  final PickedImageFile? imageFile;
  final bool removeImage;
}

class _AssignSessionInstructorFormData {
  const _AssignSessionInstructorFormData({required this.instructorId});

  final String? instructorId;
}

class _InstructorMonthlyStats {
  const _InstructorMonthlyStats({
    required this.scheduledCount,
    required this.completedCount,
    required this.cancelledCount,
  });

  final int scheduledCount;
  final int completedCount;
  final int cancelledCount;

  factory _InstructorMonthlyStats.fromSessions(
    List<AdminSessionSchedule> sessions,
  ) {
    var scheduledCount = 0;
    var completedCount = 0;
    var cancelledCount = 0;

    for (final session in sessions) {
      switch (session.status) {
        case 'completed':
          completedCount += 1;
          break;
        case 'cancelled':
          cancelledCount += 1;
          break;
        default:
          scheduledCount += 1;
          break;
      }
    }

    return _InstructorMonthlyStats(
      scheduledCount: scheduledCount,
      completedCount: completedCount,
      cancelledCount: cancelledCount,
    );
  }
}

class _EditUserPassFormData {
  const _EditUserPassFormData({
    required this.totalCount,
    required this.paidAmount,
    required this.validFrom,
    required this.validUntil,
  });

  final int totalCount;
  final double paidAmount;
  final DateTime validFrom;
  final DateTime validUntil;
}

class _CreateSessionFormData {
  const _CreateSessionFormData.template({
    required this.templateIds,
    required this.startDate,
    required this.endDate,
  }) : mode = _CreateSessionMode.templateApplied,
       templateId = null,
       name = null,
       description = null,
       sessionDate = null,
       startTime = null,
       endTime = null,
       capacity = null,
       instructorId = null,
       passProductIds = null;

  const _CreateSessionFormData.oneOff({
    required this.name,
    required this.description,
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.instructorId,
    required this.passProductIds,
  }) : mode = _CreateSessionMode.oneOff,
       templateIds = null,
       templateId = null,
       startDate = null,
       endDate = null;

  final _CreateSessionMode mode;
  final List<String>? templateIds;
  final String? templateId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? name;
  final String? description;
  final DateTime? sessionDate;
  final String? startTime;
  final String? endTime;
  final int? capacity;
  final String? instructorId;
  final List<String>? passProductIds;
}

class _SessionDateRange {
  const _SessionDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool matches(_SessionDateRange other) {
    return _isSameCalendarDay(start, other.start) &&
        _isSameCalendarDay(end, other.end);
  }
}

class _AdminWeeklySessionPlacement {
  const _AdminWeeklySessionPlacement({
    required this.session,
    required this.top,
    required this.height,
    required this.columnIndex,
    required this.columnCount,
  });

  final AdminSessionSchedule session;
  final double top;
  final double height;
  final int columnIndex;
  final int columnCount;
}

class _WeeklyPlacementDraft {
  const _WeeklyPlacementDraft({
    required this.session,
    required this.columnIndex,
  });

  final AdminSessionSchedule session;
  final int columnIndex;
}

const _dayOptions = {
  'mon': '월',
  'tue': '화',
  'wed': '수',
  'thu': '목',
  'fri': '금',
  'sat': '토',
  'sun': '일',
};

String _weekdayLabels(List<String> days) {
  return days.map((day) => _dayOptions[day] ?? day).join(', ');
}

String _weekdayLabelForDate(DateTime day) {
  return const ['월', '화', '수', '목', '금', '토', '일'][day.weekday - 1];
}

String _adminDateInputValue(DateTime value) {
  return DateFormat('yyyy-MM-dd').format(_normalizedDate(value));
}

DateTime _normalizedDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _startOfAdminDay(DateTime value) {
  final normalized = _normalizedDate(value);
  return DateTime(normalized.year, normalized.month, normalized.day);
}

bool _isAdminDayStart(DateTime value) {
  return value.hour == 0 &&
      value.minute == 0 &&
      value.second == 0 &&
      value.millisecond == 0 &&
      value.microsecond == 0;
}

bool _isAdminDayEnd(DateTime value) {
  return value.hour == 23 &&
      value.minute == 59 &&
      value.second == 59 &&
      value.millisecond == 999;
}

Future<DateTime?> _pickAdminDate(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final normalizedFirstDate = _normalizedDate(
    firstDate ?? DateTime(2020, 1, 1),
  );
  final normalizedLastDate = _normalizedDate(
    lastDate ?? DateTime(2100, 12, 31),
  );
  final safeLastDate = normalizedLastDate.isBefore(normalizedFirstDate)
      ? normalizedFirstDate
      : normalizedLastDate;
  final safeInitialDate = _clampAdminDate(
    _normalizedDate(initialDate),
    normalizedFirstDate,
    safeLastDate,
  );
  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => _AdminCompactDateDialog(
      initialDate: safeInitialDate,
      firstDate: normalizedFirstDate,
      lastDate: safeLastDate,
    ),
  );
}

Future<DateTimeRange?> _pickAdminDateRange(
  BuildContext context, {
  required DateTime initialStartDate,
  required DateTime initialEndDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final normalizedFirstDate = _normalizedDate(
    firstDate ?? DateTime(2020, 1, 1),
  );
  final normalizedLastDate = _normalizedDate(
    lastDate ?? DateTime(2100, 12, 31),
  );
  final safeLastDate = normalizedLastDate.isBefore(normalizedFirstDate)
      ? normalizedFirstDate
      : normalizedLastDate;
  final safeStartDate = _clampAdminDate(
    _normalizedDate(initialStartDate),
    normalizedFirstDate,
    safeLastDate,
  );
  final safeEndDate = _clampAdminDate(
    _normalizedDate(initialEndDate),
    safeStartDate,
    safeLastDate,
  );
  return showDialog<DateTimeRange>(
    context: context,
    builder: (dialogContext) => _AdminCompactDateRangeDialog(
      initialStartDate: safeStartDate,
      initialEndDate: safeEndDate,
      firstDate: normalizedFirstDate,
      lastDate: safeLastDate,
    ),
  );
}

Future<TimeOfDay?> _pickAdminTime(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    initialEntryMode: TimePickerEntryMode.dial,
    builder: (context, child) {
      if (child == null) {
        return const SizedBox.shrink();
      }
      final mediaQuery = MediaQuery.of(context);
      return MediaQuery(
        data: mediaQuery.copyWith(alwaysUse24HourFormat: true),
        child: child,
      );
    },
  );
}

class _AdminCompactDateDialog extends StatefulWidget {
  const _AdminCompactDateDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_AdminCompactDateDialog> createState() =>
      _AdminCompactDateDialogState();
}

class _AdminCompactDateDialogState extends State<_AdminCompactDateDialog> {
  late DateTime _selectedDay;
  late DateTime _displayMonth;

  DateTime get _firstAllowedMonth =>
      DateTime(widget.firstDate.year, widget.firstDate.month);
  DateTime get _lastAllowedMonth =>
      DateTime(widget.lastDate.year, widget.lastDate.month);

  @override
  void initState() {
    super.initState();
    _selectedDay = _clampAdminDate(
      widget.initialDate,
      widget.firstDate,
      widget.lastDate,
    );
    _displayMonth = DateTime(_selectedDay.year, _selectedDay.month);
  }

  @override
  Widget build(BuildContext context) {
    final previousMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
    final nextMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
    final canMovePrevious =
        previousMonth.isAtSameMomentAs(_firstAllowedMonth) ||
        previousMonth.isAfter(_firstAllowedMonth);
    final canMoveNext =
        nextMonth.isAtSameMomentAs(_lastAllowedMonth) ||
        nextMonth.isBefore(_lastAllowedMonth);

    return AlertDialog(
      title: _AdminDialogTitle(
        title: '날짜 선택',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: canMovePrevious ? _movePreviousMonth : null,
                  tooltip: '이전 달',
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '날짜를 선택하세요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.subtle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: canMoveNext ? _moveNextMonth : null,
                  tooltip: '다음 달',
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMonthCalendar(_displayMonth),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _adminDateInputValue(_selectedDay),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedDay),
          child: const Text('적용'),
        ),
      ],
    );
  }

  Widget _buildMonthCalendar(DateTime month) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            Formatters.yearMonth(month),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        TableCalendar<DateTime>(
          firstDay: widget.firstDate,
          lastDay: widget.lastDate,
          focusedDay: _focusedDayForMonth(month),
          locale: 'ko_KR',
          headerVisible: false,
          availableCalendarFormats: const {CalendarFormat.month: 'month'},
          startingDayOfWeek: StartingDayOfWeek.sunday,
          availableGestures: AvailableGestures.none,
          sixWeekMonthsEnforced: true,
          selectedDayPredicate: (day) => _isSameCalendarDay(day, _selectedDay),
          rowHeight: 38,
          daysOfWeekHeight: 20,
          calendarStyle: CalendarStyle(
            outsideDaysVisible: true,
            canMarkersOverflow: false,
            defaultDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            weekendDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            outsideDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            disabledDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            holidayDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            todayDecoration: BoxDecoration(
              color: AppColors.infoBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            todayTextStyle: const TextStyle(
              color: AppColors.infoForeground,
              fontWeight: FontWeight.w700,
            ),
            selectedTextStyle: const TextStyle(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w700,
            ),
            selectedDecoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: Theme.of(
              context,
            ).textTheme.labelSmall!.copyWith(color: AppColors.subtle),
            weekendStyle: Theme.of(
              context,
            ).textTheme.labelSmall!.copyWith(color: AppColors.subtle),
          ),
          calendarBuilders: CalendarBuilders<DateTime>(
            disabledBuilder: (context, day, focusedDay) => Center(
              child: Text(
                '${day.day}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.subtle.withValues(alpha: 0.42),
                ),
              ),
            ),
          ),
          enabledDayPredicate: (day) =>
              !day.isBefore(widget.firstDate) && !day.isAfter(widget.lastDate),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = _normalizedDate(selectedDay);
            });
          },
        ),
      ],
    );
  }

  void _movePreviousMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
    });
  }

  void _moveNextMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
    });
  }

  DateTime _focusedDayForMonth(DateTime month) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    if (monthStart.isBefore(widget.firstDate)) {
      return widget.firstDate;
    }
    if (monthEnd.isAfter(widget.lastDate)) {
      return widget.lastDate;
    }
    return monthStart;
  }
}

class _AdminCompactDateRangeDialog extends StatefulWidget {
  const _AdminCompactDateRangeDialog({
    required this.initialStartDate,
    required this.initialEndDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_AdminCompactDateRangeDialog> createState() =>
      _AdminCompactDateRangeDialogState();
}

class _AdminCompactDateRangeDialogState
    extends State<_AdminCompactDateRangeDialog> {
  late DateTime _baseMonth;
  late DateTime _rangeStart;
  DateTime? _rangeEnd;

  DateTime get _secondMonth => DateTime(_baseMonth.year, _baseMonth.month + 1);
  DateTime get _firstAllowedMonth =>
      DateTime(widget.firstDate.year, widget.firstDate.month);
  DateTime get _lastAllowedMonth =>
      DateTime(widget.lastDate.year, widget.lastDate.month);

  List<DateTime> get _displayedMonths {
    final months = <DateTime>[_baseMonth];
    if (!_secondMonth.isAfter(_lastAllowedMonth)) {
      months.add(_secondMonth);
    }
    return months;
  }

  @override
  void initState() {
    super.initState();
    _rangeStart = _clampAdminDate(
      widget.initialStartDate,
      widget.firstDate,
      widget.lastDate,
    );
    _rangeEnd = _clampAdminDate(
      widget.initialEndDate,
      _rangeStart,
      widget.lastDate,
    );
    _baseMonth = DateTime(_rangeStart.year, _rangeStart.month);
  }

  @override
  Widget build(BuildContext context) {
    final displayedMonths = _displayedMonths;
    final canMovePrevious =
        DateTime(
          _baseMonth.year,
          _baseMonth.month - 1,
        ).isAtSameMomentAs(_firstAllowedMonth) ||
        DateTime(
          _baseMonth.year,
          _baseMonth.month - 1,
        ).isAfter(_firstAllowedMonth);
    final canMoveNext =
        DateTime(
          _baseMonth.year,
          _baseMonth.month + 1,
        ).isAtSameMomentAs(_lastAllowedMonth) ||
        DateTime(
          _baseMonth.year,
          _baseMonth.month + 1,
        ).isBefore(_lastAllowedMonth);

    return AlertDialog(
      title: _AdminDialogTitle(
        title: '기간 선택',
        onClose: () => Navigator.of(context).pop(),
      ),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: canMovePrevious ? _movePreviousMonthPair : null,
                  tooltip: '이전 달',
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '시작일을 먼저 선택하고, 종료일을 선택하세요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.subtle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: canMoveNext ? _moveNextMonthPair : null,
                  tooltip: '다음 달',
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (displayedMonths.length == 1)
              SizedBox(
                width: 360,
                child: _buildMonthCalendar(displayedMonths.first),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildMonthCalendar(displayedMonths.first)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMonthCalendar(displayedMonths.last)),
                ],
              ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '시작일 ${_adminDateInputValue(_rangeStart)}'
                '  ·  종료일 ${_adminDateInputValue(_rangeEnd ?? _rangeStart)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              DateTimeRange(start: _rangeStart, end: _rangeEnd ?? _rangeStart),
            );
          },
          child: const Text('적용'),
        ),
      ],
    );
  }

  Widget _buildMonthCalendar(DateTime month) {
    final focusedDay = _focusedDayForMonth(month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            Formatters.yearMonth(month),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        TableCalendar<DateTime>(
          firstDay: widget.firstDate,
          lastDay: widget.lastDate,
          focusedDay: focusedDay,
          locale: 'ko_KR',
          headerVisible: false,
          availableCalendarFormats: const {CalendarFormat.month: 'month'},
          startingDayOfWeek: StartingDayOfWeek.sunday,
          availableGestures: AvailableGestures.none,
          sixWeekMonthsEnforced: true,
          rangeStartDay: _rangeStart,
          rangeEndDay: _rangeEnd,
          rangeSelectionMode: RangeSelectionMode.toggledOn,
          rowHeight: 38,
          daysOfWeekHeight: 20,
          calendarStyle: CalendarStyle(
            outsideDaysVisible: true,
            canMarkersOverflow: false,
            defaultDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            weekendDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            outsideDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            disabledDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            holidayDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            todayDecoration: BoxDecoration(
              color: AppColors.infoBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            todayTextStyle: const TextStyle(
              color: AppColors.infoForeground,
              fontWeight: FontWeight.w700,
            ),
            rangeStartDecoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            rangeEndDecoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            withinRangeDecoration: BoxDecoration(
              color: AppColors.primarySoft.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            rangeStartTextStyle: const TextStyle(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w700,
            ),
            rangeEndTextStyle: const TextStyle(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w700,
            ),
            withinRangeTextStyle: const TextStyle(
              color: AppColors.title,
              fontWeight: FontWeight.w600,
            ),
            selectedTextStyle: const TextStyle(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w700,
            ),
            selectedDecoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: Theme.of(
              context,
            ).textTheme.labelSmall!.copyWith(color: AppColors.subtle),
            weekendStyle: Theme.of(
              context,
            ).textTheme.labelSmall!.copyWith(color: AppColors.subtle),
          ),
          calendarBuilders: CalendarBuilders<DateTime>(
            disabledBuilder: (context, day, focusedDay) => Center(
              child: Text(
                '${day.day}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.subtle.withValues(alpha: 0.42),
                ),
              ),
            ),
          ),
          enabledDayPredicate: (day) =>
              !day.isBefore(widget.firstDate) && !day.isAfter(widget.lastDate),
          onDaySelected: (selectedDay, focusedDay) {
            _onDayTapped(_normalizedDate(selectedDay));
          },
        ),
      ],
    );
  }

  void _onDayTapped(DateTime selectedDay) {
    setState(() {
      if (_rangeEnd != null || _rangeStart.isAfter(selectedDay)) {
        _rangeStart = selectedDay;
        _rangeEnd = null;
        return;
      }

      if (_isSameCalendarDay(_rangeStart, selectedDay)) {
        _rangeEnd = selectedDay;
        return;
      }

      _rangeEnd = selectedDay;
    });
  }

  void _movePreviousMonthPair() {
    setState(() {
      _baseMonth = DateTime(_baseMonth.year, _baseMonth.month - 1);
    });
  }

  void _moveNextMonthPair() {
    setState(() {
      _baseMonth = DateTime(_baseMonth.year, _baseMonth.month + 1);
    });
  }

  DateTime _focusedDayForMonth(DateTime month) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    if (monthStart.isBefore(widget.firstDate)) {
      return widget.firstDate;
    }
    if (monthEnd.isAfter(widget.lastDate)) {
      return widget.lastDate;
    }
    return monthStart;
  }
}

DateTime _clampAdminDate(DateTime value, DateTime min, DateTime max) {
  if (value.isBefore(min)) {
    return min;
  }
  if (value.isAfter(max)) {
    return max;
  }
  return value;
}

DateTime? _parseAdminTimeInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  try {
    return DateFormat('HH:mm').parseStrict(trimmed);
  } catch (_) {
    return null;
  }
}

TimeOfDay? _parseAdminTimeOfDay(String raw) {
  final parsed = _parseAdminTimeInput(raw);
  if (parsed == null) {
    return null;
  }
  return TimeOfDay(hour: parsed.hour, minute: parsed.minute);
}

String _adminTimeInputValue(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

int _compareAdminTimeOfDay(TimeOfDay left, TimeOfDay right) {
  return (left.hour * 60 + left.minute) - (right.hour * 60 + right.minute);
}

TimeOfDay _addMinutesToTimeOfDay(TimeOfDay value, int minutesToAdd) {
  final totalMinutes =
      (value.hour * 60 + value.minute + minutesToAdd) % (24 * 60);
  final normalized = totalMinutes < 0 ? totalMinutes + 24 * 60 : totalMinutes;
  return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
}

int _compareAdminTime(DateTime left, DateTime right) {
  return (left.hour * 60 + left.minute) - (right.hour * 60 + right.minute);
}

DateTime _startOfWeek(DateTime day) {
  final normalized = DateTime(day.year, day.month, day.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

bool _isSameCalendarDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _calendarDayKey(DateTime day) {
  return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}

int _minutesSinceDayStart(DateTime value) {
  final kstValue = Formatters.kst(value);
  return kstValue.hour * 60 + kstValue.minute;
}

double _weeklyPlacementLeft({
  required double width,
  required _AdminWeeklySessionPlacement placement,
}) {
  const gap = 6.0;
  final usableWidth = width - gap * (placement.columnCount + 1);
  final columnWidth = usableWidth / placement.columnCount;
  return gap + (columnWidth + gap) * placement.columnIndex;
}

double _weeklyPlacementWidth({
  required double width,
  required _AdminWeeklySessionPlacement placement,
}) {
  const gap = 6.0;
  final usableWidth = width - gap * (placement.columnCount + 1);
  return usableWidth / placement.columnCount;
}

List<_AdminWeeklySessionPlacement> _buildWeeklySessionPlacements(
  List<AdminSessionSchedule> sessions, {
  required double hourHeight,
}) {
  if (sessions.isEmpty) {
    return const [];
  }

  final sorted = [...sessions]
    ..sort((left, right) {
      final byStart = left.startAt.compareTo(right.startAt);
      if (byStart != 0) {
        return byStart;
      }
      final byEnd = left.endAt.compareTo(right.endAt);
      if (byEnd != 0) {
        return byEnd;
      }
      return left.className.compareTo(right.className);
    });

  final placements = <_AdminWeeklySessionPlacement>[];
  var group = <AdminSessionSchedule>[];
  DateTime? groupEnd;

  void flushGroup() {
    if (group.isEmpty) {
      return;
    }
    placements.addAll(_layoutWeeklyOverlapGroup(group, hourHeight: hourHeight));
    group = <AdminSessionSchedule>[];
    groupEnd = null;
  }

  for (final session in sorted) {
    if (groupEnd == null) {
      group = <AdminSessionSchedule>[session];
      groupEnd = session.endAt;
      continue;
    }

    if (session.startAt.isBefore(groupEnd!)) {
      group.add(session);
      if (session.endAt.isAfter(groupEnd!)) {
        groupEnd = session.endAt;
      }
      continue;
    }

    flushGroup();
    group = <AdminSessionSchedule>[session];
    groupEnd = session.endAt;
  }

  flushGroup();
  return placements;
}

List<_AdminWeeklySessionPlacement> _layoutWeeklyOverlapGroup(
  List<AdminSessionSchedule> sessions, {
  required double hourHeight,
}) {
  final columnEndTimes = <DateTime>[];
  final drafts = <_WeeklyPlacementDraft>[];

  for (final session in sessions) {
    var columnIndex = -1;
    for (var index = 0; index < columnEndTimes.length; index++) {
      if (!session.startAt.isBefore(columnEndTimes[index])) {
        columnIndex = index;
        columnEndTimes[index] = session.endAt;
        break;
      }
    }

    if (columnIndex == -1) {
      columnIndex = columnEndTimes.length;
      columnEndTimes.add(session.endAt);
    }

    drafts.add(
      _WeeklyPlacementDraft(session: session, columnIndex: columnIndex),
    );
  }

  final columnCount = math.max(1, columnEndTimes.length);
  return drafts
      .map(
        (draft) => _AdminWeeklySessionPlacement(
          session: draft.session,
          top: _minutesSinceDayStart(draft.session.startAt) / 60 * hourHeight,
          height: math.max(
            draft.session.endAt.difference(draft.session.startAt).inMinutes /
                60 *
                hourHeight,
            46,
          ),
          columnIndex: draft.columnIndex,
          columnCount: columnCount,
        ),
      )
      .toList(growable: false);
}

String _cancelPolicySummary(AdminStudioSummary studio) {
  if (studio.cancelPolicyMode == 'days_before_time') {
    return '수업 ${studio.cancelPolicyDaysBefore}일 전 ${studio.cancelPolicyCutoffTime}까지 직접 취소 가능합니다.';
  }
  return '수업 ${studio.cancelPolicyHoursBefore}시간 전까지 직접 취소 가능합니다.';
}

bool _isSimpleTimeFormat(String value) {
  return RegExp(r'^\d{2}:\d{2}$').hasMatch(value);
}

String _contentWindowLabel(DateTime? start, DateTime? end) {
  if (start == null && end == null) {
    return '상시';
  }
  final startLabel = start == null
      ? '즉시'
      : _isAdminDayStart(start)
      ? _adminDateInputValue(start)
      : _adminDateTimeInputValue(start);
  final endLabel = end == null
      ? '제한 없음'
      : _isAdminDayEnd(end) || _isAdminDayStart(end)
      ? _adminDateInputValue(end)
      : _adminDateTimeInputValue(end);
  return '$startLabel - $endLabel';
}

String _adminDateTimeInputValue(DateTime? value) {
  if (value == null) {
    return '';
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
}

String _currency(double value) {
  final formatter = NumberFormat.currency(
    locale: 'ko_KR',
    symbol: '₩',
    decimalDigits: 0,
  );
  return formatter.format(value);
}

String _memberPassHoldButtonLabel(AdminMemberPassHistory history) {
  final holdDays = _memberPassActiveOrUpcomingHoldDays(history);
  if (holdDays != null && holdDays > 0) {
    return '홀딩 $holdDays일';
  }
  return '홀딩';
}

int? _memberPassActiveOrUpcomingHoldDays(AdminMemberPassHistory history) {
  final holdFrom = history.activeHoldFrom ?? history.latestHoldFrom;
  final holdUntil = history.activeHoldUntil ?? history.latestHoldUntil;
  if (holdFrom == null || holdUntil == null) {
    return null;
  }
  final today = _normalizedDate(DateTime.now());
  if (_normalizedDate(holdUntil).isBefore(today)) {
    return null;
  }
  return _normalizedDate(
        holdUntil,
      ).difference(_normalizedDate(holdFrom)).inDays +
      1;
}

int? _memberPassHistoryExpiringSoonDays(AdminMemberPassHistory history) {
  if (history.status != 'active' || history.isRefunded || history.isExhausted) {
    return null;
  }
  final today = _normalizedDate(DateTime.now());
  final validUntil = _normalizedDate(history.validUntil);
  if (validUntil.isBefore(today)) {
    return null;
  }
  final days = validUntil.difference(today).inDays;
  if (days > 14) {
    return null;
  }
  return days;
}

String? _memberPassHistoryStatusLabel(AdminMemberPassHistory history) {
  if (history.isCurrentlyHolding) {
    return '홀딩 중';
  }
  if (history.status == 'refunded') {
    return '환불 처리 완료';
  }
  if (history.refundedAmount > 0) {
    return '부분 환불';
  }
  if (history.isExhausted) {
    return '전부 사용';
  }
  if (history.status == 'inactive') {
    return '비활성';
  }
  return null;
}

Color _memberPassHistoryStatusBackground(AdminMemberPassHistory history) {
  if (history.isCurrentlyHolding) {
    return AppColors.infoBackground;
  }
  if (history.isRefunded) {
    return AppColors.errorBackground;
  }
  if (history.isExhausted) {
    return AppColors.neutralBackground;
  }
  if (history.status == 'expired') {
    return AppColors.surfaceMuted;
  }
  return AppColors.successBackground;
}

Color _memberPassHistoryStatusForeground(AdminMemberPassHistory history) {
  if (history.isCurrentlyHolding) {
    return AppColors.infoForeground;
  }
  if (history.isRefunded) {
    return AppColors.errorForeground;
  }
  if (history.isExhausted || history.status == 'expired') {
    return AppColors.neutralForeground;
  }
  return AppColors.successForeground;
}

class _RefundUserPassFormData {
  const _RefundUserPassFormData({required this.refundAmount});

  final double refundAmount;
}

class _HoldUserPassFormData {
  const _HoldUserPassFormData({
    this.action = _HoldUserPassAction.save,
    required this.holdFrom,
    required this.holdUntil,
  });

  final _HoldUserPassAction action;
  final DateTime? holdFrom;
  final DateTime? holdUntil;
}

enum _HoldUserPassAction { save, cancel }

String _daysUntilExpiryLabel(int daysUntilExpiry) {
  if (daysUntilExpiry <= 0) {
    return '오늘 만료';
  }
  return 'D-$daysUntilExpiry';
}

int _attendeeStatusOrder(String status) {
  switch (status) {
    case 'reserved':
      return 0;
    case 'cancel_requested':
      return 1;
    case 'waitlisted':
      return 2;
    default:
      return 9;
  }
}

bool _isReservedBucketStatus(String status) {
  return status == 'reserved' ||
      status == 'cancel_requested' ||
      status == 'studio_rejected';
}

String _attendeeStatusLabel(String status) {
  switch (status) {
    case 'reserved':
      return '예약';
    case 'cancel_requested':
      return '취소 요청';
    case 'waitlisted':
      return '대기';
    default:
      return Formatters.reservationStatus(status);
  }
}

Color _attendeeStatusBackground(String status) {
  switch (status) {
    case 'reserved':
      return AppColors.successBackground;
    case 'cancel_requested':
      return AppColors.highlightBackground;
    case 'waitlisted':
      return AppColors.waitlistBackground;
    default:
      return AppColors.neutralBackground;
  }
}

Color _attendeeStatusForeground(String status) {
  switch (status) {
    case 'reserved':
      return AppColors.successForeground;
    case 'cancel_requested':
      return AppColors.highlightForeground;
    case 'waitlisted':
      return AppColors.waitlistForeground;
    default:
      return AppColors.neutralForeground;
  }
}

Color _sessionTemplateBackground(String templateId) {
  return _templateToneFor(templateId).background;
}

Color _sessionTemplateForeground(String templateId) {
  return _templateToneFor(templateId).foreground;
}

bool _hasProcessableWaitlist(AdminSessionSchedule session) {
  if (session.status != 'scheduled') {
    return false;
  }
  if (session.waitlistCount <= 0) {
    return false;
  }
  if (!session.startAt.isAfter(DateTime.now())) {
    return false;
  }
  return session.reservedCount < session.capacity;
}

String _sessionStatusLabel(String status) {
  switch (status) {
    case 'scheduled':
      return '예정';
    case 'completed':
      return '완료';
    case 'cancelled':
      return '휴강';
    default:
      return status;
  }
}

_TemplateTone _templateToneFor(String templateId) {
  final tones = _templateTones;
  final hash = templateId.codeUnits.fold<int>(
    0,
    (value, unit) => (value * 31 + unit) & 0x7fffffff,
  );
  return tones[hash % tones.length];
}

const List<_TemplateTone> _templateTones = [
  _TemplateTone(background: Color(0xFFDCE5FF), foreground: Color(0xFF2C4BCB)),
  _TemplateTone(background: Color(0xFFE7DDFE), foreground: Color(0xFF5A36C5)),
  _TemplateTone(background: Color(0xFFFFE2F6), foreground: Color(0xFFA43FA0)),
  _TemplateTone(background: Color(0xFFDDF3FF), foreground: Color(0xFF2E77B7)),
  _TemplateTone(background: Color(0xFFE6F4EC), foreground: Color(0xFF1D7A4E)),
];

class _TemplateTone {
  const _TemplateTone({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}
