import 'package:flutter/material.dart';
import 'dart:convert';
import '../network/session_manager.dart';
import '../utils/constants.dart';
import 'login_webview_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _salvarCredenciais = true;
  bool _carregando = false;
  late final SessionManager _session;

  @override
  void initState() {
    super.initState();
    _init();
    // Se veio de um 401, abre direto o diálogo de token (pula a tela de login).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['abrirToken'] == true && mounted) {
        _entrarComToken();
      }
    });
  }

  Future<void> _init() async {
    _session = await SessionManager.create();
    final email = _session.getUserEmail();
    final senha = _session.getSavedPassword();
    if (email != null) _emailController.text = email;
    if (senha != null) _senhaController.text = senha;
    if (mounted) setState(() {});
  }

  void _abrirWebView({bool autoLogin = false}) {
    if (_salvarCredenciais && _emailController.text.isNotEmpty) {
      _session.saveCredentials(
          _emailController.text.trim(), _senhaController.text);
    } else {
      _session.clearCredentials();
    }
    setState(() => _carregando = true);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginWebViewScreen(
          args: {
            'email': _emailController.text.trim(),
            'senha': _senhaController.text,
            'autoLogin': autoLogin,
          },
        ),
      ),
    );
  }

  void _entrarDemo() {
    _session.enableDemo();
    Navigator.of(context).pushReplacementNamed('/home');
  }

  // Entrada manual do token gerado no site (maestro.americanas.io/login?token=...).
  // Útil quando o MFA (SMS) do Microsoft está indisponível.
  void _entrarComToken() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrar com token'),
        content: TextField(
          controller: c,
          maxLines: null,
          minLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText:
                'Cole o token JWT ou a URL com token=/rc-newToken (também serve o token do Papeleta63 / Rotina Comercial)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              final token = _extrairTokenDeTexto(c.text);
              if (token == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Token não encontrado no texto informado.'),
                ));
                return;
              }
              Navigator.pop(ctx);
              _aplicarToken(token);
            },
            child: const Text('ENTRAR'),
          ),
        ],
      ),
    );
  }

  String? _extrairTokenDeTexto(String texto) {
    const patterns = [
      'token=',
      'newToken=',
      'bearer=',
      'access_token=',
      'id_token=',
      'auth_token=',
      'jwt=',
    ];
    for (final p in patterns) {
      final idx = texto.indexOf(p);
      if (idx != -1) {
        var v = texto.substring(idx + p.length);
        final fim = v.indexOf(RegExp(r'[&\s;]'));
        if (fim != -1) v = v.substring(0, fim);
        if (v.isNotEmpty) return v;
      }
    }
    final t = texto.trim();
    if (t.startsWith('eyJ') && t.split('.').length == 3) return t;
    // Token bruto colado diretamente (ex.: rc-newToken do Papeleta63 / Rotina
    // Comercial, que não é um JWT). Não aceita URLs nem textos muito longos.
    if (t.isNotEmpty &&
        !t.contains(RegExp(r'\s')) &&
        !t.startsWith('http') &&
        t.length >= 20 &&
        t.length <= 1000) return t;
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

  void _aplicarToken(String token) {
    final claims = _decodificarClaims(token);
    _session.saveToken(
        token, expiryEpochSeconds: claims?['exp'] is int ? claims!['exp'] as int : null);
    final email = (claims?['email'] ??
            claims?['upn'] ??
            claims?['preferred_username'] ??
            claims?['unique_name'])
        ?.toString();
    final nome = _nomeDosClaims(claims, email ?? '');
    final stores = claims?['stores'];
    final loja = claims?['loja']?.toString() ??
        (stores is List && stores.isNotEmpty ? stores.first.toString() : null);
    _session.saveUserInfo(
      email ?? 'usuario@americanas.io',
      nome,
      loja ?? _session.getUserStore() ?? Constants.defaultStore,
    );
    Navigator.of(context).pushReplacementNamed('/home');
  }

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

  String _capitalizar(String s) => s
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE60000),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // "M" gigante ao fundo (espelha activity_login.xml: txtFundoGigante)
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0.0, 0.75),
              child: Transform.scale(
                scale: 5.5,
                child: const Text(
                  'M',
                  style: TextStyle(
                    fontSize: 200,
                    color: Colors.black12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const SizedBox(height: 56),
                          // 1. Logo + título
                          Image.asset(
                            'assets/ic_maestro_logo.png',
                            width: 96,
                            height: 96,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'maestro',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Gerencie todos os seus pedidos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          // 2. Formulário (width 320)
                          SizedBox(
                            width: 320,
                            child: Column(
                              children: [
                                _campo(
                                  controller: _emailController,
                                  hint: 'E-mail institucional',
                                  keyboardType:
                                      TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 15),
                                _campo(
                                  controller: _senhaController,
                                  hint: 'Senha',
                                  obscure: true,
                                ),
                                const SizedBox(height: 40),
                                SizedBox(
                                  width: double.infinity,
                                  height: 60,
                                  child: ElevatedButton(
                                    onPressed: _carregando
                                        ? null
                                        : () =>
                                            _abrirWebView(autoLogin: true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF1A1A1A),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _carregando
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Text(
                                            'ENTRAR',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: Colors.white
                                            .withOpacity(0.33),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10),
                                      child: Text('ou',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12)),
                                    ),
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: Colors.white
                                            .withOpacity(0.33),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _carregando
                                        ? null
                                        : () => _abrirWebView(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor:
                                          const Color(0xFF333333),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const _MicrosoftLogo(size: 20),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'ENTRAR COM MICROSOFT',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 2b. Modo demonstração (preview sem credenciais)
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: TextButton(
                              onPressed: _carregando ? null : _entrarDemo,
                              child: const Text(
                                'Entrar em modo demonstração',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 2c. Entrada manual do token gerado no site
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: TextButton(
                              onPressed: _carregando ? null : _entrarComToken,
                              child: const Text(
                                'ENTRAR COM TOKEN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          // 3. Checkbox salvar credenciais
                          InkWell(
                            onTap: () => setState(
                                () => _salvarCredenciais = !_salvarCredenciais),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: _salvarCredenciais
                                            ? Colors.white
                                            : Colors.white54,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      color: _salvarCredenciais
                                          ? Colors.white
                                          : Colors.transparent,
                                    ),
                                    child: _salvarCredenciais
                                        ? const Icon(Icons.check,
                                            size: 18, color: Color(0xFFE60000))
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Salvar credenciais e ativar login automático',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 4. Rodapé versão
                          const Text(
                            'versão 1.6.2 (62)',
                            style: TextStyle(
                              color: Color(0xFFFFCCCC),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Color(0xFF0056B3), fontSize: 16),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFE0F7FA),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF70B7D0), fontSize: 16),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Logo 2x2 da Microsoft (4 quadrados coloridos), espelhando ic_microsoft.xml.
class _MicrosoftLogo extends StatelessWidget {
  final double size;
  const _MicrosoftLogo({this.size = 20});

  @override
  Widget build(BuildContext context) {
    final c = size / 2 - 1;
    final tiles = [
      Container(color: const Color(0xFFF25022)),
      Container(color: const Color(0xFF7FBA00)),
      Container(color: const Color(0xFF00A4EF)),
      Container(color: const Color(0xFFFFBA08)),
    ];
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        children: [
          Row(children: [
            SizedBox(width: c, height: c, child: tiles[0]),
            const SizedBox(width: 2),
            SizedBox(width: c, height: c, child: tiles[1]),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            SizedBox(width: c, height: c, child: tiles[2]),
            const SizedBox(width: 2),
            SizedBox(width: c, height: c, child: tiles[3]),
          ]),
        ],
      ),
    );
  }
}
