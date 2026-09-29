import 'package:flutter/material.dart';
import '../models/pedido.dart';

class ItemQuantidadeDialog extends StatefulWidget {
  final List<Item> itens;

  const ItemQuantidadeDialog({super.key, required this.itens});

  @override
  State<ItemQuantidadeDialog> createState() => _ItemQuantidadeDialogState();
}

class _ItemQuantidadeDialogState extends State<ItemQuantidadeDialog> {
  late List<int> _qtd;

  @override
  void initState() {
    super.initState();
    _qtd = widget.itens.map((e) => e.quantidade).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      title: const Text('Confirmar quantidades'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.itens.length,
          itemBuilder: (ctx, i) {
            final item = widget.itens[i];
            return ListTile(
              title: Text(item.descricao ?? item.codigoSAP ?? '-',
                  style: const TextStyle(fontSize: 14)),
              subtitle: Text('Estoque: ${item.estoque ?? "-"}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => setState(() {
                      if (_qtd[i] > 0) _qtd[i]--;
                    }),
                  ),
                  Text('${_qtd[i]}'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() {
                      _qtd[i]++;
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_qtd),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

class SmartphoneConfirmacaoDialog extends StatefulWidget {
  final List<Item> itens;

  const SmartphoneConfirmacaoDialog({super.key, required this.itens});

  @override
  State<SmartphoneConfirmacaoDialog> createState() =>
      _SmartphoneConfirmacaoDialogState();
}

class _SmartphoneConfirmacaoDialogState
    extends State<SmartphoneConfirmacaoDialog> {
  final Map<int, String> _imeis = {};

  @override
  Widget build(BuildContext context) {
    final smartphones = widget.itens
        .where((e) => (e.quantidadeImeis) > 0 || (e.imeis.isNotEmpty))
        .toList();
    return AlertDialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      title: const Text('Confirmar smartphones'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: smartphones.length,
          itemBuilder: (ctx, i) {
            final item = smartphones[i];
            final idx = widget.itens.indexOf(item);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'IMEI: ${item.descricao ?? item.codigoSAP}',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => _imeis[idx] = v,
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_imeis),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
