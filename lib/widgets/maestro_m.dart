import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// "m" vetorial do maestro, revelado verticalmente conforme o progresso.
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
    this.height = 84,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: p,
          child: SvgPicture.asset(
            'assets/icons/maestro_m.svg',
            width: width,
            height: height,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
