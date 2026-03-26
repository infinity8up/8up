import 'package:flutter/foundation.dart';

import '../core/error_text.dart';
import '../models/class_models.dart';
import '../models/pass_models.dart';
import '../repositories/session_repository.dart';

class CalendarController extends ChangeNotifier {
  CalendarController(this._repository);

  final SessionRepository _repository;

  List<ClassSessionItem> _sessions = const [];
  String? _studioId;
  bool _loading = false;
  String? _error;

  List<ClassSessionItem> get sessions => _sessions;
  bool get isLoading => _loading;
  String? get error => _error;

  DateTime get rangeStart {
    final now = DateTime.now();
    return _startOfWeek(now).subtract(const Duration(days: 84));
  }

  DateTime get rangeEnd {
    final now = DateTime.now();
    return _endOfWeek(DateTime(now.year, now.month + 2, 0));
  }

  void bindStudio(String? studioId) {
    if (_studioId == studioId) {
      return;
    }

    _studioId = studioId;
    if (studioId == null) {
      _sessions = const [];
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
      _sessions = await _repository.fetchSessions(
        studioId: studioId,
        startDate: rangeStart,
        endDate: rangeEnd,
      );
    } catch (error) {
      _error = ErrorText.format(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<ClassSessionItem> sessionsForDay(
    DateTime day,
    List<UserPassSummary> passes,
  ) {
    final dayKey = DateTime(day.year, day.month, day.day);
    final sessions = _sessions
        .where((session) {
          final sessionKey = DateTime(
            session.sessionDate.year,
            session.sessionDate.month,
            session.sessionDate.day,
          );
          return sessionKey == dayKey && _isVisible(session, passes);
        })
        .toList(growable: false);
    sessions.sort((left, right) => left.startAt.compareTo(right.startAt));
    return sessions;
  }

  bool _isVisible(ClassSessionItem session, List<UserPassSummary> passes) {
    if (session.myReservationStatus != null) {
      return true;
    }

    if (session.status != 'scheduled' && session.status != 'completed') {
      return false;
    }

    return passes.any((pass) {
      final inDateRange =
          !pass.validFrom.isAfter(session.sessionDate) &&
          !pass.validUntil.isBefore(session.sessionDate);
      if (!inDateRange ||
          !pass.allowedTemplateIds.contains(session.classTemplateId) ||
          pass.isHeldOn(session.sessionDate)) {
        return false;
      }

      if (session.startAt.isAfter(DateTime.now())) {
        return pass.hasRemaining;
      }

      return true;
    });
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final daysFromSunday = normalized.weekday % DateTime.daysPerWeek;
    return normalized.subtract(Duration(days: daysFromSunday));
  }

  DateTime _endOfWeek(DateTime date) {
    return _startOfWeek(date).add(const Duration(days: 6));
  }
}
