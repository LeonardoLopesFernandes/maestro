import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Desenha o "m" minúsculo do maestro conforme o progresso informado.
class MaestroMDraw extends StatelessWidget {
  final double progress;
  final Color color;
  final double width;
  final double height;

  const MaestroMDraw({
    super.key,
    required this.progress,
    this.color = Colors.white,
    this.width = 120,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _MaestroMPainter(progress, color),
      ),
    );
  }
}

class _MaestroMPainter extends CustomPainter {
  final double progress;
  final Color color;

  _MaestroMPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    canvas.save();
    canvas.scale(size.width / 120, size.height / 100);

    final path = Path()
      ..moveTo(18, 84)
      ..lineTo(18, 44)
      ..cubicTo(18, 14, 52, 14, 52, 44)
      ..lineTo(52, 84)
      ..moveTo(52, 44)
      ..cubicTo(52, 14, 86, 14, 86, 44)
      ..lineTo(86, 84);

    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    var restante = total * progress.clamp(0.0, 1.0);

    final glow = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 27
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    ui.Offset? ponta;
    for (final metric in metrics) {
      if (restante <= 0) break;
      final desenhar = restante < metric.length ? restante : metric.length;
      final trecho = metric.extractPath(0, desenhar);
      canvas.drawPath(trecho, glow);
      canvas.drawPath(trecho, stroke);
      ponta = metric.getTangentForOffset(desenhar)?.position;
      restante -= desenhar;
    }

    if (ponta != null && progress < 1) {
      canvas.drawCircle(
        ponta,
        8,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
      );
      canvas.drawCircle(ponta, 4, Paint()..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MaestroMPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
