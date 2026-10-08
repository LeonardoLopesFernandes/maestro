import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Splash animado do maestro: a moto entra, para no centro, se desfaz em
/// partículas (com a silhueta exata da moto) e as partículas se juntam para
/// formar o logo/nome "maestro". Fundo vermelho; roda uma vez.
class MaestroSplashAnim extends StatefulWidget {
  const MaestroSplashAnim({super.key});

  @override
  State<MaestroSplashAnim> createState() => _MaestroSplashAnimState();
}

class _MaestroSplashAnimState extends State<MaestroSplashAnim>
    with SingleTickerProviderStateMixin {
  static const double _motoSize = 190;

  late final AnimationController controller;
  late final Widget _motoWidget;

  final Random random = Random();

  final List<_Particle> particles = [];
  List<Offset> _motoPoints = [];
  List<Offset> _logoPoints = [];

  bool particlesCreated = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();

    // Criado uma única vez: o mesmo widget é reutilizado a cada frame, então o
    // SVG não é reprocessado durante a animação.
    _motoWidget = SvgPicture.string(
      _motoSvg,
      width: _motoSize,
      height: _motoSize,
    );

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    )..addListener(() {
        setState(() {});
        _maybeCreateParticles();
      });

    _loadPoints();
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Carrega os pontos da silhueta do logo "maestro" (assets/splash.png) e da
  /// moto (rasterizando o SVG).
  Future<void> _loadPoints() async {
    final results = await Future.wait([
      _loadLogoPoints(),
      _rasterizeSvg(_motoSvg, _motoSize),
    ]);
    if (!mounted) return;
    setState(() {
      _logoPoints = results[0];
      _motoPoints = results[1];
      _ready = true;
    });
    _maybeCreateParticles();
  }

  /// Extrai os pontos (silhueta) do PNG do logo pelo canal alfa.
  Future<List<Offset>> _loadLogoPoints() async {
    final data = await rootBundle.load('assets/splash.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final bytesData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytesData == null) return [];
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
    return pts;
  }

  /// Rasteriza o SVG no tamanho [size] e devolve a silhueta (pontos com alfa),
  /// centrada na origem. É isso que permite as partículas nascerem com o
  /// desenho exato da moto.
  Future<List<Offset>> _rasterizeSvg(String svg, double size) async {
    final info = await vg.loadPicture(SvgStringLoader(svg), null);
    final svgSize = info.size;
    if (svgSize.width <= 0 || svgSize.height <= 0) return [];

    final scale = size / svgSize.width;
    final w = (svgSize.width * scale).round();
    final h = (svgSize.height * scale).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.drawPicture(info.picture);
    info.picture.dispose();

    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    picture.dispose();

    final bytesData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytesData == null) return [];
    final bytes = bytesData.buffer.asUint8List();

    final pts = <Offset>[];
    for (int y = 0; y < image.height; y += 2) {
      for (int x = 0; x < image.width; x += 2) {
        final index = (y * image.width + x) * 4;
        if (bytes[index + 3] > 100) {
          pts.add(Offset(
            x - image.width / 2,
            y - image.height / 2,
          ));
        }
      }
    }
    return pts;
  }

  void _maybeCreateParticles() {
    if (particlesCreated) return;
    if (!_ready) return;
    if (controller.value < 0.48) return;
    particlesCreated = true;
    _createParticles();
  }

  void _createParticles() {
    if (_motoPoints.isEmpty || _logoPoints.isEmpty) return;

    final total = min(_motoPoints.length, 1200);

    for (int i = 0; i < total; i++) {
      final mp = _motoPoints[
          (i * _motoPoints.length ~/ total).clamp(0, _motoPoints.length - 1)];
      final tp = _logoPoints[
          (i * _logoPoints.length ~/ total).clamp(0, _logoPoints.length - 1)];

      final angle = random.nextDouble() * pi * 2;

      particles.add(
        _Particle(
          start: mp,
          target: tp,
          dir: Offset(cos(angle), sin(angle)),
          bulge: 4 + random.nextDouble() * 16,
          size: 1.0 + random.nextDouble() * 2.0,
          delay: random.nextDouble() * 0.30,
          rotation: random.nextDouble() * pi * 2,
        ),
      );
    }
  }

  double _motorProgress() => Curves.easeOutCubic.transform(
        (controller.value / 0.36).clamp(0.0, 1.0),
      );

  // A moto para no centro (0.36) e começa a se desfazer devagar (0.46 → 0.90).
  double _particleProgress() {
    if (controller.value < 0.46) return 0;
    return ((controller.value - 0.46) / 0.44).clamp(0.0, 1.0);
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

          final p = _motorProgress();
          final startX = -_motoSize - 60;
          final endX = center.dx - _motoSize / 2;
          final motoX = startX + (endX - startX) * p;
          final bob = sin(p * pi * 3) * (1 - p) * 6;
          final tilt = (1 - p) * -0.06;
          // A moto some devagar, acompanhando o início do desmanche.
          final motoOpacity =
              (1 - ((controller.value - 0.48) / 0.16)).clamp(0.0, 1.0);
          final finalOpacity =
              ((controller.value - 0.88) / 0.12).clamp(0.0, 1.0);

          return Stack(
            children: [
              // Brilho central.
              Positioned.fill(
                child: CustomPaint(
                  painter: _GlowPainter(progress: controller.value),
                ),
              ),

              // Moto (SVG).
              if (controller.value < 0.66 && motoOpacity > 0)
                Transform.translate(
                  offset: Offset(motoX, center.dy - _motoSize / 2 + bob),
                  child: Transform.rotate(
                    angle: tilt,
                    child: Opacity(
                      opacity: motoOpacity,
                      child: _motoWidget,
                    ),
                  ),
                ),

              // Partículas: saem da silhueta da moto e formam o "maestro".
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

              // Logo final.
              if (finalOpacity > 0)
                Center(
                  child: Opacity(
                    opacity: finalOpacity,
                    child: Image.asset(
                      'assets/splash.png',
                      width: 180,
                      color: Colors.white,
                      colorBlendMode: BlendMode.srcIn,
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
  final Offset target;
  final Offset dir;
  final double bulge;
  final double size;
  final double delay;
  final double rotation;

  _Particle({
    required this.start,
    required this.target,
    required this.dir,
    required this.bulge,
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
    if (progress <= 0) return;

    for (final particle in particles) {
      final localProgress =
          ((progress - particle.delay) / (1 - particle.delay))
              .clamp(0.0, 1.0);

      if (localProgress <= 0) continue;

      final eased = Curves.easeInOutSine.transform(localProgress);

      // Vai da silhueta da moto para a do logo, com um leve "estufar" no meio.
      final base = Offset.lerp(particle.start, particle.target, eased)!;
      final bulge = particle.dir * (sin(localProgress * pi) * particle.bulge);
      final position = base + bulge;

      final opacity = localProgress < 0.1
          ? localProgress / 0.1
          : localProgress > 0.88
              ? (1 - localProgress) / 0.12
              : 1.0;

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0))
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
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

class _GlowPainter extends CustomPainter {
  final double progress;

  _GlowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    if (progress < 0.40 || progress > 0.88) return;

    final p = ((progress - 0.40) / 0.48).clamp(0.0, 1.0);
    final intensity = sin(p * pi);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: intensity * 0.20),
          Colors.white.withValues(alpha: intensity * 0.04),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: 220),
      );

    canvas.drawCircle(center, 220, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) => true;
}
