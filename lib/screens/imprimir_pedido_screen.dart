import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/pedido.dart';

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
          _itensPedido(),
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
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Pedido via ${_canalLabel()}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              pedido.codigoExterno,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _dadosPedido() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _linhaInfo('Modalidade de entrega', _modalidade()),
        _linhaInfo(
          'Criação do pedido',
          _formatarData(pedido.dataCriacao ?? pedido.dataInclusao),
        ),
        _linhaInfo('Entrega estimada', _formatarData(pedido.dhEntregaEstimada)),
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

  pw.Widget _itensPedido() {
    if (pedido.itens.isEmpty) {
      return pw.Text(
        'Nenhum item no pedido.',
        style: const pw.TextStyle(fontSize: 9),
      );
    }
    return pw.Wrap(
      spacing: 16,
      runSpacing: 8,
      children: pedido.itens.map((item) {
        return pw.SizedBox(
          width: 250,
          child: pw.Text(
            _textoItem(item),
            style: const pw.TextStyle(
              fontSize: 8.5,
              lineSpacing: 2,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _textoItem(Item item) {
    final eans = <String>{};
    final principal = (item.codigoEAN ?? '').trim();
    if (principal.isNotEmpty) eans.add(principal);
    for (final ean in item.eans) {
      final valor = ean.trim();
      if (valor.isNotEmpty) eans.add(valor);
    }
    final sufixo = eans.isEmpty ? '' : ' (EAN: ${eans.join(' ou ')})';
    return '${item.quantidadeEfetiva}x ${item.descricao ?? ''}$sufixo';
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
    if (tipo.contains('RETIRADA')) return 'retirada';
    final valor = pedido.tipoEntrega?.trim() ?? '';
    return valor.isEmpty ? 'delivery' : valor.toLowerCase();
  }

  String _inicialCliente() {
    final nome = pedido.cliente?.nome?.trim() ?? '';
    if (nome.isEmpty) return '';
    return nome.substring(0, 1).toUpperCase();
  }

  String _formatarData(String? data) {
    if (data == null || data.trim().isEmpty) return '-';
    final dt = DateTime.tryParse(data)?.toLocal();
    if (dt == null) return data;
    final p = (int v) => v.toString().padLeft(2, '0');
    return '${p(dt.day)}/${p(dt.month)}/${dt.year}';
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
