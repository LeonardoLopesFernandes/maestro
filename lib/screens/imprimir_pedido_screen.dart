import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/pedido.dart';

final Map<String, Uint8List?> _cacheImagensPedido = {};

class ImprimirPedidoScreen extends StatelessWidget {
  final Pedido pedido;

  const ImprimirPedidoScreen({super.key, required this.pedido});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE30613),
        foregroundColor: Colors.white,
        title: const Text('Imprimir pedido'),
      ),
      body: PdfPreview(
        allowPrinting: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: 'pedido_${pedido.codigoExterno}.pdf',
        build: _gerarPdf,
      ),
    );
  }

  Future<Uint8List> _gerarPdf(PdfPageFormat format) async {
    final doc = pw.Document();
    final qrData = _qrData();
    final logoBytes = await rootBundle
        .load('assets/icons/americanas_logo.jpg')
        .then((bd) => bd.buffer.asUint8List());
    final imagens = await Future.wait(pedido.itens.map(_carregarImagemItem));
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          _cabecalho(logoBytes),
          pw.SizedBox(height: 22),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 3, child: _dadosPedido()),
              pw.SizedBox(width: 24),
              pw.Expanded(flex: 2, child: _blocoQr(qrData)),
            ],
          ),
          pw.SizedBox(height: 24),
          _linhaCorte(),
          pw.SizedBox(height: 20),
          pw.Text(
            pedido.codigoExterno,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 14),
          _itensPedido(imagens),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _cabecalho(Uint8List logoBytes) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Image(
          pw.MemoryImage(logoBytes),
          height: 46,
          fit: pw.BoxFit.contain,
        ),
        pw.Text(
          pedido.codigoExterno,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  pw.Widget _dadosPedido() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _linhaInfo('Canal de venda', _canalLabel()),
        _linhaInfo('Modalidade de entrega', _modalidade()),
        _linhaInfo(
          'Criação do pedido',
          _formatarDataHora(pedido.dataCriacao ?? pedido.dataInclusao),
        ),
        _linhaInfo(
            'Entrega estimada', _formatarDataHora(pedido.dhEntregaEstimada)),
        _linhaInfo('Nome do cliente', pedido.cliente?.nome ?? '-'),
        _linhaInfo(
          'Nome do recebedor',
          pedido.recebedor?.nome ?? pedido.cliente?.nome ?? '-',
        ),
        _linhaInfo('Endereço', _enderecoCompleto()),
      ],
    );
  }

  pw.Widget _linhaInfo(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.TextSpan(
              text: valor,
              style: const pw.TextStyle(fontSize: 9.5),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _blocoQr(String? qrData) {
    final inicial = _inicialCliente();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (inicial.isNotEmpty) ...[
          pw.Text(
            inicial,
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
        ],
        if (qrData != null)
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: qrData,
            width: 118,
            height: 118,
          )
        else
          pw.Container(
            width: 118,
            height: 118,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Text(
              'Nota fiscal\nnão disponível',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
          ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Escaneie o código acima para acessar a Nota Fiscal.',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  pw.Widget _linhaCorte() {
    return pw.Column(
      children: [
        pw.Row(
          children: [
            pw.Expanded(child: _tracejado()),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10),
              child: pw.Text(
                'RECORTE',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                ),
              ),
            ),
            pw.Expanded(child: _tracejado()),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Recorte aqui! A parte inferior não deve ser disponibilizada para o cliente/entregador.',
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _tracejado() {
    return pw.Row(
      children: List.generate(
        28,
        (_) => pw.Container(
          width: 5,
          height: 0.8,
          margin: const pw.EdgeInsets.only(right: 3),
          color: PdfColors.grey500,
        ),
      ),
    );
  }

  pw.Widget _itensPedido(List<Uint8List?> imagens) {
    if (pedido.itens.isEmpty) {
      return pw.Text(
        'Nenhum item no pedido.',
        style: const pw.TextStyle(fontSize: 9),
      );
    }
    return pw.Wrap(
      spacing: 12,
      runSpacing: 18,
      children: List.generate(pedido.itens.length, (i) {
        final item = pedido.itens[i];
        final bytes = i < imagens.length ? imagens[i] : null;
        return pw.SizedBox(
          width: 160,
          child: _cardItem(item, bytes),
        );
      }),
    );
  }

  pw.Widget _cardItem(Item item, Uint8List? imagem) {
    final ean = _eanPrincipal(item);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 22,
              child: pw.Text(
                '${item.quantidadeEfetiva}x',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Container(
              width: 72,
              height: 72,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(2),
              ),
              child: imagem == null
                  ? pw.Text(
                      'sem\nimagem',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey500,
                      ),
                    )
                  : pw.Image(
                      pw.MemoryImage(imagem),
                      width: 66,
                      height: 66,
                      fit: pw.BoxFit.contain,
                    ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          item.descricao ?? '',
          style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.5),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'EAN: ${ean.isEmpty ? '---' : ean}',
          style: const pw.TextStyle(fontSize: 8.5),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Estoque estimado: ${item.estoque ?? 0}',
          style: const pw.TextStyle(fontSize: 8.5),
        ),
      ],
    );
  }

  String _eanPrincipal(Item item) {
    final principal = (item.codigoEAN ?? '').trim();
    if (principal.isNotEmpty) return principal;
    for (final ean in item.eans) {
      final valor = ean.trim();
      if (valor.isNotEmpty) return valor;
    }
    return '';
  }

  Future<Uint8List?> _carregarImagemItem(Item item) async {
    final url = _urlImagemAlta((item.urlImagem ?? '').trim());
    if (url.isEmpty) return null;
    if (_cacheImagensPedido.containsKey(url)) {
      return _cacheImagensPedido[url];
    }
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: const {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 12));
      final bytes = response.bodyBytes;
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          _imagemSuportada(bytes)) {
        _cacheImagensPedido[url] = bytes;
        return bytes;
      }
    } catch (_) {
      // Imagem indisponível: o item continua sendo impresso.
    }
    _cacheImagensPedido[url] = null;
    return null;
  }

  bool _imagemSuportada(Uint8List bytes) {
    if (bytes.length < 8) return false;
    final png = bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final jpeg = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    return png || jpeg;
  }

  String _urlImagemAlta(String url) {
    var valor = url.trim();
    if (valor.startsWith('//')) {
      valor = 'https:$valor';
    } else if (valor.startsWith('http://')) {
      valor = 'https://${valor.substring(7)}';
    }
    final uri = Uri.tryParse(valor);
    if (uri == null || !uri.host.contains('vteximg.com.br')) return valor;
    final path = uri.path.replaceFirst(
      RegExp(r'-\d+-\d+(?=/)'),
      '-1000-1000',
    );
    return uri.replace(path: path).toString();
  }

  String _canalLabel() {
    final canal = (pedido.canalDeVendas ?? '').toUpperCase();
    if (canal.contains('IFOOD')) return 'iFood';
    if (canal.contains('AMERICANAS')) return 'Americanas';
    if (canal.contains('MAGAZINE')) return 'Magazine';
    final nome = pedido.canalDeVendas?.trim() ?? '';
    return nome.isEmpty ? 'Delivery' : nome;
  }

  String _modalidade() {
    final tipo = (pedido.tipoEntrega ?? '').toUpperCase();
    if (tipo.contains('EXTERNA')) return 'delivery';
    if (tipo.contains('RETIRADA')) return 'pegue na loja hoje';
    final valor = pedido.tipoEntrega?.trim() ?? '';
    return valor.isEmpty ? 'delivery' : valor.toLowerCase();
  }

  String _inicialCliente() {
    final nome = pedido.cliente?.nome?.trim() ?? '';
    if (nome.isEmpty) return '';
    return nome.substring(0, 1).toUpperCase();
  }

  String _formatarDataHora(String? data) {
    if (data == null || data.trim().isEmpty) return '-';
    final dt = DateTime.tryParse(data)?.toLocal();
    if (dt == null) return data;
    final p = (int v) => v.toString().padLeft(2, '0');
    return '${p(dt.day)}/${p(dt.month)}/${dt.year} - '
        '${p(dt.hour)}h${p(dt.minute)}';
  }

  String _enderecoCompleto() {
    final c = pedido.cliente;
    if (c == null) return '-';
    final b = StringBuffer();
    if ((c.endereco ?? '').isNotEmpty) b.write(c.endereco);
    if ((c.numero ?? '').isNotEmpty) b.write(', ${c.numero}');
    if ((c.complemento ?? '').isNotEmpty) b.write(' - ${c.complemento}');
    if ((c.bairro ?? '').isNotEmpty) b.write(', ${c.bairro}');
    if ((c.cidade ?? '').isNotEmpty) b.write(', ${c.cidade}');
    if ((c.uf ?? '').isNotEmpty) b.write(' - ${c.uf}');
    if ((c.cep ?? '').isNotEmpty) b.write(' CEP ${c.cep}');
    final endereco = b.toString().trim();
    return endereco.isEmpty ? '-' : endereco;
  }

  String? _qrData() {
    final url = pedido.notaFiscalUrl?.trim() ?? '';
    if (url.isNotEmpty) return url;
    final chave = pedido.notaFiscalChave?.trim() ?? '';
    if (chave.isNotEmpty) {
      return 'https://lasa.inventti.app/nfe/api/pdf/DanfeEmissao?chave=$chave';
    }
    return null;
  }
}
