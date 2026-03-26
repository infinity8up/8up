import 'package:flutter/foundation.dart';

import '../core/error_text.dart';
import '../core/reservation_bucket_rules.dart';
import '../models/class_models.dart';
import '../repositories/reservation_repository.dart';

enum ReservationBucket { upcoming, waitlist, completed, cancelled }

class ReservationsController extends ChangeNotifier {
  ReservationsController(this._repository);

  final ReservationRepository _repository;

  List<ReservationItem> _reservations = const [];
  String? _studioId;
  bool _loading = false;
  String? _error;

  List<ReservationItem> get reservations => _reservations;
  bool get isLoading => _loading;
  String? get error => _error;

  void bindStudio(String? studioId) {
    if (_studioId == studioId) {
      return;
    }

    _studioId = studioId;
    if (studioId == null) {
      _reservations = const [];
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
      _reservations = await _repository.fetchReservations(studioId);
    } catch (error) {
      _error = ErrorText.format(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<DateTime> availableMonths({String? userPassId}) {
    final months = <DateTime>[];
    final seenKeys = <String>{};

    for (final reservation in _reservations) {
      if (userPassId != null && reservation.userPassId != userPassId) {
        continue;
      }
      final month = DateTime(
        reservation.startAt.year,
        reservation.startAt.month,
      );
      final key = '${month.year}-${month.month}';
      if (seenKeys.add(key)) {
        months.add(month);
      }
    }

    months.sort((left, right) => right.compareTo(left));
    return months;
  }

  List<ReservationItem> itemsForBucket(
    ReservationBucket bucket, {
    String? userPassId,
    DateTime? month,
  }) {
    final now = DateTime.now();
    final filtered = _reservations
        .where((reservation) {
          if (userPassId != null && reservation.userPassId != userPassId) {
            return false;
          }
          if (month != null &&
              (reservation.startAt.year != month.year ||
                  reservation.startAt.month != month.month)) {
            return false;
          }
          switch (bucket) {
            case ReservationBucket.upcoming:
              return isReservationUpcomingStatus(
                reservation.status,
                reservation.startAt,
                now,
              );
            case ReservationBucket.waitlist:
              return isReservationWaitlistedStatus(reservation.status);
            case ReservationBucket.completed:
              return isReservationCompletedStatus(
                reservation.status,
                reservation.startAt,
                now,
              );
            case ReservationBucket.cancelled:
              return isReservationCancelledStatus(
                reservation.status,
                approvedCancelAt: reservation.approvedCancelAt,
              );
          }
        })
        .toList(growable: false);

    filtered.sort((left, right) {
      if (bucket == ReservationBucket.completed ||
          bucket == ReservationBucket.cancelled) {
        return right.startAt.compareTo(left.startAt);
      }
      return left.startAt.compareTo(right.startAt);
    });

    return filtered;
  }
}
