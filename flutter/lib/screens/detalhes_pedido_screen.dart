import 'package:flutter/material.dart';
import '../models/pedido.dart';
import '../network/api_service.dart';
import '../network/session_manager.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../widgets/dialogs.dart';

class DetalhesPedidoScreen extends StatefulWidget {
  final SessionManager session;
  final ApiService apiService;
  final String pedidoId;
  final Pedido? pedido;

  const DetalhesPedidoScreen({
    super.key,
    required this.session,
    required this.apiService,
    required this.pedidoId,
    this.pedido,
  });

  @override
  State<DetalhesPedidoScreen> createState() => _DetalhesPedidoScreenState();
}

class _DetalhesPedidoScreenState extends State<DetalhesPedidoScreen> {
  late Pedido _pedido;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _pedido = widget.pedido ?? Pedido(id: widget.pedidoId);
    if (widget.pedido == null) _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final p = await widget.apiService
          .getPedidoById(widget.session.getUserStore() ?? Constants.defaultStore, widget.pedidoId);
      if (mounted) setState(() => _pedido = p);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _acao(String novoStatus, {String? msg}) async {
    setState(() => _carregando = true);
    try {
      await widget.apiService.updateStatus(
        widget.session.getUserStore() ?? Constants.defaultStore,
        _pedido.id,
        novoStatus,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg ?? 'Status atualizado: $novoStatus')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha: $e')));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<Widget> _acoes() {
    final s = _pedido.status;
    if (s == Constants.statusNovoPedido) {
      return [
        _btn('Separar', const Color(Constants.ORANGE_500),
            () => _acao(Constants.statusEmSeparacao, msg: 'Pedido em separação')),
      ];
    }
    if (s == Constants.statusEmSeparacao) {
      return [
        _btn('Confirmar', const Color(Constants.GREEN_500), _confirmarSeparacao),
      ];
    }
    if (s == Constants.statusProntoParaSair) {
      return [
        _btn('Retirar', const Color(Constants.BLUE_500), _retirar),
      ];
    }
    if (s == Constants.statusSaiuParaEntrega) {
      return [
        _btn('Confirmar Entrega', const Color(Constants.GREEN_500),
            () => _acao('FINALIZADO', msg: 'Entrega confirmada')),
        _btn('Insucesso', const Color(Constants.RED_500),
            () => _acao('DEVOLVIDO', msg: 'Insucesso registrado')),
      ];
    }
    if (s == Constants.statusRetornarEstoque) {
      return [
        _btn('Retornar ao Estoque', const Color(Constants.ORANGE_500),
            () => _acao('RETORNAR_PARA_ESTOQUE', msg: 'Retornado ao estoque')),
      ];
    }
    return [
      _btn('Cancelar Pedido', const Color(Constants.RED_500), _cancelar),
      _btn('Devolver', const Color(Constants.RED_500),
          () => _acao('DEVOLVIDO', msg: 'Devolvido')),
    ];
  }

  void _confirmarSeparacao() async {
    final qtd = await showDialog<List<int>>(
      context: context,
      builder: (_) => ItemQuantidadeDialog(itens: _pedido.itens),
    );
    if (qtd == null) return;
    if (_pedido.itens.any((e) => e.quantidadeImeis > 0 || e.imeis.isNotEmpty)) {
      final imeis = await showDialog<Map<int, String>>(
        context: context,
        builder: (_) => SmartphoneConfirmacaoDialog(itens: _pedido.itens),
      );
      if (imeis == null) return;
    }
    await _acao(Constants.statusProntoParaSair, msg: 'Pedido pronto para sair');
  }

  void _retirar() async {
    await _acao(Constants.statusSaiuParaEntrega, msg: 'Pedido saiu para entrega');
  }

  void _cancelar() async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => _MotivoDialog(titulo: 'Cancelar pedido'),
    );
    if (motivo == null || motivo.isEmpty) return;
    setState(() => _carregando = true);
    try {
      await widget.apiService.cancelarPedido(
        widget.session.getUserStore() ?? Constants.defaultStore,
        _pedido.id,
        motivo,
        'CANCELAMENTO',
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Pedido cancelado')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha: $e')));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Widget _btn(String label, Color cor, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: cor),
          onPressed: _carregando ? null : onTap,
          child: Text(label, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(Constants.RED_600),
        title: Text(_pedido.titulo.isEmpty ? 'Pedido' : _pedido.titulo),
        actions: [
          if (_pedido.notaFiscalChave != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Abrindo DANFE...')),
                );
              },
            ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _secao('Cliente', [
                  if (_pedido.cliente?.nome != null)
                    Text(_pedido.cliente!.nome!),
                  if (_pedido.cliente?.cpf != null)
                    Text('CPF: ${_pedido.cliente!.cpf}'),
                  if (_pedido.cliente?.endereco != null)
                    Text(
                        'Endereço: ${_pedido.cliente!.endereco} ${_pedido.cliente!.numero ?? ''}'),
                  if (_pedido.cliente?.cidade != null)
                    Text(
                        '${_pedido.cliente!.cidade}${_pedido.cliente!.uf != null ? ' - ${_pedido.cliente!.uf}' : ''}'),
                ]),
                _secao('Resumo', [
                  _linhaValor('Subtotal', _pedido.valorSubtotal),
                  _linhaValor('Desconto', _pedido.valorDesconto),
                  _linhaValor('Entrega', _pedido.valorEntrega),
                  _linhaValor('Total', _pedido.valorTotal),
                  Text('Pagamento: ${_pedido.pagamentoStatus ?? "-"}'),
                ]),
                _secao('Itens', _pedido.itens.map((e) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.descricao ?? e.codigoSAP ?? '-'),
                    subtitle: Text(
                        'Qtd: ${e.quantidade}  |  ${CurrencyFormatter.format(e.valorTotal)}'),
                    trailing: e.estoque != null
                        ? Text('Est: ${e.estoque}')
                        : null,
                  );
                }).toList()),
                _secao('Histórico', _pedido.historico.map((h) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(h.status ?? '-'),
                    subtitle: Text(
                        '${h.usuario ?? ""}  ${h.data ?? ""}'),
                  );
                }).toList()),
                const SizedBox(height: 12),
                ..._acoes(),
              ],
            ),
    );
  }

  Widget _secao(String titulo, List<Widget> filhos) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            ...filhos,
          ],
        ),
      ),
    );
  }

  Widget _linhaValor(String label, double v) =>
      Text('$label: ${CurrencyFormatter.format(v)}');
}

class _MotivoDialog extends StatefulWidget {
  final String titulo;

  const _MotivoDialog({required this.titulo});

  @override
  State<_MotivoDialog> createState() => _MotivoDialogState();
}

class _MotivoDialogState extends State<_MotivoDialog> {
  final _c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _c,
        decoration: const InputDecoration(labelText: 'Motivo'),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_c.text.trim()),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
