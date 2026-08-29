import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart' show Color;
import 'package:workmanager/workmanager.dart';
import '../network/api_client.dart';
import '../network/api_service.dart';
import '../network/session_manager.dart';

const String kPollingTask = 'maestroPedidoPolling';
const String kChannelId = 'maestro_pedidos';

// Equivalente ao PedidoPollingWorker do Kotlin: dispara em background (mesmo
// com o app fechado) e emite notificação quando há novos pedidos aguardando.
@pragma('vm:entry-point')
void pollingCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == kPollingTask) {
      await _verificarPedidos();
    }
    return Future.value(true);
  });
}

Future<void> _verificarPedidos() async {
  try {
    final session = await SessionManager.create();
    if (!session.isLoggedIn()) return;
    final api = ApiService(ApiClient(session: session));
    final store = session.getUserStore() ?? 'L291';
    final counts = await api.getCounts(store);
    final total = counts.novoPedido +
        counts.emSeparacao +
        counts.prontoParaSair +
        counts.saiuParaEntrega;
    final last = session.getLastPollingCount();
    if (total > last) {
      await _notificar(counts);
    }
    session.saveLastPollingCount(total);
  } catch (_) {
    // silencioso: o próximo ciclo tenta novamente
  }
}

Future<void> _notificar(dynamic counts) async {
  final plugin = FlutterLocalNotificationsPlugin();
    const android = AndroidNotificationDetails(
      'pedidos_channel',
      'Novos pedidos',
      channelDescription: 'Avisa quando há novos pedidos',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      icon: 'ic_maestro_notification',
      color: Color(0xFFF80032),
    );
  const details = NotificationDetails(android: android);
  final corpo =
      '${counts.novoPedido} novo(s), ${counts.emSeparacao} em separação, '
      '${counts.prontoParaSair} pronto(s)';
  await plugin.show(
    1,
    'Maestro — pedidos aguardando',
    corpo,
    details,
  );
}

// Registra a tarefa periódica (15 min). Deve ser chamado uma vez na inicialização.
Future<void> inicializarPolling() async {
  await Workmanager().initialize(pollingCallbackDispatcher);
  final session = await SessionManager.create();
  if (session.isLoggedIn()) {
    await Workmanager().registerPeriodicTask(
      kPollingTask,
      kPollingTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }
}
