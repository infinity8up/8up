import 'package:flutter/foundation.dart';

const String kEightUpAuthCallbackUrl = 'eightup://login-callback/';

String currentAuthRedirectUrl() {
  if (kIsWeb) {
    return Uri.base.replace(query: '', fragment: '').toString();
  }
  return kEightUpAuthCallbackUrl;
}
