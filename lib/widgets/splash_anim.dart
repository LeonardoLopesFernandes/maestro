import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Splash animado do maestro: a moto entra, explode em partículas que formam
/// o texto "maestro". Fundo escuro; roda uma vez.
class MaestroSplashAnim extends StatefulWidget {
  const MaestroSplashAnim({super.key});

  @override
  State<MaestroSplashAnim> createState() => _MaestroSplashAnimState();
}

class _MaestroSplashAnimState extends State<MaestroSplashAnim>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  final Random random = Random();

  final List<_Particle> particles = [];
  List<Offset> _imagePoints = [];

  bool particlesCreated = false;

  @override
  void initState() {
    super.initState();

    _loadImagePoints();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..addListener(() {
        setState(() {});

        if (controller.value > 0.54 &&
            !particlesCreated &&
            _imagePoints.isNotEmpty) {
          particlesCreated = true;
          _createParticles();
        }
      });

    controller.forward();
  }

  /// Extrai os pontos (silhueta) do PNG do logo pelo canal alfa, para as
  /// partículas formarem a imagem em vez do texto.
  Future<void> _loadImagePoints() async {
    final data = await rootBundle.load('assets/splash.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final bytesData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytesData == null) return;
    final bytes = bytesData.buffer.asUint8List();
    const targetW = 170.0;
    final scale = targetW / image.width;
    final pts = <Offset>[];
    for (int y = 0; y < image.height; y += 2) {
      for (int x = 0; x < image.width; x += 2) {
        final index = (y * image.width + x) * 4;
        if (bytes[index + 3] > 100) {
          pts.add(Offset(
            (x - image.width / 2) * scale,
            (y - image.height / 2) * scale,
          ));
        }
      }
    }
    if (!mounted) return;
    setState(() => _imagePoints = pts);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _createParticles() {
    final textPoints = _imagePoints;
    if (textPoints.isEmpty) return;

    // Distribui as partículas por TODA a silhueta (antes pegava só os
    // primeiros pontos, deixando o logo "riscado").
    final total = min(textPoints.length, 2000);

    for (int i = 0; i < total; i++) {
      final angle = random.nextDouble() * pi * 2;
      final explosionDistance = 20 + random.nextDouble() * 150;

      final start = Offset(
        cos(angle) * 45,
        sin(angle) * 45,
      );

      final explosion = Offset(
        cos(angle) * explosionDistance,
        sin(angle) * explosionDistance,
      );

      final target =
          textPoints[(i * textPoints.length ~/ total).clamp(0, textPoints.length - 1)];

      particles.add(
        _Particle(
          start: start,
          explosion: explosion,
          target: target,
          size: 1.2 + random.nextDouble() * 2.4,
          delay: random.nextDouble() * 0.15,
          rotation: random.nextDouble() * pi * 2,
        ),
      );
    }
  }

  double _motorProgress() {
    return Curves.easeOutCubic.transform(
      (controller.value / 0.48).clamp(0.0, 1.0),
    );
  }

  double _particleProgress() {
    if (controller.value < 0.52) return 0;

    return Curves.easeInOutCubic.transform(
      ((controller.value - 0.52) / 0.40).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE60000),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final center = Offset(
            constraints.maxWidth / 2,
            constraints.maxHeight / 2,
          );

          return Stack(
            children: [
              // Brilho central.
              Positioned.fill(
                child: CustomPaint(
                  painter: _GlowPainter(
                    progress: controller.value,
                  ),
                ),
              ),

              // Moto.
              if (controller.value < 0.72)
                CustomPaint(
                  size: Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  ),
                  painter: _MotorcyclePainter(
                    progress: _motorProgress(),
                    particleProgress: _particleProgress(),
                    center: center,
                  ),
                ),

              // Partículas.
              if (particlesCreated)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ParticlePainter(
                      particles: particles,
                      progress: _particleProgress(),
                      center: center,
                    ),
                  ),
                ),

              // Pequeno brilho final.
              if (controller.value > 0.82)
                Center(
                  child: Opacity(
                    opacity: ((controller.value - 0.82) / 0.18)
                        .clamp(0.0, 1.0),
                    child: Image.asset(
                      'assets/splash.png',
                      width: 180,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Particle {
  final Offset start;
  final Offset explosion;
  final Offset target;
  final double size;
  final double delay;
  final double rotation;

  _Particle({
    required this.start,
    required this.explosion,
    required this.target,
    required this.size,
    required this.delay,
    required this.rotation,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Offset center;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final localProgress =
          ((progress - particle.delay) / (1 - particle.delay))
              .clamp(0.0, 1.0);

      if (localProgress <= 0) continue;

      Offset position;

      if (localProgress < 0.28) {
        // Explosão.
        final p = Curves.easeOut.transform(
          localProgress / 0.28,
        );

        position = Offset.lerp(
          particle.start,
          particle.explosion,
          p,
        )!;
      } else {
        // Formação do texto.
        final p = Curves.easeInOutCubic.transform(
          (localProgress - 0.28) / 0.72,
        );

        position = Offset.lerp(
          particle.explosion,
          particle.target,
          p,
        )!;
      }

      final opacity = localProgress < 0.12
          ? localProgress / 0.12
          : 1.0;

      final paint = Paint()
        ..color = Colors.white.withValues(
          alpha: opacity.clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.fill;

      final pulse =
          1 + sin(localProgress * pi * 8 + particle.rotation) * 0.25;

      canvas.drawCircle(
        center + position,
        particle.size * pulse,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return true;
  }
}

class _MotorcyclePainter extends CustomPainter {
  final double progress;
  final double particleProgress;
  final Offset center;

  _MotorcyclePainter({
    required this.progress,
    required this.particleProgress,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = Colors.white.withValues(
        alpha: (1 - particleProgress * 1.4).clamp(0.0, 1.0),
      )
      ..style = PaintingStyle.fill;

    final x = -size.width * 0.65 + (size.width * 0.65 * progress);

    final y = center.dy;

    canvas.save();

    canvas.translate(x, y);

    canvas.scale(
      1.0 + sin(progress * pi) * 0.04,
    );

    // Inclinação durante a chegada.
    canvas.rotate(
      (1 - progress) * -0.08,
    );

    final path = Path();

    path.moveTo(17.42, 10);
    path.lineTo(13.41, 6);
    path.lineTo(9, 6);
    path.lineTo(9, 8);
    path.lineTo(12.59, 8);
    path.lineTo(14.59, 10);
    path.lineTo(6.5, 10);

    path.cubicTo(
      4,
      10,
      2,
      12,
      2,
      14.5,
    );

    path.cubicTo(
      2,
      17,
      4,
      19,
      6.5,
      19,
    );

    path.cubicTo(
      8.72,
      19,
      10.56,
      17.38,
      10.92,
      15.27,
    );

    path.lineTo(13.04, 14);

    path.cubicTo(
      13,
      14.17,
      13,
      14.33,
      13,
      14.5,
    );

    path.cubicTo(
      13,
      17,
      15,
      19,
      17.5,
      19,
    );

    path.cubicTo(
      20,
      19,
      22,
      17,
      22,
      14.5,
    );

    path.cubicTo(
      22,
      12,
      20,
      10,
      17.42,
      10,
    );

    canvas.scale(6);

    canvas.drawPath(path, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MotorcyclePainter oldDelegate) {
    return true;
  }
}

class _GlowPainter extends CustomPainter {
  final double progress;

  _GlowPainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    if (progress < 0.42 || progress > 0.85) return;

    final p = ((progress - 0.42) / 0.43).clamp(0.0, 1.0);

    final intensity = sin(p * pi);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(
            alpha: intensity * 0.20,
          ),
          Colors.white.withValues(
            alpha: intensity * 0.04,
          ),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: center,
          radius: 220,
        ),
      );

    canvas.drawCircle(
      center,
      220,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) {
    return true;
  }
}
