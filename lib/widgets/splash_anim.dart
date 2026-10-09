import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SVG da moto (Material "sharp-motorcycle"), usado na tela de splash e no
/// carregamento da autenticação (login webview).
const String _motoSvg = '<svg xmlns="http://www.w3.org/2000/svg" '
    'width="24" height="24" viewBox="0 0 24 24"><path fill="#ffffff" '
    'd="M19.44 9.03L15.41 5H11v2h3.59l2 2H5c-2.8 0-5 2.2-5 5s2.2 5 5 5c2.46 '
    '0 4.45-1.69 4.9-4h1.65l2.77-2.77c-.21.54-.32 1.14-.32 1.77c0 2.8 2.2 5 '
    '5 5s5-2.2 5-5c0-2.65-1.97-4.77-4.56-4.97M7.82 15C7.4 16.15 6.28 17 5 '
    '17c-1.63 0-3-1.37-3-3s1.37-3 3-3c1.28 0 2.4.85 2.82 2H5v2zM19 17c-1.66 '
    '0-3-1.34-3-3s1.34-3 3-3s3 1.34 3 3s-1.34 3-3 3"/></svg>';

/// Splash animado do maestro:
///   0,0–1,5 s  a moto anda da esquerda e para no centro.
///   1,5–2,0 s  a moto some suavemente.
///   1,9–3,8 s  as letras de "maestro" se formam uma a uma.
/// Sem partículas e sem brilho. Roda uma vez; fundo vermelho.
class MaestroSplashAnim extends StatefulWidget {
  const MaestroSplashAnim({super.key});

  @override
  State<MaestroSplashAnim> createState() => _MaestroSplashAnimState();
}

class _MaestroSplashAnimState extends State<MaestroSplashAnim>
    with SingleTickerProviderStateMixin {
  static const double _motoSize = 190;
  static const Duration _duration = Duration(milliseconds: 3800);

  static const List<String> _letters = ['m', 'a', 'e', 's', 't', 'r', 'o'];

  static const TextStyle _letterStyle = TextStyle(
    color: Colors.white,
    fontSize: 52,
    fontWeight: FontWeight.w900,
    letterSpacing: 3,
    height: 1.0,
  );

  // Frações da linha do tempo.
  static const double _rideEnd = 0.40; // fim da entrada
  static const double _brakeEnd = 0.50; // fim da frenagem
  static const double _lettersStart = 0.50; // início das letras
  static const double _letterStep = 0.045; // atraso entre letras
  static const double _letterDur = 0.22; // duração de cada letra

  late final AnimationController controller;
  late final Widget _motoWidget;

  @override
  void initState() {
    super.initState();

    // Criado uma única vez: o mesmo widget é reutilizado a cada frame.
    _motoWidget = SvgPicture.string(
      _motoSvg,
      width: _motoSize,
      height: _motoSize,
    );

    controller = AnimationController(vsync: this, duration: _duration)
      ..addListener(() => setState(() {}));

    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  double _ride() => Curves.easeOutCubic.transform(
        (controller.value / _rideEnd).clamp(0.0, 1.0),
      );

  Widget _moto(double x, double y, double opacity, double tilt, double scale) {
    return Positioned(
      left: x,
      top: y,
      child: Transform.rotate(
        angle: tilt,
        child: Transform.scale(
          scale: scale,
          child: Opacity(opacity: opacity, child: _motoWidget),
        ),
      ),
    );
  }

  Widget _letter(String ch, int i) {
    final t = controller.value;
    final start = _lettersStart + i * _letterStep;
    final p = ((t - start) / _letterDur).clamp(0.0, 1.0);

    final eased = Curves.easeOutBack.transform(p);
    final opacity =
        p <= 0 ? 0.0 : Curves.easeOut.transform((p * 1.5).clamp(0.0, 1.0));

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * 14),
        child: Transform.scale(
          scale: 0.7 + eased * 0.3,
          child: Text(ch, style: _letterStyle),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE60000),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final t = controller.value;
          final center = Offset(
            constraints.maxWidth / 2,
            constraints.maxHeight / 2,
          );

          final ride = _ride();
          final startX = -_motoSize - 60;
          final endX = center.dx - _motoSize / 2;
          final brakeT =
              ((t - _rideEnd) / (_brakeEnd - _rideEnd)).clamp(0.0, 1.0);
          final impact = sin(brakeT * pi);
          final motoX = startX + (endX - startX) * ride + impact * 4;
          final bob = sin(ride * pi * 3) * (1 - ride) * 5;
          final tilt = (1 - ride) * -0.05;
          final motoScale = 1 + impact * 0.04;
          final motoOpacity =
              (1 - ((t - _brakeEnd) / 0.08)).clamp(0.0, 1.0);
          final motoTop = center.dy - _motoSize / 2 + bob;

          return Stack(
            children: [
              if (t < 0.58 && motoOpacity > 0)
                _moto(motoX, motoTop, motoOpacity, tilt, motoScale),

              // Palavra "maestro", letra a letra.
              if (t >= _lettersStart)
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < _letters.length; i++)
                        _letter(_letters[i], i),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
