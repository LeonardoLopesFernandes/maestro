import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(Constants.RED_600),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    const Icon(Icons.shopping_cart, size: 72, color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'Maestro',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gestão de Pedidos',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 48),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDec('E-mail'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _senhaController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDec('Senha'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _salvarCredenciais,
                          onChanged: (v) =>
                              setState(() => _salvarCredenciais = v ?? true),
                          fillColor:
                              MaterialStateProperty.all(Colors.white),
                          checkColor: const Color(Constants.RED_600),
                        ),
                        const Text('Salvar credenciais',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _carregando ? null : () => _abrirWebView(autoLogin: true),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: const Color(Constants.RED_600),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _carregando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('ENTRAR',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _carregando ? null : () => _abrirWebView(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('ENTRAR COM MICROSOFT',
                          style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          _session.clearCredentials(),
                      child: const Text('Esqueci minha senha',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      );
}
