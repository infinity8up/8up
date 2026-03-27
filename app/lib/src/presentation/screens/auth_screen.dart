import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../providers/auth_controller.dart';
import '../widgets/common_widgets.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final wideLayout = isWideLayout(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: Stack(
          children: [
            const Positioned(
              top: -140,
              left: -60,
              child: _AuthBackdropOrb(
                size: 280,
                colors: [Color(0x40FFFFFF), Color(0x0AFFFFFF)],
              ),
            ),
            const Positioned(
              top: 120,
              right: -90,
              child: _AuthBackdropOrb(
                size: 260,
                colors: [Color(0x22FFFFFF), Color(0x08FFFFFF)],
              ),
            ),
            const Positioned(
              bottom: -120,
              left: 20,
              child: _AuthBackdropOrb(
                size: 240,
                colors: [Color(0x1FFFFFFF), Color(0x05FFFFFF)],
              ),
            ),
            SafeArea(
              child: ListView(
                children: [
                  AppViewport(
                    maxWidth: 560,
                    padding: EdgeInsets.fromLTRB(
                      wideLayout ? 32 : 20,
                      wideLayout ? 40 : 24,
                      wideLayout ? 32 : 20,
                      24,
                    ),
                    child: _AuthFormPanel(
                      auth: auth,
                      onSubmitKakaoSignIn: () async {
                        try {
                          await context
                              .read<AuthController>()
                              .signInWithKakao();
                        } catch (_) {
                          if (!context.mounted) {
                            return;
                          }
                          showAppSnackBar(
                            context,
                            auth.error ?? '카카오 로그인에 실패했습니다.',
                            isError: true,
                          );
                        }
                      },
                      onSubmitGoogleSignIn: () async {
                        try {
                          await context
                              .read<AuthController>()
                              .signInWithGoogle();
                        } catch (_) {
                          if (!context.mounted) {
                            return;
                          }
                          showAppSnackBar(
                            context,
                            auth.error ?? 'Google 로그인에 실패했습니다.',
                            isError: true,
                          );
                        }
                      },
                      onSubmitAppleSignIn: () async {
                        try {
                          await context
                              .read<AuthController>()
                              .signInWithApple();
                        } catch (_) {
                          if (!context.mounted) {
                            return;
                          }
                          showAppSnackBar(
                            context,
                            auth.error ?? 'Apple 로그인에 실패했습니다.',
                            isError: true,
                          );
                        }
                      },
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
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({
    required this.auth,
    required this.onSubmitKakaoSignIn,
    required this.onSubmitGoogleSignIn,
    required this.onSubmitAppleSignIn,
  });

  final AuthController auth;
  final Future<void> Function() onSubmitKakaoSignIn;
  final Future<void> Function() onSubmitGoogleSignIn;
  final Future<void> Function() onSubmitAppleSignIn;

  @override
  Widget build(BuildContext context) {
    final appleSupported =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x221F2340),
                blurRadius: 30,
                offset: Offset(0, 18),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            children: [
              Image.asset(
                kBrandLogoAssetPath,
                height: 88,
                fit: BoxFit.fitHeight,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(height: 20),
              Text(
                '예약과 출결을 앱에서 확인하세요',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.title,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                appleSupported
                    ? 'Google, Kakao 또는 Apple 계정으로 지금 바로 시작하세요'
                    : 'Google 또는 Kakao 계정으로 지금 바로 시작하세요',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.subtle,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: _SocialSignInButton(
                  onPressed: auth.isBusy ? null : onSubmitKakaoSignIn,
                  backgroundColor: const Color(0xFFFEE500),
                  foregroundColor: const Color(0xFF191919),
                  disabledBackgroundColor: const Color(0xFFF8E57A),
                  disabledForegroundColor: const Color(0x99191919),
                  icon: const _KakaoMark(size: 20),
                  label: '카카오로 시작하기',
                  progressColor: const Color(0xFF191919),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _SocialSignInButton(
                  onPressed: auth.isBusy ? null : onSubmitGoogleSignIn,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1F1F1F),
                  disabledBackgroundColor: const Color(0xFFF2F2F2),
                  disabledForegroundColor: const Color(0x801F1F1F),
                  borderSide: const BorderSide(color: Color(0xFFDADCE0)),
                  icon: const _GoogleMark(size: 20),
                  label: 'Google로 시작하기',
                  progressColor: AppColors.primaryStrong,
                ),
              ),
              if (appleSupported) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _SocialSignInButton(
                    onPressed: auth.isBusy ? null : onSubmitAppleSignIn,
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF333333),
                    disabledForegroundColor: const Color(0x99FFFFFF),
                    icon: const Icon(Icons.apple, size: 20),
                    label: 'Apple로 시작하기',
                    progressColor: Colors.white,
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

class _AuthBackdropOrb extends StatelessWidget {
  const _AuthBackdropOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/branding/google_signin_mark.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _KakaoMark extends StatelessWidget {
  const _KakaoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/branding/kakao_sync_mark.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _SocialSignInButton extends StatelessWidget {
  const _SocialSignInButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.disabledBackgroundColor,
    required this.disabledForegroundColor,
    required this.icon,
    required this.label,
    required this.progressColor,
    this.borderSide,
  });

  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color disabledBackgroundColor;
  final Color disabledForegroundColor;
  final Widget icon;
  final String label;
  final Color progressColor;
  final BorderSide? borderSide;

  @override
  Widget build(BuildContext context) {
    final isBusy = onPressed == null;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: disabledBackgroundColor,
        disabledForegroundColor: disabledForegroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: borderSide ?? BorderSide.none,
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          icon,
          const SizedBox(width: 12),
          if (isBusy)
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: progressColor,
              ),
            )
          else
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
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
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Center(
            child: AppViewport(
              maxWidth: 520,
              padding: const EdgeInsets.all(20),
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
                          '새 비밀번호 설정',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '이메일에서 열어둔 복구 링크로 새 비밀번호를 저장하세요.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.subtle),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '새 비밀번호',
                          ),
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
      ),
    );
  }

  Future<void> _submit() async {
    final auth = context.read<AuthController>();
    final password = _passwordController.text;
    if (password.length < 6) {
      showAppSnackBar(context, '비밀번호는 6자 이상이어야 합니다.', isError: true);
      return;
    }
    if (password != _confirmPasswordController.text) {
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
