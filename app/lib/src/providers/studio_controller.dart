import 'package:flutter/foundation.dart';

import '../core/error_text.dart';
import '../models/content_item.dart';
import '../repositories/studio_repository.dart';

class StudioController extends ChangeNotifier {
  StudioController(this._repository);

  final StudioRepository _repository;

  StudioFeed _feed = const StudioFeed(notices: [], events: []);
  String? _studioId;
  bool _loading = false;
  String? _error;

  StudioFeed get feed => _feed;
  bool get isLoading => _loading;
  String? get error => _error;

  void bindStudio(String? studioId) {
    if (_studioId == studioId) {
      return;
    }

    _studioId = studioId;
    if (studioId == null) {
      _feed = const StudioFeed(notices: [], events: []);
      _error = null;
      _loading = false;
      notifyListeners();
      return;
    }

    Future<void>.microtask(refresh);
  }

  Future<void> refresh() async {
    final studioId = _studioId;
    if (studioId == null) {
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _feed = await _repository.fetchStudioFeed(studioId);
    } catch (error) {
      _error = ErrorText.format(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
