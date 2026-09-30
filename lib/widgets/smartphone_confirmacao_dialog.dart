import 'package:flutter/material.dart';
import '../models/pedido.dart';
import '../screens/scanner_imei_screen.dart';

class SmartphoneConfirmacaoDialog extends StatefulWidget {
  final Pedido pedido;
  final void Function(Map<String, int> quantidades, Map<String, List<String>> imeis)
      onConfirm;
  final VoidCallback onCancel;

  const SmartphoneConfirmacaoDialog({
    super.key,
    required this.pedido,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<SmartphoneConfirmacaoDialog> createState() =>
      _SmartphoneConfirmacaoDialogState();
}

class _SmartphoneConfirmacaoDialogState
    extends State<SmartphoneConfirmacaoDialog> {
  int _screen = 1;
  final Map<String, int> _qtd = {};
  final Map<String, TextEditingController> _qtyCtrls = {};
  final Map<String, List<TextEditingController>> _imeiCtrls = {};

  List<Item> get _itens =>
      widget.pedido.itens?.where((i) => i.quantidadeImeis > 0).toList() ??
      const [];

  String _key(Item i) => i.codigoSAP ?? i.codigoEAN ?? i.descricao ?? '';

  @override
  void initState() {
    super.initState();
    for (final it in _itens) {
      final k = _key(it);
      _qtd[k] = it.quantidade;
      _qtyCtrls[k] =
          TextEditingController(text: it.quantidade.toString());
      _ensureImeiCtrls(k, it, it.quantidade);
    }
  }

  @override
  void dispose() {
    for (final c in _qtyCtrls.values) c.dispose();
    for (final l in _imeiCtrls.values) {
      for (final c in l) c.dispose();
    }
    super.dispose();
  }

  void _ensureImeiCtrls(String k, Item it, int qtd) {
    final count = qtd * it.quantidadeImeis;
    final list = _imeiCtrls.putIfAbsent(k, () => []);
    while (list.length < count) list.add(TextEditingController());
    while (list.length > count) {
      list.last.dispose();
      list.removeLast();
    }
  }

  List<String> _imeisOf(String k) =>
      _imeiCtrls[k]?.map((c) => c.text.trim()).toList() ?? [];

  Future<void> _scan() async {
    final imei = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const ScannerImeiScreen()));
    if (imei == null || imei.isEmpty) return;
    for (final k in _imeiCtrls.keys) {
      for (final c in _imeiCtrls[k]!) {
        if (c.text.trim().isEmpty) {
          c.text = imei;
          setState(() {});
          return;
        }
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não há campos de IMEI livres')),
    );
  }

  bool _validar() {
    for (final it in _itens) {
      final k = _key(it);
      final q = _qtd[k] ?? 0;
      if (q <= 0) {
        _snack('Quantidade inválida para ${it.descricao ?? ''}');
        return false;
      }
      final total = q * it.quantidadeImeis;
      final imeis = _imeisOf(k);
      if (imeis.length < total || imeis.any((e) => e.isEmpty)) {
        _snack('IMEI obrigatório para ${it.descricao ?? ''}');
        return false;
      }
      if (imeis.any((e) => e.length < 15)) {
        _snack('IMEI inválido para ${it.descricao ?? ''}');
        return false;
      }
    }
    return true;
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _confirmar() {
    if (!_validar()) return;
    final imeis = <String, List<String>>{};
    for (final it in _itens) {
      imeis[_key(it)] = _imeisOf(_key(it));
    }
    Navigator.of(context).pop();
    widget.onConfirm(Map.from(_qtd), imeis);
  }

  void _onQtdChanged(String k, Item it, String text) {
    final nova = int.tryParse(text) ?? 0;
    final clamped = nova > it.quantidade ? it.quantidade : nova;
    _qtd[k] = clamped;
    _ensureImeiCtrls(k, it, clamped);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: 24),
      backgroundColor: Colors.transparent,
      child: _screen == 1 ? _buildScreen1() : _buildScreen2(),
    );
  }

  Widget _buildScreen1() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE31837),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(12)),
                ),
                width: double.infinity,
                child: Text(
                  'Confirmação de Pedido - ${widget.pedido.codigoExterno ?? widget.pedido.numero ?? ''}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: _itens.map(_buildItem).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onCancel();
                      },
                      child: const Text('FECHAR',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF12CD0C)),
                      onPressed: () {
                        if (_validar()) setState(() => _screen = 2);
                      },
                      child: const Text('CONFIRMAR',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 12,
          bottom: 70,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFFE31837),
            onPressed: _scan,
            child: const Icon(Icons.barcode_reader, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildScreen2() {
    var total = 0;
    for (final v in _qtd.values) total += v;
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Confirmação',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Total de itens confirmados:'),
          const SizedBox(height: 8),
          Text('$total',
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _screen = 1),
                child: const Text('FECHAR',
                    style: TextStyle(color: Colors.grey)),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF12CD0C)),
                onPressed: _confirmar,
                child: const Text('SIM',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItem(Item it) {
    final k = _key(it);
    final qtdMax = it.quantidade;
    final qtdAtual = _qtd[k] ?? qtdMax;
    final alterado = qtdAtual != qtdMax;
    final imeiCount = qtdAtual * it.quantidadeImeis;
    final ean = it.codigoEAN ?? '';
    final sap = it.codigoSAP ?? '';
    var codigoStr = '';
    if (ean.isNotEmpty) codigoStr += 'EAN: $ean';
    if (sap.isNotEmpty) {
      if (codigoStr.isNotEmpty) codigoStr += ' / ';
      codigoStr += 'SAP: $sap';
    }

    return Card(
      color: alterado ? const Color(0xFFFFF1F1) : Colors.white,
      shape: RoundedRectangleBorder(
          side: BorderSide(
              color: alterado ? const Color(0xFFE61937) : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: true,
                  onChanged: null,
                  activeColor: alterado
                      ? const Color(0xFFE61937)
                      : const Color(0xFF2E7D32),
                ),
                Text('${qtdMax}x',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(it.descricao ?? 'Sem descrição',
                        style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
            if (codigoStr.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 36, bottom: 4),
                child: Text(codigoStr,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
              ),
            if (it.estoque != null)
              Padding(
                padding: const EdgeInsets.only(left: 36, bottom: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('Estoque: ${it.estoque}',
                      style: const TextStyle(fontSize: 11)),
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: qtdAtual > 1
                      ? () {
                          final nova = qtdAtual - 1;
                          _qtyCtrls[k]?.text = nova.toString();
                          _qtd[k] = nova;
                          _ensureImeiCtrls(k, it, nova);
                          setState(() {});
                        }
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: TextField(
                    controller: _qtyCtrls[k],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration:
                        const InputDecoration(isDense: true),
                    onChanged: (t) => _onQtdChanged(k, it, t),
                  ),
                ),
              ],
            ),
            if (it.quantidadeImeis > 0) ...[
              const Divider(),
              Text(
                it.quantidadeImeis == 1
                    ? 'IMEI do aparelho'
                    : 'IMEIs dos aparelhos',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ...List.generate(imeiCount, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                            textAlign: TextAlign.end),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _imeiCtrls[k]![i],
                          keyboardType: TextInputType.number,
                          maxLength: 15,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'IMEI ${i + 1}',
                            border: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: alterado
                                        ? const Color(0xFFE61937)
                                        : Colors.grey)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
