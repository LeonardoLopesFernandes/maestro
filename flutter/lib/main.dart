import 'package:flutter/material.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await SessionManager.create();
  final apiService = ApiService(ApiClient(session: session));
  runApp(MaestroApp(session: session, apiService: apiService));
}

class MaestroApp extends StatelessWidget {
  final SessionManager session;
  final ApiService apiService;

  const MaestroApp(
      {super.key, required this.session, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return Provider<ApiService>.value(
      value: apiService,
      child: MaterialApp(
        title: 'Maestro',
        debugShowCheckedModeBanner: false,
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

