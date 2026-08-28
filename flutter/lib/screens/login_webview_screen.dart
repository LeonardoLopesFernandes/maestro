import 'dart:async';
import 'dart:convert';
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
    final token = _extrairToken(url);
    if (token != null) {
      _salvarToken(token);
      return;
    }
    // URL de retorno do OAuth (maestro-auth.../ad/reply?code=...) pode entregar o
    // token em cookie/query na próxima navegação; o polling cuida disso.
    if (url.startsWith(Constants.redirectUri)) {
      _capturarToken().then((t) {
        if (t != null) _salvarToken(t);
      });
    }
  }

  // Espelha extrairTokenDaUrl/extrairTokenDosCookies do Kotlin LoginWebViewActivity.
  String? _extrairToken(String texto) {
    if (texto.isEmpty) return null;
    const patterns = [
      'token=',
      'newToken=',
      'bearer=',
      'access_token=',
      'id_token=',
      'auth_token=',
      'jwt='
    ];
    for (final p in patterns) {
      final idx = texto.indexOf(p);
      if (idx != -1) {
        var valor = texto.substring(idx + p.length);
        final fim = valor.indexOf(RegExp(r'[&\s;]'));

        if (fim != -1) valor = valor.substring(0, fim);
        if (valor.isNotEmpty && valor.length > 50) return valor;
      }
    }
    return null;
  }

  Future<String?> _capturarToken() async {
    if (_tokenCapturado) return null;
    try {
      const script = "(function(){"
          "function extrair(s){"
          "if(!s) return null;"
          "var keys=['token=','newToken=','bearer=','access_token=','id_token=','auth_token=','jwt='];"
          "for(var i=0;i<keys.length;i++){var p=keys[i];var idx=s.indexOf(p);"
          "if(idx>=0){var v=s.substring(idx+p.length);var m=v.match(/^[^&\"'_\\\\s]+/);"
          "if(m&&m[0].length>50) return m[0];}}"
          "var lk=['newToken','token','bearer','access_token','id_token','auth_token','jwt','session_token'];"
          "for(var i=0;i<lk.length;i++){var v=localStorage.getItem(lk[i])||sessionStorage.getItem(lk[i]);"
          "if(v&&v.length>50) return v;}"
          "for(var i=0;i<lk.length;i++){if(window[lk[i]]&&window[lk[i]].length>50) return window[lk[i]];}"
          "return null;"
          "}"
          "var cookies=document.cookie||'';"
          "var loc=location.href||'';"
          "return extrair(loc)||extrair(cookies);"
          "})();";
      final result = await _controller.runJavaScriptReturningResult(script);
      String? token;
      if (result is String) token = result.replaceAll('"', '').trim();
      if (token != null && token.isNotEmpty && token.length > 50) {
        return token;
      }
    } catch (e) {
      LogHelper.e("capturarToken", e);
    }
    return null;
  }

  String? _extrairClaim(String token, String claim) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1];
      payload = payload.padRight(payload.length + (4 - payload.length % 4) % 4, '=');
      final json = jsonDecode(utf8.decode(base64Url.decode(payload)));
      if (json is Map) {
        for (final c in ['email', 'upn', 'preferred_username', 'unique_name', claim]) {
          final v = json[c];
          if (v != null && v.toString().isNotEmpty) return v.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  void _salvarToken(String token) {
    if (_loginConcluido) return;
    _loginConcluido = true;
    _tokenCapturado = true;
    _pollTimer?.cancel();
    if (mounted) setState(() => _carregando = true);
    _session.saveToken(token);
    final email = _extrairClaim(token, 'email') ??
        widget.args?['email'] ??
        "usuario@americanas.io";
    final nome = _extrairClaim(token, 'nome') ??
        _extrairClaim(token, 'name') ??
        email.split('@').first;
    _session.saveUserInfo(
        email, nome, _session.getUserStore() ?? Constants.defaultStore);
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
