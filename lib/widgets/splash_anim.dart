import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'maestro_m.dart';

/// Loading de marca do maestro, usado enquanto o app/webview inicializa.
class MaestroSplashAnim extends StatefulWidget {
  final String mensagem;

  const MaestroSplashAnim({
    super.key,
    this.mensagem = 'Sincronizando pedidos...',
  });

  @override
  State<MaestroSplashAnim> createState() => _MaestroSplashAnimState();
}

class _MaestroSplashAnimState extends State<MaestroSplashAnim>
    with SingleTickerProviderStateMixin {
  static const Color _vermelho = Color(0xFFE60000);

  late final AnimationController _controller;
  late final Animation<double> _mProgress;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _mProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.72, curve: Curves.easeInOut),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando Maestro',
      child: ColoredBox(
        color: _vermelho,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: const Alignment(0.95, 0.05),
                    child: Text(
                      'a',
                      style: TextStyle(
                        fontSize: constraints.maxHeight * 1.8,
                        height: 1,
                        color: Colors.black12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (_, __) => MaestroMDraw(
                            progress: _mProgress.value,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FadeTransition(
                          opacity: _opacity,
                          child: SlideTransition(
                            position: _slide,
                            child: const Text(
                              'maestro',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: 250,
                          height: 167,
                          child: Lottie.asset(
                            'assets/lottie/splash.json',
                            fit: BoxFit.contain,
                            repeat: true,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.two_wheeler,
                              color: Colors.white,
                              size: 72,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          widget.mensagem,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 180,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: const LinearProgressIndicator(
                              minHeight: 3,
                              backgroundColor: Colors.white24,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'americanas.io',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

