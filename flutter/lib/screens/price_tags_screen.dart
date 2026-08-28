import 'package:flutter/material.dart';
import '../network/api_service.dart';
import '../network/session_manager.dart';
import '../utils/constants.dart';

class PriceTagsScreen extends StatefulWidget {
  final SessionManager session;
  final ApiService apiService;

  const PriceTagsScreen(
      {super.key, required this.session, required this.apiService});

  @override
  State<PriceTagsScreen> createState() => _PriceTagsScreenState();
}

class _PriceTagsScreenState extends State<PriceTagsScreen> {
  Map<String, dynamic> _summary = {};
  List<dynamic> _tags = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final loja = widget.session.getUserStore() ?? Constants.defaultStore;
    try {
      final s = await widget.apiService.getPriceTagSummary(loja);
      final t = await widget.apiService.getPriceTags(loja);
      if (mounted) {
        setState(() {
          _summary = s;
          _tags = (t['data'] ?? t['tags'] ?? t['pedidos'] ?? []) as List<dynamic>;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _enviar(dynamic tag) async {
    final loja = widget.session.getUserStore() ?? Constants.defaultStore;
    final printerId = '1';
    final tagId = (tag is Map ? tag['_id'] ?? tag['id'] : tag)?.toString() ?? '';
    try {
      await widget.apiService.sendPriceTags(loja, printerId, tagId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Enviado para impressora')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(Constants.RED_600),
        title: const Text('Etiquetas de Preço'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _carregar),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_summary.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Resumo: ${_summary.toString().replaceAll(RegExp(r'[{}]'), '')}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _tags.isEmpty
                      ? const Center(
                          child: Text('Nenhuma etiqueta pendente.',
                              style: TextStyle(color: Color(Constants.GRAY_400))))
                      : ListView.builder(
                          itemCount: _tags.length,
                          itemBuilder: (_, i) {
                            final tag = _tags[i];
                            final title = tag is Map
                                ? (tag['titulo'] ??
                                    tag['descricao'] ??
                                    tag['numero'] ??
                                    tag['codigoExterno'] ??
                                    'Item $i')
                                .toString()
                                : tag.toString();
                            return ListTile(
                              title: Text(title),
                              subtitle: tag is Map
                                  ? Text(tag.toString()
                                      .replaceAll(RegExp(r'[{}]'), ''))
                                  : null,
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(Constants.BLUE_500)),
                                onPressed: () => _enviar(tag),
                                child: const Text('Enviar',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
