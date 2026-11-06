import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_drawing/path_drawing.dart';

/// Logo "m" do maestro desenhado por traço e depois preenchido.
class MaestroLogoDraw extends StatefulWidget {
  final double size;
  final Color color;

  const MaestroLogoDraw({
    super.key,
    this.size = 140,
    this.color = Colors.white,
  });

  @override
  State<MaestroLogoDraw> createState() => _MaestroLogoDrawState();
}

class _MaestroLogoDrawState extends State<MaestroLogoDraw>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Path? _path;
  late List<PathMetric> _metrics;
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _metrics = const [];
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
    _load();
  }

  Future<void> _load() async {
    try {
      final svg = await rootBundle.loadString('assets/icons/maestro_m.svg');
      final match =
          RegExp(r'<path[^>]*d="([^"]+)"').firstMatch(svg);
      if (match == null) return;
      final path = parseSvgPathData(match.group(1)!);
      final matrix = Matrix4.identity()
        ..translateByDouble(0, 269, 0, 1)
        ..scaleByDouble(0.1, -0.1, 1, 1);
      path.transform(matrix.storage);
      path.fillType = PathFillType.evenOdd;
      final metrics = path.computeMetrics().toList();
      final total = metrics.fold<double>(0, (s, m) => s + m.length);
      if (!mounted) return;
      setState(() {
        _path = path;
        _metrics = metrics;
        _total = total;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final drawP = (_c.value / 0.85).clamp(0.0, 1.0);
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _MaestroLogoPainter(
            path: _path,
            metrics: _metrics,
            total: _total,
            drawP: drawP,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _MaestroLogoPainter extends CustomPainter {
  final Path? path;
  final List<PathMetric> metrics;
  final double total;
  final double drawP;
  final Color color;

  _MaestroLogoPainter({
    required this.path,
    required this.metrics,
    required this.total,
    required this.drawP,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = path;
    if (p == null || total <= 0) return;
    final bounds = p.getBounds();
    final s = math.min(size.width / bounds.width, size.height / bounds.height);
    final dx = (size.width - bounds.width * s) / 2 - bounds.left * s;
    final dy = (size.height - bounds.height * s) / 2 - bounds.top * s;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(s);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    var restante = total * drawP;
    for (final m in metrics) {
      if (restante >= m.length) {
        canvas.drawPath(p, fill);
      }
      if (restante > 0) {
        final l = math.min(m.length, restante);
        canvas.drawPath(m.extractPath(0, l), stroke);
        restante -= l;
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MaestroLogoPainter old) =>
      old.drawP != drawP || old.color != color || old.path != path;
}
