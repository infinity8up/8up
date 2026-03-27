import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorText {
  static String format(Object error) {
    if (error is AuthException) {
      return error.message;
    }
    if (error is PostgrestException) {
      if (error.message.contains('reservations_unique_user_session') ||
          error.message.contains('Reservation already exists for this session')) {
        return '이미 이 수업에 대한 예약 이력이 있습니다.';
      }
      if (error.message.contains('예약 내역이 있는 수업은 삭제할 수 없습니다')) {
        return '예약 내역이 있거나, 예약 취소 내역이 있는 수업은 삭제가 불가합니다.';
      }
      return error.message;
    }
    if (error is StateError &&
        error.message.contains('예약 내역이 있는 수업은 삭제할 수 없습니다')) {
      return '예약 내역이 있거나, 예약 취소 내역이 있는 수업은 삭제가 불가합니다.';
    }
    return error.toString();
  }
}
