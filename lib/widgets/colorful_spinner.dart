import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Spinner circular com gradiente girando e mudando de cor.
class MaestroColorfulSpinner extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color trackColor;

  const MaestroColorfulSpinner({
    super.key,
    this.size = 84,
    this.strokeWidth = 6,
    this.trackColor = const Color(0x33FFFFFF),
  });

  @override
  State<MaestroColorfulSpinner> createState() => _MaestroColorfulSpinnerState();
}

class _MaestroColorfulSpinnerState extends State<MaestroColorfulSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => CustomPaint(
            painter: _ColorfulSpinnerPainter(
              progresso: _controller.value,
              strokeWidth: widget.strokeWidth,
              trackColor: widget.trackColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorfulSpinnerPainter extends CustomPainter {
  final double progresso;
  final double strokeWidth;
  final Color trackColor;

  _ColorfulSpinnerPainter({
    required this.progresso,
    required this.strokeWidth,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final raio = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: centro, radius: raio);

    canvas.drawCircle(
      centro,
      raio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );

    final cores = List<Color>.generate(7, (i) {
      final hue = ((i * 360 / 6) + progresso * 360) % 360;
      return HSVColor.fromAHSV(1, hue, 0.82, 1).toColor();
    });

    final shader = SweepGradient(
      colors: cores,
      transform: GradientRotation(progresso * 2 * math.pi - math.pi / 2),
    ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 1.65,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _ColorfulSpinnerPainter oldDelegate) =>
      oldDelegate.progresso != progresso ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.trackColor != trackColor;
}
