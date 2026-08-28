import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../network/session_manager.dart';
import '../network/api_client.dart';
import '../network/api_service.dart';
import '../utils/constants.dart';
import '../utils/log_helper.dart';

class LoginWebViewScreen extends StatefulWidget {
  final Map<String, dynamic>? args;

  const LoginWebViewScreen({super.key, this.args});

  @override
  State<LoginWebViewScreen> createState() => _LoginWebViewScreenState();
}

class _LoginWebViewScreenState extends State<LoginWebViewScreen> {
  late final WebViewController _controller;
  late final SessionManager _session;
  late final ApiService _apiService;

  bool _loginConcluido = false;
  bool _carregando = true;
  bool _pronto = false;
  bool _tokenCapturado = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    _session = await SessionManager.create();
    _apiService = ApiService(ApiClient(session: _session));
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (url != null) _verificarUrl(url);
          },
          onPageFinished: (url) async {
            if (!_loginConcluido) {
              final token = await _capturarToken();
              if (token != null) _salvarToken(token);
            }
            if (!_loginConcluido && mounted) {
              setState(() => _carregando = false);
            }
            if (url != null) _verificarUrl(url);
          },
          onNavigationRequest: (request) {
            _verificarUrl(request.url);
            return NavigationDecision.navigate;
          },
        ),
      );

    await _controller.loadRequest(Uri.parse(Constants.msLoginUrl));
    _pronto = true;
    if (mounted) setState(() {});

    // Polling de segurança: a página de resposta pode setar o token via
    // JavaScript sem trocar a URL (igual ao JavascriptInterface do Kotlin).
    _pollTimer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      if (_loginConcluido) return;
      final token = await _capturarToken();
      if (token != null) _salvarToken(token);
    });
  }

  void _verificarUrl(String url) {
    if (_loginConcluido) return;
    if (url.startsWith(Constants.redirectUri)) {
      _capturarToken().then((token) {
        if (token != null) _salvarToken(token);
      });
    }
  }

  Future<String?> _capturarToken() async {
    if (_tokenCapturado) return null;
    try {
      const script = "(function(){"
          "function c(){return document.cookie;}"
          "var l=localStorage.getItem('token')||localStorage.getItem('newToken')||"
          "localStorage.getItem('access_token')||"
          "sessionStorage.getItem('token')||sessionStorage.getItem('newToken');"
          "if(l)return l;"
          "var m=document.cookie.match(/(?:^|;\\s*)(?:token|newToken|access_token)=([^;]+)/);"
          "if(m)return m[1];"
          "return '';"
          "})();";
      final result = await _controller.runJavaScriptReturningResult(script);
      String? token;
      if (result is String) token = result.replaceAll('"', '').trim();
      if (token != null && token.isNotEmpty && token.length > 30) {
        return token;
      }
    } catch (e) {
      LogHelper.e("capturarToken", e);
    }
    return null;
  }

  void _salvarToken(String token) {
    if (_loginConcluido) return;
    _loginConcluido = true;
    _tokenCapturado = true;
    _pollTimer?.cancel();
    if (mounted) setState(() => _carregando = true);
    _session.saveToken(token);
    final email = widget.args?['email'] ?? "usuario@americanas.io";
    _session.saveUserInfo(email, "Usuário",
        _session.getUserStore() ?? Constants.defaultStore);
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_loginConcluido) return false;
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE60000),
        body: Stack(
          children: [
            if (_pronto)
              WebViewWidget(controller: _controller)
            else
              const SizedBox.shrink(),
            if (_carregando) const _CarregamentoWidget(),
          ],
        ),
      ),
    );
  }
}

class _CarregamentoWidget extends StatelessWidget {
  const _CarregamentoWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE60000),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 24),
            Text('Autenticando...',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
