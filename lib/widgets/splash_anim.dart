import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Splash animado do maestro (Lottie) com o texto "maestro" surgindo embaixo.
class MaestroSplashAnim extends StatefulWidget {
  const MaestroSplashAnim({super.key});

  @override
  State<MaestroSplashAnim> createState() => _MaestroSplashAnimState();
}

class _MaestroSplashAnimState extends State<MaestroSplashAnim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _opacity = curved;
    _slide = Tween<Offset>(begin: const Offset(0, 0.45), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE60000),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/lottie/splash.json',
              width: 300,
              height: 200,
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (_, error, __) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.two_wheeler, color: Colors.white, size: 80),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Lottie: $error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FadeTransition(
              opacity: _opacity,
              child: SlideTransition(
                position: _slide,
                child: const Text(
                  'maestro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
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
