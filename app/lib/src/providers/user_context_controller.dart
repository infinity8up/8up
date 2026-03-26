import 'package:flutter/foundation.dart';

import '../core/error_text.dart';
import '../models/studio.dart';
import '../models/user_profile.dart';
import '../repositories/app_settings_repository.dart';
import '../repositories/studio_repository.dart';
import '../repositories/profile_repository.dart';
import 'auth_controller.dart';

class UserContextController extends ChangeNotifier {
  UserContextController(
    this._profileRepository,
    this._studioRepository,
    this._settingsRepository,
  );

  final ProfileRepository _profileRepository;
  final StudioRepository _studioRepository;
  final AppSettingsRepository _settingsRepository;

  UserProfile? _profile;
  List<StudioMembership> _memberships = const [];
  String? _selectedStudioId;
  String? _currentUserId;
  bool _loading = false;
  bool _requiresSignOut = false;
  String? _error;

  UserProfile? get profile => _profile;
  List<StudioMembership> get memberships => _memberships;
  List<StudioMembership> get activeMemberships => _memberships
      .where((membership) => membership.isActive)
      .toList(growable: false);
  String? get selectedStudioId => _selectedStudioId;
  bool get isLoading => _loading;
  bool get requiresSignOut => _requiresSignOut;
  String? get error => _error;
  bool get hasMemberships => _memberships.isNotEmpty;

  StudioMembership? get selectedMembership {
    final studioId = _selectedStudioId;
    if (studioId == null) {
      return null;
    }
    for (final membership in _memberships) {
      if (membership.studioId == studioId) {
        return membership;
      }
    }
    return null;
  }

  void bindAuth(AuthController authController) {
    final nextUserId = authController.userId;
    if (nextUserId == _currentUserId) {
      return;
    }

    _currentUserId = nextUserId;
    if (nextUserId == null) {
      _profile = null;
      _memberships = const [];
      _selectedStudioId = null;
      _error = null;
      _loading = false;
      _requiresSignOut = false;
      notifyListeners();
      return;
    }

    Future<void>.microtask(refresh);
  }

  Future<void> refresh() async {
    if (_currentUserId == null) {
      return;
    }

    _loading = true;
    _error = null;
    _requiresSignOut = false;
    notifyListeners();

    try {
      final profile = await _profileRepository.fetchCurrentUserProfile();
      if (profile == null) {
        _profile = null;
        _memberships = const [];
        _selectedStudioId = null;
        _requiresSignOut = true;
        _error = '회원 계정을 찾을 수 없습니다. 다시 로그인해 주세요.';
        return;
      }
      final memberships = await _studioRepository.fetchMemberships();

      _profile = profile;
      _memberships = memberships;

      final activeMemberships = memberships
          .where((membership) {
            return membership.isActive;
          })
          .toList(growable: false);
      final userId = _currentUserId!;
      final savedStudioId = await _settingsRepository.getSelectedStudioId(
        userId,
      );
      final candidateStudioId =
          activeMemberships.any(
            (membership) => membership.studioId == savedStudioId,
          )
          ? savedStudioId
          : activeMemberships.any(
              (membership) => membership.studioId == _selectedStudioId,
            )
          ? _selectedStudioId
          : activeMemberships.isEmpty
          ? null
          : activeMemberships.first.studioId;

      _selectedStudioId = candidateStudioId;

      if (candidateStudioId == null) {
        await _settingsRepository.clearSelectedStudioId(userId);
      } else if (candidateStudioId != savedStudioId) {
        await _settingsRepository.setSelectedStudioId(
          userId,
          candidateStudioId,
        );
      }
    } catch (error) {
      _error = ErrorText.format(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> selectStudio(String studioId) async {
    final canSelect = _memberships.any((membership) {
      return membership.studioId == studioId && membership.isActive;
    });
    if (!canSelect) {
      return false;
    }
    if (_selectedStudioId == studioId) {
      return false;
    }
    _selectedStudioId = studioId;
    final userId = _currentUserId;
    if (userId != null) {
      await _settingsRepository.setSelectedStudioId(userId, studioId);
    }
    notifyListeners();
    return true;
  }

  Future<void> updateMembershipStatus({
    required String membershipId,
    required String status,
  }) async {
    await _studioRepository.updateOwnMembershipStatus(
      membershipId: membershipId,
      status: status,
    );
    await refresh();
  }
}
