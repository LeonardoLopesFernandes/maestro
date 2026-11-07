import 'package:flutter/material.dart';
import 'colorful_spinner.dart';

/// Pull-to-refresh do maestro: enquanto puxa, o "m" é desenhado.
class MaestroRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color cor;

  const MaestroRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.cor = const Color(0xFFE60000),
  });

  @override
  State<MaestroRefresh> createState() => _MaestroRefreshState();
}

class _MaestroRefreshState extends State<MaestroRefresh>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _acumulado = 0;
  bool _atualizando = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _definirProgresso(double progresso) {
    final p = progresso.clamp(0.0, 1.0);
    if ((p - _controller.value).abs() < 0.005) return;
    _controller.value = p;
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || _atualizando) return false;

    if (n is ScrollStartNotification) {
      _acumulado = 0;
      _definirProgresso(0);
    } else if (n is OverscrollNotification && n.overscroll < 0) {
      _acumulado += -n.overscroll;
      _definirProgresso(_acumulado / 90);
    } else if (n is ScrollUpdateNotification && n.metrics.pixels < 0) {
      _definirProgresso(-n.metrics.pixels / 90);
    } else if (n is ScrollEndNotification) {
      _acumulado = 0;
      _definirProgresso(0);
    }
    return false;
  }

  Future<void> _atualizar() async {
    _atualizando = true;
    _acumulado = 0;
    await _controller.animateTo(
      1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    try {
      await widget.onRefresh();
    } finally {
      _atualizando = false;
      await _controller.animateBack(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator.noSpinner(
          onRefresh: _atualizar,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.child,
          ),
        ),
        Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final p = _controller.value;
                if (p < 0.01) return const SizedBox.shrink();
                return Opacity(
                  opacity: p.clamp(0.0, 1.0),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: MaestroColorfulSpinner(
                        size: 42,
                        strokeWidth: 4,
                        trackColor: const Color(0xFFE6E6E6),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
