import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Três pontos em movimento horizontal, equivalente ao SVG 3-dots-move.
class MaestroDotsLoading extends StatefulWidget {
  final double width;
  final double height;
  final Color color;

  const MaestroDotsLoading({
    super.key,
    this.width = 42,
    this.height = 12,
    this.color = const Color(0xFFFF0000),
  });

  @override
  State<MaestroDotsLoading> createState() => _MaestroDotsLoadingState();
}

class _MaestroDotsLoadingState extends State<MaestroDotsLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: _DotsPainter(
            progresso: _controller.value,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final double progresso;
  final Color color;

  _DotsPainter({required this.progresso, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final raio = size.height * 0.22;
    final esquerda = raio;
    final direita = size.width - raio;
    final centroY = size.height / 2;
    const quantidade = 3;

    for (var i = 0; i < quantidade; i++) {
      final u = (progresso + i / quantidade) % 1.0;
      final x = esquerda + (direita - esquerda) * u;
      final fade = u < 0.14
          ? u / 0.14
          : u > 0.86
              ? (1 - u) / 0.14
              : 1.0;
      final escala = 0.72 + 0.28 * math.sin(math.pi * u);
      canvas.drawCircle(
        Offset(x, centroY),
        raio * escala,
        Paint()
          ..color =
              color.withValues(alpha: fade.clamp(0.0, 1.0).toDouble()),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter oldDelegate) =>
      oldDelegate.progresso != progresso || oldDelegate.color != color;
}
