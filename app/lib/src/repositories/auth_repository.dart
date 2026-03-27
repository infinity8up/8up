import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth_redirects.dart';

const String _appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
const String _googleWebClientIdDefine = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
);
const String _googleWebClientIdDevDefine = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID_DEV',
);
const String _googleWebClientIdRealDefine = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID_REAL',
);

String get _googleWebClientId {
  if (_googleWebClientIdDefine.isNotEmpty) {
    return _googleWebClientIdDefine;
  }

  final normalizedAppEnv = _appEnv.trim().toLowerCase();
  final useRealEnv =
      normalizedAppEnv == 'real' ||
      normalizedAppEnv == 'prod' ||
      normalizedAppEnv == 'production';

  if (useRealEnv && _googleWebClientIdRealDefine.isNotEmpty) {
    return _googleWebClientIdRealDefine;
  }
  if (!useRealEnv && _googleWebClientIdDevDefine.isNotEmpty) {
    return _googleWebClientIdDevDefine;
  }

  return '16763749845-qjqkuovh0o7hj594lk2llqstqsjdp0p4.apps.googleusercontent.com';
}

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId: _googleWebClientId,
  );

  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final email = await _resolveSignInEmail(identifier);
    if (email == null) {
      throw Exception('로그인 아이디 또는 이메일을 찾을 수 없습니다.');
    }

    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await _client.rpc(
      'register_member_account',
      params: {
        'p_name': name.trim(),
        'p_email': email.trim().toLowerCase(),
        'p_password': password,
      },
    );
  }

  Future<void> signUpWithEmailConfirmation({
    required String name,
    required String email,
    required String password,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: currentAuthRedirectUrl(),
      data: {'name': name, 'account_type': 'member'},
    );
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      throw Exception('Google 로그인은 현재 모바일 앱에서만 지원합니다.');
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS는 nonce mismatch를 피하기 위해 Supabase 브라우저 OAuth를 사용한다.
      // SFSafariViewController에서 authorize URL 로드 실패가 간헐적으로 발생해
      // 외부 Safari로 여는 쪽이 더 안정적이다.
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: currentAuthRedirectUrl(),
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: const {'prompt': 'select_account'},
      );
      return;
    }

    await _clearGoogleSignInSelection();

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      return;
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google ID 토큰을 가져오지 못했습니다.');
    }

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );

    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'name': googleUser.displayName ?? googleUser.email.split('@').first,
          'account_type': 'member',
        },
      ),
    );
  }

  Future<void> signInWithKakao() async {
    if (kIsWeb) {
      await _client.auth.signInWithOAuth(
        OAuthProvider.kakao,
        redirectTo: currentAuthRedirectUrl(),
      );
      return;
    }

    await _client.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: currentAuthRedirectUrl(),
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  Future<void> signInWithApple() async {
    if (kIsWeb) {
      throw Exception('Apple 로그인은 현재 모바일 앱에서만 지원합니다.');
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: currentAuthRedirectUrl(),
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.iOS) {
      throw Exception('Apple 로그인은 현재 iPhone 또는 Android 앱에서만 지원합니다.');
    }

    final rawNonce = _generateNonce();
    final hashedNonce = _sha256Of(rawNonce);

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Apple identity token을 가져오지 못했습니다.');
    }

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    final displayName = _buildAppleDisplayName(credential);
    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'account_type': 'member',
          if (displayName.isNotEmpty) 'name': displayName,
        },
      ),
    );
  }

  Future<void> updatePassword({required String password}) {
    return _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> updateAccount({required String name, required String email}) {
    return _client.auth.updateUser(
      UserAttributes(email: email, data: {'name': name}),
    );
  }

  Future<void> deleteAccount() async {
    try {
      await _client.rpc('delete_my_account');
      await signOut();
    } on PostgrestException catch (error) {
      if (error.message.contains('delete_my_account')) {
        throw Exception('Supabase에 `delete_my_account` RPC를 구현한 뒤 연결해 주세요.');
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    await _clearGoogleSignInSelection();
  }

  Future<String?> _resolveSignInEmail(String identifier) async {
    final normalized = identifier.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.contains('@')) {
      return normalized.toLowerCase();
    }

    final response = await _client.rpc(
      'resolve_sign_in_email',
      params: {'p_identifier': normalized},
    );
    if (response is String && response.isNotEmpty) {
      return response;
    }
    return null;
  }

  String _buildAppleDisplayName(AuthorizationCredentialAppleID credential) {
    final givenName = credential.givenName?.trim() ?? '';
    final familyName = credential.familyName?.trim() ?? '';
    return [familyName, givenName].where((value) => value.isNotEmpty).join(' ');
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256Of(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  Future<void> _clearGoogleSignInSelection() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) {
      return;
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Best effort only. Supabase logout should still complete even if
      // the native Google plugin has no cached selection to clear.
    }
  }
}
