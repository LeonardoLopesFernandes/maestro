import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart' show Color;
import 'package:workmanager/workmanager.dart';
import '../network/api_client.dart';
import '../network/api_service.dart';
import '../network/session_manager.dart';

const String kPollingTask = 'maestroPedidoPolling';
const String kChannelId = 'maestro_pedidos';
const String kChannelName = 'Novos pedidos';
const String kChannelDescription = 'Avisa quando há novos pedidos';
bool _notificacoesIniciadas = false;

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
  await inicializarNotificacoes();
  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidNotificationDetails(
    kChannelId,
    kChannelName,
    channelDescription: kChannelDescription,
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

// Inicializa o plugin e cria o canal. Precisa rodar também no isolate do
// Workmanager, pois a notificação é emitida em segundo plano.
Future<void> inicializarNotificacoes() async {
  if (_notificacoesIniciadas) return;
  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('ic_maestro_notification');
  const ios = DarwinInitializationSettings();
  await plugin.initialize(const InitializationSettings(android: android, iOS: ios));
  final androidPlugin = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
    kChannelId,
    kChannelName,
    description: kChannelDescription,
    importance: Importance.max,
    playSound: true,
  ));
  _notificacoesIniciadas = true;
}

// Registra a tarefa periódica (15 min). Deve ser chamado uma vez na inicialização.
Future<void> inicializarPolling() async {
  await inicializarNotificacoes();
  await Workmanager().initialize(pollingCallbackDispatcher);
  await agendarPollingSeLogado();
}

// Chamado também após o login: antes, quem logava na primeira execução só
// tinha o worker agendado no próximo início do app.
Future<void> agendarPollingSeLogado() async {
  final session = await SessionManager.create();
  if (!session.isLoggedIn()) return;
  await Workmanager().registerPeriodicTask(
    kPollingTask,
    kPollingTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
  );
}
