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

/// Splash animado do maestro. Linha do tempo (3,4 s no total):
///   0,0–0,9 s  entrada da moto (com rastro de velocidade)
///   0,9–1,3 s  frenagem no centro (impacto + brilho)
///   1,3–2,2 s  explosão: a moto se fragmenta em partículas luminosas
///   2,2–3,4 s  as partículas se organizam formando o logo/nome "maestro"
/// Roda uma vez; fundo vermelho.
class MaestroSplashAnim extends StatefulWidget {
  const MaestroSplashAnim({super.key});

  @override
  State<MaestroSplashAnim> createState() => _MaestroSplashAnimState();
}

class _MaestroSplashAnimState extends State<MaestroSplashAnim>
    with SingleTickerProviderStateMixin {
  static const double _motoSize = 190;
  static const Duration _duration = Duration(milliseconds: 5000);

  // Frações da linha do tempo. Entrada/frenagem curtas; explosão e formação
  // (partículas) ocupam a maior parte, para o efeito não ficar rápido.
  static const double _rideEnd = 0.12; // 0,6 s
  static const double _brakeEnd = 0.19; // 0,95 s
  static const double _explosionEnd = 0.54; // 2,7 s

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

    controller = AnimationController(vsync: this, duration: _duration)
      ..addListener(() {
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
    if (particlesCreated || !_ready) return;
    if (controller.value < 0.18) return;
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
      final distance = 40 + random.nextDouble() * 80;

      particles.add(
        _Particle(
          start: mp,
          explosion: mp + Offset(cos(angle), sin(angle)) * distance,
          target: tp,
          size: 1.0 + random.nextDouble() * 2.0,
          delay: random.nextDouble() * 0.18,
          rotation: random.nextDouble() * pi * 2,
        ),
      );
    }
  }

  double _ride() => Curves.easeOutCubic.transform(
        (controller.value / _rideEnd).clamp(0.0, 1.0),
      );

  double _explosionProgress() {
    if (controller.value < _brakeEnd) return 0;
    return ((controller.value - _brakeEnd) / (_explosionEnd - _brakeEnd))
        .clamp(0.0, 1.0);
  }

  double _formationProgress() {
    if (controller.value < _explosionEnd) return 0;
    return ((controller.value - _explosionEnd) / (1 - _explosionEnd))
        .clamp(0.0, 1.0);
  }

  Widget _motoAt(Offset topLeft, double opacity, double tilt, double scale) {
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      child: Transform.rotate(
        angle: tilt,
        child: Transform.scale(
          scale: scale,
          child: Opacity(opacity: opacity, child: _motoWidget),
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
          double motoX(double r) => startX + (endX - startX) * r;

          // Frenagem: passa um tico do centro e volta (impacto).
          final brakeT = ((t - _rideEnd) / (_brakeEnd - _rideEnd))
              .clamp(0.0, 1.0);
          final impact = sin(brakeT * pi);
          final motoScale = 1 + impact * 0.04;
          final bob = sin(ride * pi * 3) * (1 - ride) * 5;
          final tilt = (1 - ride) * -0.05;
          final motoTop = center.dy - _motoSize / 2 + bob;

          // Some devagar no início da explosão.
          final motoOpacity =
              (1 - ((t - _brakeEnd) / 0.08)).clamp(0.0, 1.0);

          final finalOpacity = ((t - 0.88) / 0.12).clamp(0.0, 1.0);

          final children = <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _GlowPainter(progress: t),
              ),
            ),
          ];

          // Rastro de velocidade durante a entrada.
          if (t < _rideEnd && ride > 0) {
            const gaps = [0.07, 0.14, 0.21];
            for (int i = 0; i < gaps.length; i++) {
              final r = (ride - gaps[i]).clamp(0.0, 1.0);
              children.add(
                _motoAt(
                  Offset(motoX(r), motoTop),
                  motoOpacity * (0.16 - i * 0.04),
                  tilt,
                  motoScale,
                ),
              );
            }
          }

          if (t < 0.34 && motoOpacity > 0) {
            children.add(_motoAt(
              Offset(motoX(ride) + impact * 5, motoTop),
              motoOpacity,
              tilt,
              motoScale,
            ));
          }

          if (particlesCreated) {
            children.add(Positioned.fill(
              child: CustomPaint(
                painter: _ParticlePainter(
                  particles: particles,
                  explosion: _explosionProgress(),
                  formation: _formationProgress(),
                  center: center,
                ),
              ),
            ));
          }

          if (finalOpacity > 0) {
            children.add(Center(
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
            ));
          }

          return Stack(children: children);
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
  final double explosion;
  final double formation;
  final Offset center;

  _ParticlePainter({
    required this.particles,
    required this.explosion,
    required this.formation,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (explosion <= 0 && formation <= 0) return;

    final haloPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    for (final particle in particles) {
      Offset position;
      double opacity;

      if (formation <= 0) {
        // Explosão: da silhueta da moto para fora.
        final ep = ((explosion - particle.delay) / (1 - particle.delay))
            .clamp(0.0, 1.0);
        if (ep <= 0) continue;
        position = Offset.lerp(
          particle.start,
          particle.explosion,
          Curves.easeOutSine.transform(ep),
        )!;
        opacity = ep < 0.1 ? ep / 0.1 : 1.0;
      } else {
        // Formação: da explosão para o "maestro".
        position = Offset.lerp(
          particle.explosion,
          particle.target,
          Curves.easeInOutSine.transform(formation),
        )!;
        opacity = formation < 0.82
            ? 1.0
            : (1 - (formation - 0.82) / 0.18).clamp(0.0, 1.0);
      }

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      final pulse =
          1 + sin((explosion + formation) * pi * 8 + particle.rotation) * 0.2;
      final p = center + position;

      // Halo luminoso apenas na explosão. Na formação ele some, para o nome
      // "maestro" ficar nítido (sem brilho estragando o efeito).
      if (formation <= 0) {
        canvas.drawCircle(p, particle.size * pulse * 2.2, haloPaint);
      }
      canvas.drawCircle(p, particle.size * pulse, paint);
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

    // Brilho no momento da frenagem/impacto.
    if (progress < 0.11 || progress > 0.42) return;

    final p = ((progress - 0.11) / 0.31).clamp(0.0, 1.0);
    final intensity = sin(p * pi);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: intensity * 0.22),
          Colors.white.withValues(alpha: intensity * 0.05),
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
