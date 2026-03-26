import 'package:flutter/foundation.dart';

import '../../core/error_text.dart';
import '../models/admin_models.dart';
import '../repositories/admin_repository.dart';
import 'admin_auth_controller.dart';

class AdminSessionController extends ChangeNotifier {
  AdminSessionController(this._repository);

  final AdminRepository _repository;

  AdminProfile? _profile;
  PlatformAdminProfile? _platformProfile;
  String? _boundUserId;
  bool _loading = false;
  String? _error;

  AdminProfile? get profile => _profile;
  PlatformAdminProfile? get platformProfile => _platformProfile;
  bool get isPlatformAdmin => _platformProfile != null;
  bool get isLoading => _loading;
  String? get error => _error;

  void bindAuth(AdminAuthController auth) {
    if (!auth.isAuthenticated) {
      _boundUserId = null;
      _profile = null;
      _platformProfile = null;
      _loading = false;
      _error = null;
      notifyListeners();
      return;
    }

    if (_boundUserId == auth.userId) {
      return;
    }

    _boundUserId = auth.userId;
    Future<void>.microtask(refresh);
  }

  Future<void> refresh() async {
    if (_boundUserId == null) {
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _platformProfile = await _repository
          .fetchCurrentPlatformAdminProfileOrNull();
      if (_platformProfile != null) {
        _profile = null;
        return;
      }

      _profile = await _repository.fetchCurrentAdminProfileOrNull();
      _platformProfile = null;
    } catch (error) {
      _error = ErrorText.format(error);
      _profile = null;
      _platformProfile = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
