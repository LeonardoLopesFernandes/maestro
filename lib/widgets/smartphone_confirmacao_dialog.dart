import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pedido.dart';
import '../screens/scanner_imei_screen.dart';

/// Diálogo de confirmação de pedido (smartphones) com o layout de referência:
/// cabeçalho vermelho, cards de produto, controle de quantidade e campo IMEI
/// com leitor de câmera.
class SmartphoneConfirmacaoDialog extends StatefulWidget {
  final Pedido pedido;
  final void Function(
      Map<String, int> quantidades, Map<String, List<String>> imeis) onConfirm;
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
  static const Color red700 = Color(0xFFC62828);
  static const Color red600 = Color(0xFFD32F2F);
  static const Color red50 = Color(0xFFFFEBEE);
  static const Color red100 = Color(0xFFFFCDD2);

  final Map<String, int> _qtd = {};
  final Map<String, List<TextEditingController>> _imeiCtrls = {};

  List<Item> get _itens =>
      widget.pedido.itens.where((i) => i.quantidadeImeis > 0).toList();

  String _key(Item i) => i.codigoSAP ?? i.codigoEAN ?? i.descricao ?? '';

  @override
  void initState() {
    super.initState();
    for (final it in _itens) {
      final k = _key(it);
      _qtd[k] = it.quantidade;
      _ensureImeiCtrls(k, it, it.quantidade);
    }
  }

  @override
  void dispose() {
    for (final l in _imeiCtrls.values) {
      for (final c in l) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _ensureImeiCtrls(String k, Item it, int qtd) {
    final count = qtd * it.quantidadeImeis;
    final list = _imeiCtrls.putIfAbsent(k, () => []);
    while (list.length < count) {
      final c = TextEditingController();
      c.addListener(() {
        if (mounted) setState(() {});
      });
      list.add(c);
    }
    while (list.length > count) {
      list.last.dispose();
      list.removeLast();
    }
  }

  List<String> _imeisOf(String k) =>
      _imeiCtrls[k]?.map((c) => c.text.trim()).toList() ?? [];

  void _alterarQtd(String k, Item it, int nova) {
    final clamped = nova < 1 ? 1 : (nova > it.quantidade ? it.quantidade : nova);
    _qtd[k] = clamped;
    _ensureImeiCtrls(k, it, clamped);
    setState(() {});
  }

  Future<void> _scanInto(String k, int index) async {
    final imei = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const ScannerImeiScreen()));
    if (imei == null || imei.isEmpty) return;
    final list = _imeiCtrls[k];
    if (list == null || index >= list.length) return;
    list[index].text = imei;
    setState(() {});
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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

  void _confirmar() {
    if (!_validar()) return;
    final imeis = <String, List<String>>{};
    for (final it in _itens) {
      imeis[_key(it)] = _imeisOf(_key(it));
    }
    Navigator.of(context).pop();
    widget.onConfirm(Map.from(_qtd), imeis);
  }

  void _cancelar() {
    Navigator.of(context).pop();
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final numero = widget.pedido.codigoExterno.isNotEmpty
        ? widget.pedido.codigoExterno
        : widget.pedido.numero;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho
            Container(
              color: red700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Confirmação de Pedido',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Nº $numero',
                        style: TextStyle(
                          color: Colors.red.shade100.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 20),
                    onPressed: _cancelar,
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Conteúdo
            Flexible(
              child: Container(
                color: const Color(0xFFFAFAFA),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _itens.map(_buildItem).toList(),
                  ),
                ),
              ),
            ),
            // Rodapé
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelar,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: const Color(0xFF374151),
                      ),
                      child: const Text(
                        'CANCELAR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: red600,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: red600.withOpacity(0.4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'CONFIRMAR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      if (codigoStr.isNotEmpty) codigoStr += '  |  ';
      codigoStr += 'SAP: $sap';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card do produto
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: alterado ? red600 : red100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_box_rounded,
                      color: red600, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        it.descricao ?? 'Sem descrição',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                          height: 1.2,
                        ),
                      ),
                      if (codigoStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          codigoStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      if (it.estoque != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: red50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: red100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2_outlined,
                                  size: 14, color: Color(0xFFB71C1C)),
                              const SizedBox(width: 6),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFB71C1C),
                                  ),
                                  children: [
                                    const TextSpan(text: 'Estoque: '),
                                    TextSpan(
                                      text: '${it.estoque}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Quantidade
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quantidade',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        color: Colors.grey.shade700,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                        onPressed: qtdAtual > 1
                            ? () => _alterarQtd(k, it, qtdAtual - 1)
                            : null,
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '$qtdAtual',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        color: Colors.grey.shade700,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                        onPressed: qtdAtual < qtdMax
                            ? () => _alterarQtd(k, it, qtdAtual + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // IMEI(s)
          Text(
            it.quantidadeImeis == 1 && imeiCount == 1
                ? 'IMEI do aparelho'
                : 'IMEIs dos aparelhos',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          ...List.generate(imeiCount, (i) {
            final ctrl = _imeiCtrls[k]![i];
            return Padding(
              padding: EdgeInsets.only(bottom: i == imeiCount - 1 ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imeiCount > 1) ...[
                    Text(
                      'IMEI ${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    maxLength: 15,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 14),
                    buildCounter: (context,
                            {required currentLength,
                            required isFocused,
                            maxLength}) =>
                        null,
                    decoration: InputDecoration(
                      hintText: 'Digite ou escaneie o IMEI',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      prefixIcon: Icon(
                        Icons.qr_code_2_rounded,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      suffixIcon: Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: red50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt_outlined,
                              size: 16, color: red600),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                          onPressed: () => _scanInto(k, i),
                        ),
                      ),
                      fillColor: Colors.white,
                      filled: true,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: red600, width: 2),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${ctrl.text.length}/15',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
