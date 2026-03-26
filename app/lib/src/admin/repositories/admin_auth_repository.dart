import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_redirects.dart';

class AdminAuthRepository {
  AdminAuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final context = await _resolveSignInContext(identifier);
    if (context == null) {
      throw Exception('로그인 ID를 찾을 수 없습니다.');
    }
    if (context.signInState == 'pending') {
      throw Exception(context.message ?? '8UP 관리자가 등록 진행중입니다.');
    }
    if (context.signInState == 'rejected') {
      throw Exception(context.message ?? '스튜디오 등록 요청이 반려되었습니다.');
    }
    if (context.email == null || context.email!.isEmpty) {
      throw Exception('로그인 ID를 찾을 수 없습니다.');
    }

    await _client.auth.signInWithPassword(
      email: context.email!,
      password: password,
    );
  }

  Future<void> signUpStudioAdmin({
    required String studioName,
    required String studioPhone,
    required String studioAddress,
    required String adminName,
    required String loginId,
    required String email,
    required String password,
  }) async {
    await _client.rpc(
      'submit_studio_signup_request',
      params: {
        'p_studio_name': studioName.trim(),
        'p_studio_phone': studioPhone.trim(),
        'p_studio_address': studioAddress.trim(),
        'p_representative_name': adminName.trim(),
        'p_requested_login_id': loginId.trim().toLowerCase(),
        'p_requested_email': email.trim().toLowerCase(),
        'p_password': password,
      },
    );
  }

  Future<void> signUpStudioAdminDirectly({
    required String studioName,
    required String studioPhone,
    required String studioAddress,
    required String adminName,
    required String loginId,
    required String email,
    required String password,
  }) async {
    await _client.rpc(
      'register_studio_admin_account',
      params: {
        'p_studio_name': studioName.trim(),
        'p_studio_phone': studioPhone.trim(),
        'p_studio_address': studioAddress.trim(),
        'p_admin_name': adminName.trim(),
        'p_login_id': loginId.trim().toLowerCase(),
        'p_email': email.trim().toLowerCase(),
        'p_password': password,
      },
    );
  }

  Future<void> signUpStudioAdminWithEmailConfirmation({
    required String studioName,
    required String studioPhone,
    required String studioAddress,
    required String adminName,
    required String loginId,
    required String email,
    required String password,
  }) async {
    await _client.rpc(
      'validate_admin_signup_request',
      params: {
        'p_studio_name': studioName.trim(),
        'p_login_id': loginId.trim().toLowerCase(),
        'p_email': email.trim().toLowerCase(),
      },
    );

    await _client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      emailRedirectTo: currentAuthRedirectUrl(),
      data: {
        'name': adminName.trim(),
        'account_type': 'admin_pending',
        'studio_name': studioName.trim(),
        'studio_phone': studioPhone.trim(),
        'studio_address': studioAddress.trim(),
        'admin_login_id': loginId.trim().toLowerCase(),
        'admin_role': 'admin',
      },
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<_AdminSignInContext?> _resolveSignInContext(String identifier) async {
    final normalized = identifier.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final response = await _client.rpc(
      'resolve_admin_sign_in_context',
      params: {'p_identifier': normalized},
    );

    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is Map<String, dynamic>) {
        return _AdminSignInContext.fromMap(first);
      }
    }
    if (response is Map<String, dynamic>) {
      return _AdminSignInContext.fromMap(response);
    }
    return null;
  }
}

class _AdminSignInContext {
  const _AdminSignInContext({
    required this.email,
    required this.signInState,
    required this.accountKind,
    required this.message,
  });

  final String? email;
  final String signInState;
  final String accountKind;
  final String? message;

  factory _AdminSignInContext.fromMap(Map<String, dynamic> map) {
    return _AdminSignInContext(
      email: map['email'] as String?,
      signInState: map['sign_in_state'] as String? ?? '',
      accountKind: map['account_kind'] as String? ?? '',
      message: map['message'] as String?,
    );
  }
}
