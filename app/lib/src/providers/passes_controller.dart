import 'package:flutter/foundation.dart';

import '../core/error_text.dart';
import '../models/pass_models.dart';
import '../repositories/pass_repository.dart';

class PassesController extends ChangeNotifier {
  PassesController(this._repository);

  final PassRepository _repository;

  List<UserPassSummary> _passes = const [];
  String? _studioId;
  bool _loading = false;
  String? _error;

  List<UserPassSummary> get passes => _passes;
  bool get isLoading => _loading;
  String? get error => _error;

  void bindStudio(String? studioId) {
    if (_studioId == studioId) {
      return;
    }

    _studioId = studioId;
    if (studioId == null) {
      _passes = const [];
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
      final fetched = await _repository.fetchPasses(studioId);
      fetched.sort((left, right) {
        if (left.isExpired != right.isExpired) {
          return left.isExpired ? 1 : -1;
        }
        return left.validUntil.compareTo(right.validUntil);
      });
      _passes = fetched;
    } catch (error) {
      _error = ErrorText.format(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<UserPassSummary> eligiblePassesForTemplate(
    String templateId, {
    DateTime? onDate,
  }) {
    final targetDate = onDate ?? DateTime.now();
    return _passes
        .where((pass) {
          return pass.hasRemaining &&
              pass.allowedTemplateIds.contains(templateId) &&
              !pass.validFrom.isAfter(targetDate) &&
              !pass.validUntil.isBefore(targetDate) &&
              !pass.isHeldOn(targetDate);
        })
        .toList(growable: false);
  }

  UserPassSummary? defaultPassForTemplate(
    String templateId,
    DateTime sessionDay,
  ) {
    final eligible =
        _passes
            .where((pass) {
              final inDateRange =
                  !pass.validFrom.isAfter(sessionDay) &&
                  !pass.validUntil.isBefore(sessionDay);
              return pass.hasRemaining &&
                  inDateRange &&
                  pass.allowedTemplateIds.contains(templateId) &&
                  !pass.isHeldOn(sessionDay);
            })
            .toList(growable: false)
          ..sort((left, right) => left.validUntil.compareTo(right.validUntil));

    return eligible.isEmpty ? null : eligible.first;
  }
}
