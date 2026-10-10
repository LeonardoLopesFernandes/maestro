import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renderiza um ícone que pode ser vetorial (`.svg`) ou raster
/// (`.webp`/`.png`), aplicando cor por tint quando informada.
Widget appIcon(
  String path, {
  double? width,
  double? height,
  Color? color,
}) {
  if (path.endsWith('.svg')) {
    return SvgPicture.asset(
      path,
      width: width,
      height: height,
      fit: BoxFit.contain,
      colorFilter:
          color == null ? null : ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
  return Image.asset(
    path,
    width: width,
    height: height,
    color: color,
    colorBlendMode: BlendMode.srcIn,
  );
}
