import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/americanas_bff.dart';
import '../services/image_search_api.dart';
import '../services/serp_api_image_search.dart';
import '../utils/constants.dart';

/// Abre o diálogo grande com a imagem do produto do pedido.
///
/// Busca primeiro na API da Americanas (BFF) pelo EAN e, se não houver imagem,
/// cai na API de busca de imagem (Bluesoft/Google Images) usada no consultor
/// de preço. Sem EAN, tenta pela descrição.
Future<void> mostrarImagemProduto(
  BuildContext context, {
  required String ean,
  required String descricao,
  required String loja,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ProdutoImagemDialog(
      ean: ean.trim(),
      descricao: descricao.trim(),
      loja: loja.trim().isEmpty ? Constants.defaultStore : loja.trim(),
    ),
  );
}

class _ProdutoImagemDialog extends StatefulWidget {
  final String ean;
  final String descricao;
  final String loja;

  const _ProdutoImagemDialog({
    required this.ean,
    required this.descricao,
    required this.loja,
  });

  @override
  State<_ProdutoImagemDialog> createState() => _ProdutoImagemDialogState();
}

class _ProdutoImagemDialogState extends State<_ProdutoImagemDialog> {
  String? _url;
  String? _fonte;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    String? url;
    String? fonte;

    // 1) API da Americanas (BFF) — imagem oficial.
    if (widget.ean.isNotEmpty) {
      try {
        final produto =
            await AmericanasBff.getProduct(widget.ean, store: widget.loja);
        final u = produto.imageUrl?.trim();
        if (u != null && u.isNotEmpty) {
          url = u;
          fonte = 'Americanas';
        }
      } catch (_) {}
    }

    // 2) API de busca de imagem: Bluesoft + Google Images.
    if (url == null && widget.ean.isNotEmpty) {
      try {
        final u = await SerpApiImageSearch.searchImageByEan(
            widget.ean, widget.descricao);
        if (u != null && u.isNotEmpty) {
          url = u;
          fonte = 'Bluesoft / Google Imagens';
        }
      } catch (_) {}
    }

    // 3) ImageSearchApi (Google Shopping) — descrição ou EAN.
    if (url == null) {
      final query =
          widget.descricao.isNotEmpty ? widget.descricao : widget.ean;
      if (query.isNotEmpty) {
        try {
          final resultados = await ImageSearchApi.searchByText(query);
          for (final r in resultados) {
            if (r.imageUrl.trim().isNotEmpty) {
              url = r.imageUrl.trim();
              fonte = 'ImageSearchApi';
              break;
            }
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _url = url;
      _fonte = fonte;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final alturaImagem = math.min(size.height * 0.52, 440.0);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: size.height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.image_outlined,
                      color: Color(Constants.RED_600)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Imagem do produto',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              if (widget.descricao.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                  child: Text(
                    widget.descricao,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              if (widget.ean.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'EAN: ${widget.ean}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(Constants.MEDIUM_TEXT)),
                  ),
                ),
              const SizedBox(height: 12),
              Flexible(
                child: SizedBox(
                  height: alturaImagem,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: const Color(0xFFF8FAFC),
                      child: _conteudoImagem(),
                    ),
                  ),
                ),
              ),
              if (_fonte != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Fonte: $_fonte',
                    style: const TextStyle(
                        fontSize: 10, color: Color(Constants.GRAY_400)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conteudoImagem() {
    if (_carregando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Buscando imagem...',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      );
    }
    if (_url == null || _url!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 42, color: Color(0xFF9CA3AF)),
            SizedBox(height: 10),
            Text('Imagem não encontrada',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ),
      );
    }
    return Image.network(
      _url!,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (_, __, ___) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined,
                size: 42, color: Color(0xFF9CA3AF)),
            SizedBox(height: 10),
            Text('Não foi possível carregar a imagem',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}
