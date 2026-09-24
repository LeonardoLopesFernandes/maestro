import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../network/api_service.dart';
import '../network/session_manager.dart';
import '../utils/constants.dart';

class VisualizarDanfeScreen extends StatefulWidget {
  final SessionManager session;
  final ApiService apiService;
  final String chave;
  final String? url;

  const VisualizarDanfeScreen({
    super.key,
    required this.session,
    required this.apiService,
    required this.chave,
    this.url,
  });

  @override
  State<VisualizarDanfeScreen> createState() => _VisualizarDanfeScreenState();
}

class _VisualizarDanfeScreenState extends State<VisualizarDanfeScreen> {
  Uint8List? _bytes;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  String get _danfeUrl {
    final u = widget.url;
    if (u != null && u.trim().isNotEmpty) return u.trim();
    // Host externo (inventti/lasa) que disponibiliza o PDF da DANFE pela chave
    return 'https://lasa.inventti.app/nfe/api/pdf/DanfeEmissao?chave=${widget.chave}';
  }

  Future<void> _carregar() async {
    try {
      final b = await widget.apiService.getDanfeUrl(_danfeUrl);
      if (mounted) setState(() => _bytes = b);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(Constants.RED_600),
        automaticallyImplyLeading: false,
        title: const Text('NOTA FISCAL',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(child: Text('Erro: $_erro'))
              : _bytes == null
                  ? const Center(child: Text('Sem dados.'))
                  : PdfPreview(
                      allowPrinting: true,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      pdfFileName: 'danfe_${widget.chave}.pdf',
                      build: (_) async => _bytes!,
                    ),
    );
  }
}
