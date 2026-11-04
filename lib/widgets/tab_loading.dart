import 'package:flutter/material.dart';
import 'app_icon.dart';

/// Loading interno de cada aba: mostra o ícone e a cor da aba ativa.
class MaestroTabLoading extends StatelessWidget {
  final String iconAsset;
  final Color cor;
  final String titulo;

  const MaestroTabLoading({
    super.key,
    required this.iconAsset,
    required this.cor,
    this.titulo = '',
  });

  @override
  Widget build(BuildContext context) {
    final texto = titulo.isEmpty ? 'Carregando pedidos...' : 'Carregando $titulo...';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(22),
            child: appIcon(iconAsset, width: 48, height: 48, color: cor),
          ),
          const SizedBox(height: 16),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF616161),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 132,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: cor.withValues(alpha: 0.16),
                valueColor: AlwaysStoppedAnimation<Color>(cor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
