import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class Formatters {
  static const _locale = 'ko_KR';
  static const _kstOffset = Duration(hours: 9);
  static final DateFormat _date = DateFormat('yyyy.MM.dd');
  static final DateFormat _yearMonth = DateFormat('yyyy년 M월', _locale);
  static final DateFormat _monthDay = DateFormat('M월 d일 (E)', _locale);
  static final DateFormat _time = DateFormat('HH:mm');
  static final DateFormat _full = DateFormat('M월 d일 (E) HH:mm', _locale);

  static DateTime kst(DateTime value) {
    if (value.isUtc) {
      return value.add(_kstOffset);
    }
    return value;
  }

  static String date(DateTime value) => _date.format(kst(value));
  static String yearMonth(DateTime value) => _yearMonth.format(kst(value));
  static String monthDay(DateTime value) => _monthDay.format(kst(value));
  static String time(DateTime value) => _time.format(kst(value));
  static String full(DateTime value) => _full.format(kst(value));

  static String phoneDigits(String? value) =>
      value == null ? '' : value.replaceAll(RegExp(r'\D'), '');

  static bool isMobilePhone(String? value) {
    final digits = phoneDigits(value);
    return digits.length == 11 && digits.startsWith('010');
  }

  static String phone(
    String? value, {
    String fallback = '핸드폰 번호 없음',
  }) {
    final digits = phoneDigits(value);
    if (digits.isEmpty) {
      return fallback;
    }
    return _formatPhoneDigits(digits);
  }

  static String editablePhone([String? value]) {
    final digits = _normalizeEditablePhoneDigits(phoneDigits(value));
    return _formatPhoneDigits(digits);
  }

  static String storagePhone(String? value) => phoneDigits(value);

  static String reservationStatus(String status) {
    switch (status) {
      case 'reserved':
        return '예약 확정';
      case 'waitlisted':
        return '대기';
      case 'cancel_requested':
        return '취소 요청 검토 중';
      case 'cancelled':
        return '취소';
      case 'completed':
        return '완료';
      case 'studio_cancelled':
        return '스튜디오 취소';
      case 'studio_rejected':
        return '스튜디오 취소 거절';
      default:
        return status;
    }
  }

  static String ledgerEntry(String entryType) {
    switch (entryType) {
      case 'planned':
        return '예정';
      case 'restored':
        return '복원';
      case 'completed':
        return '사용';
      case 'refund_adjustment':
        return '환불 조정';
      case 'manual_adjustment':
        return '수동 조정';
      default:
        return entryType;
    }
  }

  static String ledgerMemo(String memo) {
    switch (memo.trim()) {
      case 'Reservation created':
        return '예약 생성';
      case 'Member cancelled before deadline':
        return '취소 기한 내 직접 취소';
      case 'Admin approved cancel request':
        return '관리자 취소 승인';
      case 'Session completed':
        return '수강 완료';
      default:
        return memo;
    }
  }

  static String passStatus(String status) {
    switch (status) {
      case 'active':
        return '사용 가능';
      case 'exhausted':
        return '소진';
      case 'expired':
        return '만료';
      case 'refunded':
        return '환불 처리 완료';
      case 'inactive':
        return '비활성';
      default:
        return status;
    }
  }

  static String _normalizeEditablePhoneDigits(String digits) {
    if (digits.isEmpty || digits.length <= 3) {
      return '010';
    }
    var normalized = digits;
    if (!normalized.startsWith('010')) {
      final suffix = normalized.length > 3 ? normalized.substring(3) : '';
      normalized = '010$suffix';
    }
    if (normalized.length > 11) {
      normalized = normalized.substring(0, 11);
    }
    return normalized;
  }

  static String _formatPhoneDigits(String digits) {
    final trimmed = digits.length > 11 ? digits.substring(0, 11) : digits;
    if (trimmed.length <= 3) {
      return trimmed;
    }
    if (trimmed.length <= 7) {
      return '${trimmed.substring(0, 3)}-${trimmed.substring(3)}';
    }
    return '${trimmed.substring(0, 3)}-${trimmed.substring(3, 7)}-${trimmed.substring(7)}';
  }
}

class KoreanMobilePhoneTextInputFormatter extends TextInputFormatter {
  const KoreanMobilePhoneTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = Formatters.editablePhone(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
