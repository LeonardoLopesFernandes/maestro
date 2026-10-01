import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  bool _pedirCredenciais = false;
  String _email = '';
  String _senha = '';
  Timer? _pollTimer;
  Timer? _injectTimer;
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
    _pedirCredenciais = args['pedirCredenciais'] == true;
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

    // ENTRAR COM MICROSOFT: limpa a sessão do site/Microsoft para forçar o
    // login pedir credenciais (troca de usuário), em vez de reutilizar a
    // sessão anterior que entrava automaticamente.
    if (_pedirCredenciais) {
      try {
        await WebViewCookieManager().clearCookies();
      } catch (e) {
        LogHelper.e('LoginWebView: limpar cookies', e);
      }
    }

    await _controller.loadRequest(Uri.parse(Constants.msLoginUrl));
    _pronto = true;
    if (mounted) setState(() {});

    // Auto-login robusto (igual ao minha-loja): injeta as credenciais
    // periodicamente até o login concluir (o Microsoft pode trocar de tela
    // entre email/senha/KMSI em momentos diferentes).
    if (_autoLogin) {
      _injectTimer =
          Timer.periodic(const Duration(milliseconds: 1200), (_) {
        if (!_loginConcluido) _preencherLoginAutomatico();
      });
    }

    // Polling de segurança: a página de resposta pode setar o token via
    // JavaScript sem trocar a URL (igual ao JavascriptInterface do Kotlin).
    _pollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      if (_loginConcluido) return;
      final token = await _capturarToken();
      if (token != null) _salvarToken(token);
    });
  }

  // Força a tela de escolha de conta do Microsoft (ou a de login quando
// pedirCredenciais — ENTRAR COM MICROSOFT — para trocar de usuário).
  bool _garantirSelectAccount(String url) {
    if (_loginConcluido || _promptInjetado) return false;
    if (!url.contains('login.microsoftonline.com')) return false;
    if (url.contains('prompt=')) return false;
    _promptInjetado = true;
    final sep = url.contains('?') ? '&' : '?';
    final prompt = _pedirCredenciais ? 'login' : 'select_account';
    final nova = url + sep + 'prompt=$prompt';
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
        "if(em&&em.value.trim()===''){setV(em,\$EMAIL\$);if(btn){btn.click();}return 'email';}"
        "var pw=document.getElementById('i0118');"
        "if(pw&&pw.value.trim()===''){setV(pw,\$SENHA\$);if(btn){btn.click();}return 'pwd';}"
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
          "if(v&&v.length>50&&v.indexOf(' ')<0&&(v.indexOf('.')>=0||v.indexOf('eyJ')===0)){return v;}"
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
    // Valida o token com a API antes de navegar — evita o ciclo infinito
    // (capturar token inválido -> home -> 401 -> login -> captura de novo).
    try {
      final api = ApiService(ApiClient(session: _session));
      await api.getCounts(_session.getUserStore() ?? Constants.defaultStore);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('401') ||
          msg.contains('token_not_provided') ||
          msg.contains('unauthorized')) {
        LogHelper.e('LoginWebView: token rejeitado pela API', e);
        _loginConcluido = false;
        _tokenCapturado = false;
        if (mounted) setState(() => _carregando = false);
        return;
      }
      // Outros erros (rede) — tenta navegar mesmo assim.
    }
    // Navega para a home.
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _injectTimer?.cancel();
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

/// Moto que passa atrás do logo: vai à direita, volta pela esquerda
/// e para no centro.
const _kMotoSvg =
    '''<svg xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" viewBox="0 0 24 24"><title>sharp-motorcycle</title><path fill="#fffdfd" d="M19.44 9.03L15.41 5H11v2h3.59l2 2H5c-2.8 0-5 2.2-5 5s2.2 5 5 5c2.46 0 4.45-1.69 4.9-4h1.65l2.77-2.77c-.21.54-.32 1.14-.32 1.77c0 2.8 2.2 5 5 5s5-2.2 5-5c0-2.65-1.97-4.77-4.56-4.97M7.82 15C7.4 16.15 6.28 17 5 17c-1.63 0-3-1.37-3-3s1.37-3 3-3c1.28 0 2.4.85 2.82 2H5v2zM19 17c-1.66 0-3-1.34-3-3s1.34-3 3-3s3 1.34 3 3s-1.34 3-3 3"/></svg>''';

/// Logo "a" (Americanas) branco, desenhado com revelação da esquerda pra direita.
const _kLogoSvg =
    '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1254 1254">
<g transform="translate(0.000000,1254.000000) scale(0.100000,-0.100000)" fill="#FFFFFF" stroke="none">
<path fill-rule="evenodd" d="m9528 5330 l252 0 0 -690 0 -690 -3510 0 -3510 0 0 689 0 690 43 3 c32 2 3136 2 6725 -2z m-2853 -2130 c565 -34 1045 -145 1410 -325 412 -203 657 -459 774 -810 68 -203 63 -70 71 -2100 8 -1851 11 -1982 45 -2117 36 -138 125 -250 239 -299 l56 -24 0 -117 0 -118 -859 0 -860 0 -36 110 c-35 109 -98 400 -111 512 -4 32 -10 58 -13 58 -4 0 -31 -25 -61 -56 -128 -130 -348 -296 -557 -420 -727 -431 -1719 -492 -2428 -150 -289 139 -495 309 -646 532 -55 83 -127 220 -158 304 -34 93 -79 280 -92 390 -17 135 -17 438 0 560 30 214 113 476 202 637 98 177 264 360 439 485 119 85 378 214 535 266 341 114 581 158 1490 271 521 65 671 92 834 150 197 71 326 171 371 288 28 71 39 257 21 344 -38 184 -167 313 -383 385 -185 62 -246 69 -593 69 -327 -1 -406 -8 -567 -56 -309 -91 -493 -289 -574 -616 l-27 -113 -797 0 c-438 0 -799 2 -802 5 -8 8 30 230 61 360 225 929 899 1437 2082 1570 301 34 635 43 934 25z m3105 -7520 l0 -690 -3510 0 -3510 0 0 690 0 690 3510 0 3510 0 0 -690z M7234 6340 c-234 -113 -493 -182 -959 -255 -324 -51 -640 -139 -804 -225 -122 -63 -258 -184 -316 -280 -99 -164 -130 -395 -80 -591 79 -304 390 -479 852 -479 539 0 984 203 1219 556 87 131 144 282 181 479 17 90 32 846 17 844 -5 0 -54 -23 -110 -49z"/>
</g>
</svg>''';

class _CarregamentoWidget extends StatefulWidget {
  const _CarregamentoWidget();

  @override
  State<_CarregamentoWidget> createState() => _CarregamentoWidgetState();
}

class _CarregamentoWidgetState extends State<_CarregamentoWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw;

  @override
  void initState() {
    super.initState();
    _draw = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();
  }

  double _motoDx(double t) {
    if (t < 0.3) return 0.8 * (t / 0.3);
    if (t < 0.4) return -0.8;
    if (t < 0.7) return -0.8 + 0.8 * ((t - 0.4) / 0.3);
    return 0.0;
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE60000),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _draw,
              builder: (_, __) {
                final t = _draw.value;
                final w = MediaQuery.of(context).size.width;
                // "Desenha" da esquerda para a direita (15%–75% do ciclo).
                final drawT = ((t - 0.15) / 0.60).clamp(0.0, 1.0);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(_motoDx(t) * w, 0),
                      child: SvgPicture.string(
                        _kMotoSvg,
                        width: 128,
                        height: 128,
                      ),
                    ),
                    SizedBox(
                      width: 128,
                      height: 128,
                      child: Stack(
                        children: [
                          ClipRect(
                            clipper: _LeftRevealClipper(drawT),
                            child: SvgPicture.string(
                              _kLogoSvg,
                              width: 128,
                              height: 128,
                            ),
                          ),
                          if (drawT > 0.02 && drawT < 0.98)
                            Positioned(
                              left: 128 * drawT - 1.5,
                              top: 4,
                              bottom: 4,
                              child: Container(
                                width: 3,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const Text('Autenticando...',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/// Recorta o logo da esquerda para a direita, simulando a ponta da caneta.
class _LeftRevealClipper extends CustomClipper<Rect> {
  final double t;
  _LeftRevealClipper(this.t);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, 0, size.width * t.clamp(0.0, 1.0), size.height);

  @override
  bool shouldReclip(covariant _LeftRevealClipper old) => old.t != t;
}
