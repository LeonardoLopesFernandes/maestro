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
  bool _senhaVisivel = false;
  bool _salvarCredenciais = true;
  bool _carregando = false;
  bool _reconectando = false;
  late final SessionManager _session;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _session = await SessionManager.create();
    final email = _session.getUserEmail();
    final senha = _session.getSavedPassword();
    if (email != null) _emailController.text = email;
    if (senha != null) _senhaController.text = senha;
    if (mounted) setState(() {});

    if (_session.hasSavedCredentials()) {
      _iniciarReconexaoSilenciosa();
    }
  }

  void _iniciarReconexaoSilenciosa() {
    setState(() {
      _reconectando = true;
      _carregando = true;
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      _abrirWebView(autoLogin: true);
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE60000),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // "a" gigante ao fundo (espelha activity_login.xml: txtFundoGigante).
          // Escala com a altura da tela para cobrir do topo ao rodapé.
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                return Align(
                  alignment: const Alignment(0.95, 0.5),
                  child: Text(
                    'a',
                    style: TextStyle(
                      fontSize: h * 1.2,
                      height: 1.0,
                      color: Colors.black12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              },
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
                          if (_reconectando)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 20),
                              child: Text(
                                'Sessão expirada. Reconectando automaticamente...',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ),
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
                                  obscure: !_senhaVisivel,
                                  mostrarOlho: true,
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
    bool mostrarOlho = false,
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
          suffixIcon: mostrarOlho
              ? IconButton(
                  icon: Icon(
                    _senhaVisivel
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: const Color(0xFF0056B3),
                  ),
                  onPressed: () =>
                      setState(() => _senhaVisivel = !_senhaVisivel),
                )
              : null,
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
