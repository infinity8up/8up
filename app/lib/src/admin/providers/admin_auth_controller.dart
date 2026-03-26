import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_text.dart';
import '../repositories/admin_auth_repository.dart';

class AdminAuthController extends ChangeNotifier {
  AdminAuthController(this._repository) {
    _session = _repository.currentSession;
    _subscription = _repository.authStateChanges.listen((state) {
      _lastEvent = state.event;
      _session = state.session;
      notifyListeners();
    });
  }

  final AdminAuthRepository _repository;
  StreamSubscription<AuthState>? _subscription;

  Session? _session;
  AuthChangeEvent? _lastEvent;
  bool _busy = false;
  String? _error;

  Session? get session => _session;
  String? get userId => _session?.user.id;
  bool get isAuthenticated => _session != null;
  bool get isPasswordRecovery => _lastEvent == AuthChangeEvent.passwordRecovery;
  bool get isBusy => _busy;
  String? get error => _error;

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    await _run(
      () => _repository.signIn(identifier: identifier, password: password),
    );
  }

  Future<void> signOut() async {
    await _run(_repository.signOut);
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
    await _run(
      () => _repository.signUpStudioAdmin(
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

  Future<void> updatePassword({required String password}) async {
    await _run(() => _repository.updatePassword(password));
  }

  void clearRecoveryMode() {
    if (!isPasswordRecovery) {
      return;
    }
    _lastEvent = AuthChangeEvent.signedIn;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) {
      return;
    }
    _error = null;
    notifyListeners();
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      _error = ErrorText.format(error);
      notifyListeners();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
