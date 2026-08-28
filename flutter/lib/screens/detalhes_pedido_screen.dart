import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/pedido.dart';
import '../network/api_service.dart';
import '../network/session_manager.dart';
import '../utils/currency_formatter.dart';
import '../widgets/maestro_dialogs.dart';
import 'scanner_imei_screen.dart';

const int _cinzaBorda = 0xFF475569;
const int _bgTela = 0xFFF5F5F5;

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
  bool _carregando = true;
  bool _erro = false;
  Map<String, dynamic>? _tokens;
  bool _timelineAberta = false;
  final ScrollController _scrollController = ScrollController();
  bool _mostrarAcao = false;
  bool _didInitFim = false;

  @override
  void initState() {
    super.initState();
    _pedido = widget.pedido ??
        Pedido(
          id: widget.pedidoId,
          numero: '',
          codigoExterno: '',
          loja: '',
          status: '',
          dataInclusao: '',
          cliente: null,
          itens: [],
          valorTotal: 0,
          valorSubtotal: 0,
          valorDesconto: 0,
          valorEntrega: 0,
          timelines: [],
          historico: [],
        );
    if (widget.pedido == null) {
      _carregar();
    } else {
      _carregando = false;
      _carregarTokens();
    }
  }

  Future<void> _carregar() async {
    try {
      final p = await widget.apiService.getPedidoById(widget.pedidoId);
      if (mounted) {
        setState(() {
          _pedido = p;
          _carregando = false;
        });
      }
      _carregarTokens();
    } catch (_) {
      if (mounted) setState(() => _erro = true);
    }
  }

  Future<void> _carregarTokens() async {
    try {
      final t = await widget.apiService
          .getDeliveryTokens(_pedido.codigoExterno ?? _pedido.numero);
      if (mounted) {
        final data = (t is Map && t['data'] is Map) ? t['data'] : t;
        setState(() => _tokens =
            data is Map ? Map<String, dynamic>.from(data as Map) : null);
      }
    } catch (_) {}
  }

  ({String texto, Color cor}) get _statusBadge {
    final s = _pedido.status.toUpperCase().trim();
    switch (s) {
      case 'NOVO_PEDIDO':
      case 'NOVO':
        return (texto: 'NOVO', cor: const Color(0xFF12CD0C));
      case 'EM_SEPARACAO':
      case 'SEPARACAO':
        return (texto: 'Separação', cor: const Color(0xFFFFAA02));
      case 'PRONTO_PARA_SAIR':
      case 'PRONTO':
        return (texto: 'Pronto para Retirada', cor: const Color(0xFFFFAA02));
      case 'SAIU_PARA_ENTREGA':
        return (texto: 'Saiu Para Entrega', cor: const Color(0xFFCE00FF));
      case 'FINALIZADO':
      case 'ENTREGUE':
        return (texto: 'Entregue', cor: const Color(0xFF12CD0C));
      case 'CANCELADO':
        return (texto: 'Cancelado', cor: const Color(0xFFF80032));
      case 'DEVOLVIDO':
        return (texto: 'Devolvido', cor: const Color(0xFFF80032));
      case 'RETORNAR_PARA_ESTOQUE':
        return (texto: 'RETORNAR AO ESTOQUE', cor: const Color(0xFFF80032));
      default:
        return (texto: s.isEmpty ? '—' : s, cor: const Color(0xFF9CA3AF));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusBadge;
    if (!_carregando && !_didInitFim) {
      _didInitFim = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final pos = _scrollController.position;
          final atEnd = pos.pixels >= (pos.maxScrollExtent - 4);
          if (atEnd != _mostrarAcao) {
            if (mounted) setState(() => _mostrarAcao = atEnd);
          }
        }
      });
    }
    return Scaffold(
      backgroundColor: const Color(_bgTela),
      body: _carregando
          ? _skeleton()
          : Column(
              children: [
                _toolbar(status.cor),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollUpdateNotification ||
                          n is ScrollEndNotification) {
                        final pos = n.metrics;
                        final atEnd =
                            pos.pixels >= (pos.maxScrollExtent - 4);
                        if (atEnd != _mostrarAcao && mounted) {
                          setState(() => _mostrarAcao = atEnd);
                        }
                      }
                      return false;
                    },
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        _headerStatus(status),
                        const SizedBox(height: 12),
                        _cardCliente(),
                        const SizedBox(height: 10),
                        _cardRecebedor(),
                        const SizedBox(height: 10),
                        _cardItens(),
                        const SizedBox(height: 10),
                        _cardTokens(),
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
                ),
                _barraAcao(status),
              ],
            ),
      floatingActionButton: _temImei()
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFE31837),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ScannerImeiScreen(),
                ),
              ),
              child: const Icon(Icons.barcode_reader, color: Colors.white),
            )
          : null,
    );
  }

  bool _temImei() =>
      _pedido.itens.any((i) => i.quantidadeImeis > 0);

  Widget _skeleton() => const Center(
        child: CircularProgressIndicator(),
      );

  Widget _toolbar(Color cor) => Container(
        color: cor,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_pedido.cliente?.nome ?? 'Cliente',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('Nº ${_pedido.codigoExterno ?? _pedido.numero}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _headerStatus(({String texto, Color cor}) status) => Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: status.cor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status.texto,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                if (_pedido.canalDeVendas != null &&
                    _pedido.canalDeVendas!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF80032),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_pedido.canalDeVendas!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
                if (_pedido.tipoEntrega != null &&
                    _pedido.tipoEntrega!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF760018),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(_pedido.tipoEntrega!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _timelineAberta = !_timelineAberta),
              child: Row(
                children: [
                  SvgPicture.asset(
                    _timelineAberta
                        ? 'assets/vectors/ic_arrow_up.svg'
                        : 'assets/vectors/ic_arrow_down.svg',
                    width: 20,
                    height: 20,
                    color: const Color(0xFF64748B),
                  ),
                  const Text('Linha do Tempo',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937))),
                ],
              ),
            ),
            if (_timelineAberta) ...[
              const SizedBox(height: 12),
              _timeline(),
            ],
          ],
        ),
      );

  ({String icon, Color cor}) _timelineStyle(String nome) {
    final n = nome.toUpperCase();
    if (n.contains('NOVO') ||
        n.contains('INCLUIDO') ||
        n.contains('CHEGADA') ||
        n.contains('VISUALIZ') ||
        n.contains('CRIADO')) {
      return (icon: 'assets/icons/criado.png', cor: const Color(0xFF12CD0C));
    }
    if (n.contains('SEPARACAO')) {
      return (
        icon: 'assets/icons/em_separacao.png',
        cor: const Color(0xFF00CBFE)
      );
    }
    if (n.contains('EDITADO')) {
      return (icon: 'assets/icons/editado.png', cor: const Color(0xFFED7D31));
    }
    if (n.contains('PRONTO')) {
      return (
        icon: 'assets/icons/pronto_para_retirada.png',
        cor: const Color(0xFFFFAA02)
      );
    }
    if (n.contains('ENTREGA')) {
      return (
        icon: 'assets/icons/saiu_para_entrega.png',
        cor: const Color(0xFFCE00FF)
      );
    }
    if (n.contains('RETORNAR')) {
      return (
        icon: 'assets/icons/retornar_para_estoque.png',
        cor: const Color(0xFFDC2626)
      );
    }
    if (n.contains('CANCEL')) {
      return (icon: 'assets/icons/cancelado.png', cor: const Color(0xFFDC2626));
    }
    if (n.contains('DEVOLV')) {
      return (icon: 'assets/icons/devolvido.png', cor: const Color(0xFFDC2626));
    }
    if (n.contains('ENTREGUE') || n.contains('FINALIZ')) {
      return (icon: 'assets/icons/entregue.png', cor: const Color(0xFF12CD0C));
    }
    return (icon: 'assets/icons/criado.png', cor: const Color(0xFF9CA3AF));
  }

  Widget _timeline() {
    final passos = _pedido.timelines;
    if (passos.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: passos.map((t) {
          final style = _timelineStyle(t.nome ?? '');
          return Container(
            width: 86,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: style.cor.withOpacity(0.12),
                    border: Border.all(color: style.cor, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Image.asset(style.icon, color: style.cor),
                  ),
                ),
                const SizedBox(height: 5),
                Text(t.nome ?? '',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: style.cor),
                    textAlign: TextAlign.center),
                if (t.data != null && t.data!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(t.data!,
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFF9CA3AF)),
                        textAlign: TextAlign.center),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _temMaisDe3Dias() {
    final d = _pedido.dataInclusao;
    if (d == null || d.isEmpty) return false;
    try {
      final dt = DateTime.parse(d).toLocal();
      return DateTime.now().difference(dt).inDays > 3;
    } catch (_) {
      return false;
    }
  }

  Widget _cardCliente() => _card(
        titulo: 'Dados do cliente',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _linhaDado(Icons.person,
                _pedido.cliente?.nome ?? 'Cliente não informado',
                negrito: true, size: 16),
            if (_pedido.cliente?.cpf != null)
              _linhaDado(Icons.badge, 'CPF: ${_pedido.cliente!.cpf!}'),
            if (_pedido.cliente?.email != null)
              _linhaDado(Icons.email, _pedido.cliente!.email!),
            if (_pedido.cliente?.telefone != null)
              Row(
                children: [
                  const Icon(Icons.phone, size: 18, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_pedido.cliente!.telefone!,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280)))),
                  IconButton(
                    icon: const Icon(Icons.call, color: Color(0xFF12CD0C)),
                    onPressed: () {},
                  ),
                ],
              ),
            if (_pedido.cliente?.endereco != null)
              _linhaDado(Icons.location_on, _pedido.cliente!.endereco!),
          ],
        ),
      );

  Widget _cardRecebedor() => _card(
        titulo: 'Recebedor',
        child: _linhaDado(Icons.person_outline, '-'),
      );

  Widget _cardItens() => _card(
        titulo: 'Itens do pedido',
        child: Column(
          children: [
            ..._pedido.itens.map(_itemRow).toList(),
            const Divider(height: 20, color: Color(0xFFBCBCBC)),
            _linhaValor('Subtotal', _pedido.valorSubtotal),
            _linhaValor('Desconto', _pedido.valorDesconto),
            _linhaValor('Entrega', _pedido.valorEntrega),
            const Divider(height: 16, color: Color(0xFFBCBCBC)),
            Row(
              children: [
                const Text('Total',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                    'R\$ ${CurrencyFormatter.format(_pedido.valorTotal)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CD137))),
              ],
            ),
          ],
        ),
      );

  Widget _itemRow(Item i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 45,
                  child: Text('${i.quantidade}x',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B2B2B))),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.descricao ?? '',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A4A4A))),
                      Text(
                          'EAN: ${i.codigoEAN ?? ''} / SAP: ${i.codigoSAP ?? ''}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF888888))),
                      if (i.imeis.isNotEmpty)
                        Text('IMEI: ${i.imeis.expand((e) => e).join(", ")}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFD32F2F),
                                fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('R\$ ${CurrencyFormatter.format(i.valorTotal)}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B2B2B))),
                      Text('${i.quantidade}x R\$ ${CurrencyFormatter.format(i.valorUnitario)}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF555555),
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            if (i.estoque != null)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF29CC39),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Estoque estimado: ${i.estoque}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11)),
                ),
              ),
            const Divider(height: 16, color: Color(0xFFDDDDDD)),
          ],
        ),
      );

  Widget _cardTokens() => _card(
        titulo: 'Tokens do pedido',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Token Cliente: ${_tokens?['tokenCliente'] ?? '--'}',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF6B7280))),
            Text('Token Retirada: ${_tokens?['tokenRetirada'] ?? '--'}',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF6B7280))),
            Text('Token Insucesso: ${_tokens?['tokenInsucesso'] ?? '--'}',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ),
      );

  Widget _card({required String titulo, required Widget child}) => Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(_cinzaBorda), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFB62F2C),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(titulo,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              child,
            ],
          ),
        ),
      );

  Widget _linhaDado(IconData icon, String texto,
          {bool negrito = false, double size = 13}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texto,
                  style: TextStyle(
                      fontSize: size,
                      color: const Color(0xFF1A1A1A),
                      fontWeight:
                          negrito ? FontWeight.bold : FontWeight.normal)),
            ),
          ],
        ),
      );

  Widget _linhaValor(String label, double v) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4A4A4A),
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('R\$ ${CurrencyFormatter.format(v)}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF4A4A4A))),
          ],
        ),
      );

  Widget _barraAcao(({String texto, Color cor}) status) {
    final s = _pedido.status.toUpperCase();
    final badges = <Widget>[];
    if (s.contains('NOVO')) {
      badges.add(_badgeAcao(
          'POR EM SEPARAÇÃO', const Color(0xFF12CD0C), _acaoSeparar));
    } else if (s.contains('SEPARACAO')) {
      badges.add(_badgeAcao('CONFIRMAR', const Color(0xFF12CD0C), _acaoConfirmar));
    } else if (s.contains('PRONTO')) {
      badges.add(_badgeAcao(
          'RETIRAR PEDIDO', const Color(0xFFFFAA02), _acaoRetirar));
      if (_temMaisDe3Dias()) {
        badges.add(const SizedBox(height: 8));
        badges.add(_badgeAcao(
            'CANCELAR', const Color(0xFFF80032), _acaoCancelarRetirada));
      }
    } else if (s.contains('ENTREGA')) {
      badges.add(_badgeAcao(
          'ENTREGADOR VOLTOU', const Color(0xFFF80032), _acaoEntregadorVoltou));
    } else if (s.contains('RETORNAR')) {
      badges.add(_badgeAcao('DEVOLVER PARA O ESTOQUE', const Color(0xFFF80032),
          _acaoDevolverEstoque));
    } else if (s.contains('FINALIZADO')) {
      badges.add(_badgeAcao(
          'CANCELAR', const Color(0xFFF80032), _acaoCancelarHistorico));
    }
    if (badges.isEmpty) return const SizedBox.shrink();
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _mostrarAcao ? 1 : 0,
      child: IgnorePointer(
        ignoring: !_mostrarAcao,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          color: const Color(_bgTela),
          child: Column(children: badges),
        ),
      ),
    );
  }

  Widget _badgeAcao(String texto, Color cor, VoidCallback onTap) => Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
            color: cor, borderRadius: BorderRadius.circular(24)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Center(
              child: Text(texto,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      );

  void _sucesso(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sucesso', textAlign: TextAlign.center),
        content: Text(msg, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _acaoSeparar() async {
    try {
      await widget.apiService.separarPedido(
          _pedido.origem ?? '', _pedido.codigoExterno ?? _pedido.numero);
      _sucesso('Pedido em separação.');
    } catch (e) {
      _erroMsg(e);
    }
  }

  Future<void> _acaoConfirmar() async {
    final ok = await MaestroDialogs.quantidadeNovo(context, _pedido);
    if (ok != true) return;
    final conf = await MaestroDialogs.tudoCerto(
        context, _pedido.itens.length);
    if (conf != true) return;
    try {
      await widget.apiService.confirmarPedido(
          _pedido.origem ?? '', _pedido.codigoExterno ?? _pedido.numero);
      _sucesso('Separação confirmada.');
    } catch (e) {
      _erroMsg(e);
    }
  }

  Future<void> _acaoRetirar() async {
    final codigo = await MaestroDialogs.token(context,
        nome: _pedido.cliente?.nome ?? '',
        numero: _pedido.codigoExterno ?? _pedido.numero);
    if (codigo == null || codigo.isEmpty) return;
    try {
      await widget.apiService.retirarPedidoShipFromStore(
          _pedido.codigoExterno ?? _pedido.numero);
      _sucesso('Pedido retirado.');
    } catch (e) {
      _erroMsg(e);
    }
  }

  Future<void> _acaoCancelarRetirada() async {
    final ok = await MaestroDialogs.confirmar(context,
        titulo: 'Cancelar pedido',
        mensagem:
            'Este pedido está há mais de 3 dias em PRONTO PARA RETIRADA. Deseja realmente cancelá-lo?',
        textoSim: 'SIM, CANCELAR');
    if (ok != true) return;
    try {
      await widget.apiService.cancelarPedido(
          _pedido.origem ?? '', _pedido.codigoExterno ?? _pedido.numero,
          'Cancelado pelo usuário', 'CANCELAMENTO');
      _sucesso('Pedido cancelado.');
    } catch (e) {
      _erroMsg(e);
    }
  }

  Future<void> _acaoEntregadorVoltou() async {
    List<String> motivos = [];
    try {
      final m = await widget.apiService.getMotivosInsucesso();
      motivos = m.map((e) => e.toString()).toList();
    } catch (_) {
      motivos = ['Cliente ausente', 'Endereço incorreto', 'Recusou receber'];
    }
    final res = await MaestroDialogs.entregadorVoltou(context, motivos);
    if (res == null) return;
    try {
      await widget.apiService.devolverPedido(
          _pedido.origem ?? '',
          _pedido.codigoExterno ?? _pedido.numero,
          recaptchaToken: res.$3,
          observacao: res.$2);
      _sucesso('Pedido retornado ao estoque.');
    } catch (e) {
      _erroMsg(e);
    }
  }

  Future<void> _acaoDevolverEstoque() async {
    final res = await MaestroDialogs.retornarEstoque(context);
    if (res == null) return;
    try {
      await widget.apiService.retornarParaEstoque(
          _pedido.origem ?? '',
          _pedido.codigoExterno ?? _pedido.numero,
          captchaToken: res.$2,
          motivo: res.$1);
      _sucesso('Devolvido ao estoque.');
    } catch (e) {
      _erroMsg(e);
    }
  }

  Future<void> _acaoCancelarHistorico() async {
    final res = await MaestroDialogs.devolverHistorico(context);
    if (res == null) return;
    try {
      await widget.apiService.cancelarPedido(
          _pedido.origem ?? '',
          _pedido.codigoExterno ?? _pedido.numero,
          res.$1,
          'CANCELAMENTO');
      _sucesso('Pedido cancelado.');
    } catch (e) {
      _erroMsg(e);
    }
  }

  void _erroMsg(Object e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Erro: $e')));
  }
}
