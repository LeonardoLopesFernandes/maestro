import 'package:flutter/foundation.dart';

class LogHelper {
  static const String _tag = "RecebimentoApp";

  static void d(String message) {
    if (kDebugMode) debugPrint("$_tag D: $message");
  }

  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint("$_tag E: $message");
      if (error != null) debugPrint(error.toString());
    }
  }

  static void i(String message) {
    if (kDebugMode) debugPrint("$_tag I: $message");
  }

  static void w(String message) {
    if (kDebugMode) debugPrint("$_tag W: $message");
  }
}
