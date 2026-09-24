import 'package:flutter/foundation.dart';

class LogHelper {
  static const String _tag = "MaestroApp";

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

  /// Verdadeiro quando o erro é de conectividade/rede (host lookup, socket,
  /// timeout), que costuma ocorrer ao voltar do segundo plano sem internet.
  /// Nesses casos não devemos incomodar o usuário com toasts.
  static bool ehErroDeRede(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('sockexception') ||
        s.contains('hostlookup') ||
        s.contains('failed hostlookup') ||
        s.contains('connection refused') ||
        s.contains('connection closed') ||
        s.contains('timed out') ||
        s.contains('timeout') ||
        s.contains('clientexception');
  }
}
