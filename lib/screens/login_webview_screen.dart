import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _autoLogin = false;
  String _email = '';
  String _senha = '';
  Timer? _pollTimer;
  bool _promptInjetado = false;

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    _session = await SessionManager.create();
    _apiService = ApiService(ApiClient(session: _session));
    final args = widget.args ?? {};
    _autoLogin = args['autoLogin'] == true;
    _email = (args['email'] ?? '').toString();
    _senha = (args['senha'] ?? '').toString();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (url != null) {
              _verificarUrl(url);
              _garantirSelectAccount(url);
            }
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
            // Auto-login: preenche e submete o formulário Microsoft quando
            // as credenciais salvas estiverem disponíveis.
            if (_autoLogin &&
                url != null &&
                url.contains('login.microsoftonline.com')) {
              _preencherLoginAutomatico();
            }
          },
          onNavigationRequest: (request) {
            _verificarUrl(request.url);
            if (_garantirSelectAccount(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    await _controller.loadRequest(Uri.parse(Constants.msLoginUrl));
    _pronto = true;
    if (mounted) setState(() {});

    // Polling de segurança: a página de resposta pode setar o token via
    // JavaScript sem trocar a URL (igual ao JavascriptInterface do Kotlin).
    _pollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      if (_loginConcluido) return;
      final token = await _capturarToken();
      if (token != null) _salvarToken(token);
    });
  }

  // Força a tela "Escolher uma conta" do Microsoft: intercepta a URL de
  // autorização e injeta prompt=select_account, para o usuário clicar na
  // conta salva desejada ao trocar de conta. Retorna true se recarregou a URL.
  bool _garantirSelectAccount(String url) {
    if (_loginConcluido || _promptInjetado) return false;
    if (!url.contains('login.microsoftonline.com')) return false;
    if (url.contains('prompt=')) return false;
    _promptInjetado = true;
    final sep = url.contains('?') ? '&' : '?';
    final nova = url + sep + 'prompt=select_account';
    _controller.loadRequest(Uri.parse(nova));
    return true;
  }

  // Espelha preencherLoginAutomatico/montarScriptPreenchimento do Kotlin.
  void _preencherLoginAutomatico() {
    if (_loginConcluido || !_autoLogin) return;
    if (_email.isEmpty || _senha.isEmpty) return;
    final emailJs = _jsString(_email);
    final senhaJs = _jsString(_senha);
    const script = "(function(){"
        "function setV(el,v){try{var d=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value');if(d&&d.set)d.set.call(el,v);else el.value=v;el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}));}catch(e){}}"
        "var btn=document.getElementById('idSIButton9');"
        "var em=document.getElementById('i0116');"
        "if(em){setV(em,\$EMAIL\$);if(btn){btn.click();return 'email';}return 'email-no-btn';}"
        "var pw=document.getElementById('i0118');"
        "if(pw){setV(pw,\$SENHA\$);if(btn){btn.click();return 'pwd';}return 'pwd-no-btn';}"
        "var km=document.getElementById('KmsiCheckboxField');"
        "if(km){if(btn){btn.click();return 'kmsi';}return 'kmsi-no-btn';}"
        "return 'none';"
        "})();";
    final js = script
        .replaceAll('\$EMAIL\$', emailJs)
        .replaceAll('\$SENHA\$', senhaJs);
    _controller.runJavaScript(js);
  }

  String _jsString(String v) {
    return "'${v.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";
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
      // 1) JS no WebView (localStorage/sessionStorage/window/cookies visíveis)
      const script = "(function(){"
          "function extrair(s){"
          "if(!s) return null;"
          "var keys=['token=','newToken=','bearer=','access_token=','id_token=','auth_token=','jwt='];"
          "for(var i=0;i<keys.length;i++){var p=keys[i];var idx=s.indexOf(p);"
          "if(idx>=0){var v=s.substring(idx+p.length);var m=v.match(/^[^&\"'_\\\\s]+/);"
          "if(m&&m[0].length>50) return m[0];}}"
          "var lk=['newToken','rc-newToken','rcNewToken','token','bearer','access_token','id_token','auth_token','jwt','session_token','maestroToken','authToken'];"
          "for(var i=0;i<lk.length;i++){var v=localStorage.getItem(lk[i])||sessionStorage.getItem(lk[i]);"
          "if(v&&v.length>50) return v;}"
          "for(var i=0;i<lk.length;i++){if(window[lk[i]]&&window[lk[i]].length>50) return window[lk[i]];}"
          "return null;"
          "}"
          "function buscar(storage){"
          "for(var i=0;i<storage.length;i++){"
          "try{var k=storage.key(i);var v=storage.getItem(k);"
          "if(v&&v.length>50&&(v.indexOf('.')>=0||v.indexOf('eyJ')===0)){return v;}"
          "}catch(e){}"
          "}"
          "return null;"
          "}"
          "var cookies=document.cookie||'';"
          "var loc=location.href||'';"
          "return extrair(loc)||extrair(cookies)||buscar(localStorage)||buscar(sessionStorage);"
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

    // 2) Cookies nativos (inclui HttpOnly, que o JS não lê) — espelha o
    // extrairTokenDosCookies do Kotlin (CookieManager).
    try {
      const channel = MethodChannel('io.maestro/cookies');
      final cookies = await channel.invokeMethod<String>('getCookies', {
        'url': 'https://maestro.americanas.io',
      });
      if (cookies != null && cookies.isNotEmpty) {
        final t = _extrairToken(cookies);
        if (t != null) return t;
      }
    } catch (e) {
      LogHelper.e("capturarToken cookies", e);
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

  Map<String, dynamic>? _decodificarClaims(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      var p = parts[1];
      p = p.padRight(p.length + (4 - p.length % 4) % 4, '=');
      final j = jsonDecode(utf8.decode(base64Url.decode(p)));
      return j is Map ? Map<String, dynamic>.from(j) : null;
    } catch (_) {
      return null;
    }
  }

  String _capitalizar(String s) => s
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  String _nomeDosClaims(Map<String, dynamic>? c, String email) {
    if (c != null) {
      for (final k in ['nome', 'name', 'display_name', 'displayName']) {
        final v = c[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      final g = c['given_name']?.toString();
      final f = c['family_name']?.toString();
      if (g != null && g.isNotEmpty) {
        return [g, if (f != null && f.isNotEmpty) f].join(' ');
      }
      final un = c['unique_name']?.toString();
      if (un != null && un.isNotEmpty && !un.contains('@')) {
        return _capitalizar(un.replaceAll(RegExp(r'[._-]'), ' '));
      }
    }
    final local = email.split('@').first;
    return _capitalizar(local.replaceAll(RegExp(r'[._-]'), ' '));
  }

  Future<void> _salvarToken(String token) async {
    if (_loginConcluido) return;
    _loginConcluido = true;
    _tokenCapturado = true;
    _pollTimer?.cancel();
    if (mounted) setState(() => _carregando = true);
    try {
      final claims = _decodificarClaims(token);
      await _session.saveToken(token,
          expiryEpochSeconds: claims?['exp'] is int ? claims!['exp'] as int : null);
      // Suporta JWT com claims aninhados em "user" (minhaloja/trocafacil)
      // e flat (Microsoft OAuth padrão).
      final user = claims?['user'] is Map
          ? Map<String, dynamic>.from(claims!['user'])
          : null;
      final email = (user?['email'] ??
                  claims?['email'] ??
                  claims?['upn'] ??
                  claims?['preferred_username'] ??
                  claims?['unique_name'] ??
                  widget.args?['email'])?.toString() ??
          "usuario@americanas.io";
      final nome = (user?['nome'] ??
                  user?['name'] ??
                  _nomeDosClaims(claims, email))
              ?.toString() ??
          '';
      final stores = user?['stores'] ?? claims?['stores'];
      final loja = user?['loja']?.toString() ??
          claims?['loja']?.toString() ??
          (stores is List && stores.isNotEmpty ? stores.first.toString() : null);
      _session.saveUserInfo(
          email, nome, loja ?? _session.getUserStore() ?? Constants.defaultStore);
    } catch (e) {
      LogHelper.e('LoginWebView: erro ao salvar token', e);
    }
    // Sempre navega para a home, mesmo se a persistência falhar.
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
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

class _CarregamentoWidget extends StatefulWidget {
  const _CarregamentoWidget();

  @override
  State<_CarregamentoWidget> createState() => _CarregamentoWidgetState();
}

class _CarregamentoWidgetState extends State<_CarregamentoWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE60000),
      child: Center(
        child: FadeTransition(
          opacity: _pulse.drive(Tween<double>(begin: 1.0, end: 0.3)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/ic_maestro_logo.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const Text('Autenticando...',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
