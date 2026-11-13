import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/pedido.dart';
import '../services/americanas_bff.dart';
import '../services/image_search_api.dart';
import '../services/serp_api_image_search.dart';
import '../services/si5_image_search.dart';
import '../utils/constants.dart';

/// Abre a imagem do produto do pedido em tela cheia.
///
/// Usa primeiro a URL (`urlImagem`) devolvida pelo pedido. Quando o pedido não
/// tem arquivo de imagem, mantém a busca pelas APIs da Americanas/SI5/etc.
Future<void> mostrarImagemProduto(
  BuildContext context, {
  required Item item,
  required String loja,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.white,
      child: _ProdutoImagemDialog(
        item: item,
        loja: loja.trim().isEmpty ? Constants.defaultStore : loja.trim(),
      ),
    ),
  );
}

class _ProdutoImagemDialog extends StatefulWidget {
  final Item item;
  final String loja;

  const _ProdutoImagemDialog({required this.item, required this.loja});

  @override
  State<_ProdutoImagemDialog> createState() => _ProdutoImagemDialogState();
}

class _ProdutoImagemDialogState extends State<_ProdutoImagemDialog> {
  String? _url;
  bool _carregando = true;
  bool _tentouFallback = false;

  @override
  void initState() {
    super.initState();
    final direta = (widget.item.urlImagem ?? '').trim();
    if (direta.isNotEmpty) {
      _url = _urlAltaResolucao(direta);
      _carregando = false;
      _tentouFallback = true;
    } else {
      _buscarNasApis();
    }
  }

  /// A resposta do pedido traz a imagem em miniatura (`-88-88`). Troca para
  /// uma versão grande da mesma imagem no VTEX para não pixelar na tela.
  String _urlAltaResolucao(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.contains('vteximg.com.br')) return url;
    final path = uri.path.replaceFirst(
      RegExp(r'-\d+-\d+(?=/)'),
      '-1000-1000',
    );
    return uri.replace(path: path).toString();
  }

  Future<void> _buscarNasApis() async {
    final ean = (widget.item.codigoEAN ?? '').trim();
    final descricao = (widget.item.descricao ?? '').trim();
    String? url;

    // 1) API da Americanas (BFF) — imagem oficial.
    if (ean.isNotEmpty) {
      try {
        final produto = await AmericanasBff.getProduct(ean, store: widget.loja);
        final u = produto.imageUrl?.trim();
        if (u != null && u.isNotEmpty) url = u;
      } catch (_) {}
    }

    // 2) SI5 Global (secundária) — imagem por EAN.
    if (url == null && ean.isNotEmpty) {
      try {
        final u = await Si5ImageSearch.searchByEan(ean);
        if (u != null && u.isNotEmpty) url = u;
      } catch (_) {}
    }

    // 3) API de busca de imagem: Bluesoft + Google Images.
    if (url == null && ean.isNotEmpty) {
      try {
        final u = await SerpApiImageSearch.searchImageByEan(ean, descricao);
        if (u != null && u.isNotEmpty) url = u;
      } catch (_) {}
    }

    // 4) ImageSearchApi (Google Shopping) — descrição ou EAN.
    if (url == null) {
      final query = descricao.isNotEmpty ? descricao : ean;
      if (query.isNotEmpty) {
        try {
          final resultados = await ImageSearchApi.searchByText(query);
          for (final r in resultados) {
            if (r.imageUrl.trim().isNotEmpty) {
              url = r.imageUrl.trim();
              break;
            }
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _url = url == null ? null : _urlAltaResolucao(url);
      _carregando = false;
    });
  }

  void _tentarFallback() {
    if (_tentouFallback) return;
    _tentouFallback = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buscarNasApis();
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final descricao = (item.descricao ?? '').trim();

    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close,
                            size: 18, color: Color(0xFF6B7280)),
                        SizedBox(width: 8),
                        Text('FECHAR',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (descricao.isNotEmpty)
                      Text(
                        descricao,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                            height: 1.3),
                      ),
                    const SizedBox(height: 16),
                    _imagem(context),
                    if (item.estoque != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F4E8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Estoque estimado: ${item.estoque}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      'Informações do produto no SAP',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(height: 10),
                    if (descricao.isNotEmpty) ...[
                      Text(
                        descricao,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF555555),
                            height: 1.4),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if ((item.codigoSAP ?? '').trim().isNotEmpty)
                      _linhaInfo('Código SAP', item.codigoSAP!.trim()),
                    if ((item.codigoEAN ?? '').trim().isNotEmpty)
                      _linhaInfo(
                          'EAN de venda (SAP)', item.codigoEAN!.trim()),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 14),
                    const Text(
                      'Outros EANs',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(height: 8),
                    ..._outrosEans(item),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagem(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final altura = math.min(largura * 0.9, 460.0);
    return Center(
      child: SizedBox(
        width: double.infinity,
        height: altura,
        child: _conteudoImagem(),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: _salvarImagemComConfirmacao,
      child: Image.network(
        _url!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (_, __, ___) {
          if (!_tentouFallback) {
            _tentarFallback();
            return const Center(child: CircularProgressIndicator());
          }
          return const Center(
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
          );
        },
      ),
    );
  }

  Future<void> _salvarImagemComConfirmacao() async {
    final url = _url;
    if (url == null || url.isEmpty) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Salvar imagem'),
        content: const Text('Deseja salvar a imagem em Download/Maestro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE60000),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('SALVAR'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final nome = _nomeArquivoImagem(url);
      await const MethodChannel('io.maestro/media').invokeMethod(
        'saveToDownloads',
        {
          'fileName': nome,
          'mimeType': _mimeImagem(url),
          'bytes': resp.bodyBytes,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Imagem salva em Download/Maestro',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar imagem: $e')),
      );
    }
  }

  String _nomeArquivoImagem(String url) {
    final uri = Uri.tryParse(url);
    var ext = 'jpg';
    if (uri != null) {
      final path = uri.path.toLowerCase();
      for (final e in const ['jpg', 'jpeg', 'png', 'webp']) {
        if (path.endsWith('.$e')) {
          ext = e == 'jpeg' ? 'jpg' : e;
          break;
        }
      }
    }
    final ean = (widget.item.codigoEAN ?? '').replaceAll(RegExp(r'\D'), '');
    final base = ean.isNotEmpty ? ean : 'produto';
    return 'maestro_${base}_${DateTime.now().millisecondsSinceEpoch}.$ext';
  }

  String _mimeImagem(String url) {
    final path = url.toLowerCase();
    if (path.contains('.png')) return 'image/png';
    if (path.contains('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  List<Widget> _outrosEans(Item item) {
    final lista = <EanSecundario>[];
    if (item.eansSecundarios.isNotEmpty) {
      lista.addAll(item.eansSecundarios);
    } else {
      lista.addAll(item.eans
          .where((e) => e.trim().isNotEmpty)
          .map((e) => EanSecundario(numero: e, tipo: '')));
    }
    if (lista.isEmpty) {
      return const [
        Text('Nenhum EAN informado.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
      ];
    }
    return lista
        .where((e) => e.numero.trim().isNotEmpty)
        .map((e) => _linhaInfo(_labelEan(e.tipo), e.numero.trim()))
        .toList();
  }

  String _labelEan(String tipo) {
    final t = tipo.toUpperCase();
    if (t.contains('DISTRIB')) return 'EAN unidade de distribuição';
    if (t.contains('VENDA')) return 'EAN unidade de venda';
    return 'EAN';
  }

  Widget _linhaInfo(String label, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF666666)),
              ),
              TextSpan(
                text: valor,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF1A1A1A)),
              ),
            ],
          ),
        ),
      );
}
