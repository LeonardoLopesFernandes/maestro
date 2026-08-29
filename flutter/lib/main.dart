import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'network/session_manager.dart';
import 'network/api_client.dart';
import 'network/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/login_webview_screen.dart';
import 'screens/home_screen.dart';
import 'screens/detalhes_pedido_screen.dart';
import 'screens/visualizar_danfe_screen.dart';
import 'screens/scanner_imei_screen.dart';
import 'screens/price_tags_screen.dart';
import 'utils/constants.dart';
import 'utils/crash_logger.dart';
import 'background/polling_worker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CrashLogger.init();
  final session = await SessionManager.create();
  final apiService = ApiService(ApiClient(session: session));
  // Polling em background (notificações de novos pedidos) — equiv. PedidoPollingWorker
  await inicializarPolling();
  // Permite notificações (Android 13+ exige permissão em runtime)
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
  runApp(MaestroApp(session: session, apiService: apiService));
}

class MaestroApp extends StatelessWidget {
  final SessionManager session;
  final ApiService apiService;

  const MaestroApp(
      {super.key, required this.session, required this.apiService});

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (details) {
      CrashLogger.init();
      Future.microtask(() => CrashLogger.logError(details.exception, details.stack));
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                const Text('Ocorreu um erro inesperado.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(details.exception.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('O log foi salvo na pasta Download (maestro_crash.log).',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    };
    return Provider<ApiService>.value(
      value: apiService,
      child: MaterialApp(
        title: 'Maestro',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('pt', 'BR'),
          Locale('en', 'US'),
        ],
        locale: const Locale('pt', 'BR'),
        theme: ThemeData(
          primaryColor: const Color(Constants.RED_600),
          colorScheme: ColorScheme.fromSwatch()
              .copyWith(primary: const Color(Constants.RED_600)),
          useMaterial3: true,
        ),
        initialRoute: _initialRoute(session),
        onGenerateRoute: (settings) {
          if (settings.name == '/auto-login') {
            final email = session.getUserEmail() ?? '';
            final senha = session.getSavedPassword() ?? '';
            return MaterialPageRoute(
              builder: (_) => LoginWebViewScreen(args: {
                'email': email,
                'senha': senha,
                'autoLogin': true,
              }),
            );
          }
          return null;
        },
        routes: {
          '/login': (_) => const LoginScreen(),
          '/webview': (_) => LoginWebViewScreen(args: {}),
          '/home': (_) => HomeScreen(session: session, apiService: apiService),
          '/etiquetas': (_) => PriceTagsScreen(
              session: session, apiService: apiService),
        },
      ),
    );
  }

  String _initialRoute(SessionManager session) {
    if (session.isLoggedIn()) return '/home';
    if (session.hasSavedCredentials()) return '/auto-login';
    return '/login';
  }
}

