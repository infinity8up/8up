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
      return error.message;
    }
    return error.toString();
  }
}
