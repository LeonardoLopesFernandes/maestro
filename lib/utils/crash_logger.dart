import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Captura erros não tratados (build errors em release, async errors) e grava
/// um arquivo de log na pasta Download (ou no diretório externo do app, se
/// não houver permissão), para inspeção dos crashes.
class CrashLogger {
  static bool _inicializado = false;

  static Future<void> init() async {
    if (_inicializado) return;
    _inicializado = true;

    FlutterError.onError = (details) {
      _write('FlutterError', details.exception, details.stack, details.library);
    };

    // Captura erros assíncronos fora da árvore de widgets.
    PlatformDispatcher.instance.onError = (error, stack) {
      _write('IsolateError', error, stack, null);
      return true;
    };

    // Última linha de defesa para o runApp.
    runZonedGuarded<void>(() {}, (error, stack) {
      _write('ZoneError', error, stack, null);
    });
  }

  /// Constrói uma mensagem de erro amigável para exibir em tela (opcional).
  static Future<void> logError(Object error, StackTrace? stack) =>
      _write('ErrorWidget', error, stack, null);

  static Future<String> _caminhoLog() async {
    const candidatos = [
      '/storage/emulated/0/Download',
      '/sdcard/Download',
      '/storage/emulated/0/Android/data/io.maestro/files',
    ];
    for (final p in candidatos) {
      try {
        final d = Directory(p);
        if (!await d.exists()) continue;
        final teste = File('$p/.maestro_write_test');
        await teste.writeAsString('ok');
        await teste.delete();
        return p;
      } catch (_) {
        // sem permissão de escrita aqui: tenta o próximo candidato
      }
    }
    // Fallback garantido: diretório temporário do sistema.
    try {
      if (await Directory.systemTemp.exists()) return Directory.systemTemp.path;
    } catch (_) {}
    return '/data/local/tmp';
  }

  static Future<void> _write(String kind, Object? error, StackTrace? stack,
      String? library) async {
    try {
      final dirPath = await _caminhoLog();
      final dir = Directory(dirPath);
      await dir.create(recursive: true);
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final sb = StringBuffer();
      sb.writeln('==== $kind @ ${DateTime.now().toLocal()} ====');
      if (library != null) sb.writeln('library: $library');
      sb.writeln('exception: ${error.toString()}');
      sb.writeln('stack:\n${stack.toString()}');
      sb.writeln(
          '==============================================================\n');
      final arquivoPrincipal = File('$dirPath/maestro_crash.log');
      await arquivoPrincipal
          .writeAsString(sb.toString(), mode: FileMode.append);
      final arquivoData =
          File('$dirPath/maestro_crash_$ts.log');
      await arquivoData.writeAsString(sb.toString());
      // ignore: avoid_print
      print('[CRASH_LOG] ${arquivoPrincipal.path}');
    } catch (e) {
      // ignore: avoid_print
      print('[CRASH_LOG_FALHOU] $e');
    }
  }
}
