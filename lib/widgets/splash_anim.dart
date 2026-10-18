import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Splash animado do maestro (Lottie), fundo vermelho.
class MaestroSplashAnim extends StatelessWidget {
  const MaestroSplashAnim({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE60000),
      child: Center(
        child: Lottie.asset(
          'assets/lottie/splash.json',
          fit: BoxFit.contain,
          repeat: false,
        ),
      ),
    );
  }
}
