import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../models/pedido.dart';
import '../network/api_service.dart';
import '../network/session_manager.dart';
import '../utils/currency_formatter.dart';
import '../widgets/maestro_dialogs.dart';
import 'scanner_imei_screen.dart';
import 'visualizar_danfe_screen.dart';
import '../widgets/smartphone_confirmacao_dialog.dart';

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
  bool _mostrarTokens = false;
  bool _didInitFim = false;
  Timer? _pollingEntregador;

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
    // O Kotlin sempre re-busca o pedido completo ao abrir os detalhes
    // (getPedidoById), pois o pedido da listagem traz o endereço padrão da
    // loja em cliente.endereco. Re-buscamos silenciosamente para obter o
    // endereço real cadastrado pelo cliente.
    if (widget.pedido == null) {
      _carregar();
    } else {
      _carregando = false;
      _carregarTokens();
      _carregar(silencioso: true);
    }
  }

  Future<void> _carregar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _carregando = true);
    try {
      final p = await widget.apiService.getPedidoById(widget.pedidoId);
      if (mounted) {
        setState(() {
          _pedido = p;
          if (!silencioso) _carregando = false;
        });
      }
      _carregarTokens();
    } catch (_) {
      if (mounted && !silencioso) setState(() => _erro = true);
    }
  }

  @override
  void dispose() {
    _pollingEntregador?.cancel();
    super.dispose();
  }

  // Polling de confirmação do entregador (fluxo EXTERNA / reserva), espelha
  // iniciarPollingConfirmacaoEntregador do Kotlin: a cada 5s (máx. 60
  // rodadas) consulta o pedido; quando o entregador confirma no app dele o
  // status vira SAIU_PARA_ENTREGA/FINALIZADO/ENTREGUE e avisamos o operador.
  void _iniciarPollingEntregador() {
    _pollingEntregador?.cancel();
    int rodadas = 0;
    _pollingEntregador = Timer.periodic(const Duration(seconds: 5), (t) async {
      rodadas++;
      if (rodadas > 60) {
        t.cancel();
        return;
      }
      try {
        final p = await widget.apiService.getPedidoById(_pedido.numero);
        final status = (p.status).toUpperCase();
        if (status == 'SAIU_PARA_ENTREGA' ||
            status == 'FINALIZADO' ||
            status == 'ENTREGUE') {
          t.cancel();
          if (mounted) {
            setState(() => _pedido = p);
            _carregarTokens();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('✅ Entregador confirmou a coleta! Toque em CONFIRMAR.'),
              duration: Duration(seconds: 4),
            ));
          }
        }
      } catch (_) {
        // mantém o polling até o limite de rodadas
      }
    });
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

  Color _corCanal(String canal) {
    final c = canal.toUpperCase();
    if (c.contains('MAGAZINE')) return const Color(0xFF0086FF);
    if (c.contains('AMERICANAS')) return const Color(0xFFE60014);
    if (c.contains('IFOOD')) return const Color(0xFFEF2E2E);
    if (c.contains('SHOPE')) return const Color(0xFFFFD200);
    return const Color(0xFFF80032);
  }

  String _labelTipoEntrega(String tipo) {
    final t = tipo.toUpperCase();
    if (t.contains('RETIRADA')) return 'Pegue na Loja Hoje';
    if (t.contains('EXTERNA')) return 'Delivery';
    return tipo;
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
        return (texto: 'Retornar Para Estoque', cor: const Color(0xFFF80032));
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
                        _cardMotivo(),
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
      floatingActionButton: null,
    );
  }

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
                      color: _corCanal(_pedido.canalDeVendas ?? ''),
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
                    child: Text(_labelTipoEntrega(_pedido.tipoEntrega!),
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
                  const Spacer(),
                  _badgeTempoTotal(),
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

  ({String label, String icon, Color cor, bool tint}) _timelineInfo(String nome) {
    final n = nome.toUpperCase();
    if (n.contains('NOVO') || n.contains('INCLUIDO') || n.contains('CHEGADA'))
      return (label: 'Chegada', icon: 'assets/icons/criado.png', cor: const Color(0xFF12CD0C), tint: true);
    if (n.contains('VISUALIZ'))
      return (label: 'Visualizado', icon: 'assets/icons/criado.png', cor: const Color(0xFF12CD0C), tint: true);
    if (n.contains('CRIADO'))
      return (label: 'Criado', icon: 'assets/icons/criado.png', cor: const Color(0xFF12CD0C), tint: true);
    if (n.contains('SEPARACAO'))
      return (label: 'Em Separação', icon: 'assets/icons/em_separacao.png', cor: const Color(0xFF00CBFE), tint: true);
    if (n.contains('EDITADO'))
      return (label: 'Editado', icon: 'assets/icons/editado.png', cor: const Color(0xFFED7D31), tint: false);
    if (n.contains('PRONTO'))
      return (label: 'Pronto para Retirada', icon: 'assets/icons/pronto_para_retirada.png', cor: const Color(0xFFFFAA02), tint: true);
    if (n.contains('ENTREGA'))
      return (label: 'Saiu para Entrega', icon: 'assets/icons/saiu_para_entrega.png', cor: const Color(0xFFCE00FF), tint: true);
    if (n.contains('RETORNAR'))
      return (label: 'Retornar para Estoque', icon: 'assets/icons/retornar_para_estoque.png', cor: const Color(0xFFDC2626), tint: true);
    if (n.contains('CANCEL'))
      return (label: 'Cancelado', icon: 'assets/icons/cancelado.png', cor: const Color(0xFFDC2626), tint: true);
    if (n.contains('DEVOLV'))
      return (label: 'Devolvido', icon: 'assets/icons/devolvido.png', cor: const Color(0xFFDC2626), tint: true);
    if (n.contains('ENTREGUE') || n.contains('FINALIZ'))
      return (label: 'Entregue', icon: 'assets/icons/entregue.png', cor: const Color(0xFF12CD0C), tint: true);
    return (label: nome, icon: 'assets/icons/criado.png', cor: const Color(0xFF9CA3AF), tint: true);
  }

  String _formatarDataBr(String? data) {
    if (data == null || data.isEmpty) return '';
    try {
      final dt = DateTime.parse(data).toLocal();
      final p = (int v) => v.toString().padLeft(2, '0');
      return '${p(dt.day)}/${p(dt.month)}/${dt.year} ${p(dt.hour)}:${p(dt.minute)}';
    } catch (_) {
      return data;
    }
  }

  Widget _timeline() {
    final passos = _pedido.timelines;
    if (passos.isEmpty) return const SizedBox.shrink();
    DateTime? previous;
    final linhas = <Map<String, dynamic>>[];
    for (final p in passos) {
      String duracao = 'Duração: 0s';
      Color corDur = const Color(0xFF9CA3AF);
      final cur = _parseData(p.data);
      if (previous != null && cur != null) {
        final diff = cur.difference(previous);
        duracao = 'Duração: ${_formatarDuracao(diff)}';
        corDur = diff.inMilliseconds > 30 * 60 * 1000
            ? const Color(0xFFDC2626)
            : const Color(0xFF9CA3AF);
      }
      linhas.add({'t': p, 'duracao': duracao, 'cor': corDur});
      if (cur != null) previous = cur;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: linhas.map((l) {
          final t = l['t'] as Timeline;
          final info = _timelineInfo(t.nome ?? '');
          final dataBr = _formatarDataBr(t.data);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Container(height: 2, color: const Color(0xFFE0E0E0)),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 42,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: Center(
                          child: Image.asset(
                            info.icon,
                            width: 30,
                            height: 30,
                            color: info.tint ? info.cor : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 64),
                      child: _textoDestacado(info.label, info.cor),
                    ),
                    if (dataBr.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(dataBr,
                            style: const TextStyle(
                                fontSize: 9, color: Color(0xFF9CA3AF)),
                            textAlign: TextAlign.center),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F1F1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(l['duracao'] as String,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: l['cor'] as Color)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  DateTime? _parseData(String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      return DateTime.parse(data).toLocal();
    } catch (_) {
      return null;
    }
  }

  // Texto com contorno (borda) para destacar os rótulos da linha do tempo
  // (Criado, Chegada, etc.) sobre o círculo branco, sem alterar o layout.
  Widget _textoDestacado(String texto, Color cor) => Stack(
        alignment: Alignment.center,
        children: [
          Text(
            texto,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
                foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.25
                ..color = const Color(0xFF1F2937),
            ),
          ),
          Text(
            texto,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937)),
          ),
        ],
      );

  Widget _badgeTempoTotal() {
    final passos = _pedido.timelines;
    if (passos.length < 2) return const SizedBox.shrink();
    final first = _parseData(passos.first.data);
    final last = _parseData(passos.last.data);
    if (first == null || last == null) return const SizedBox.shrink();
    final texto = 'Tempo total: ${_formatarDuracao(last.difference(first))}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFECECEC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(texto,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333))),
    );
  }

  String _formatarDuracao(Duration d) {
    final totalSec = d.inSeconds.abs().clamp(1, 1 << 60);
    final dias = totalSec ~/ (24 * 3600);
    final horas = (totalSec % (24 * 3600)) ~/ 3600;
    final minutos = (totalSec % 3600) ~/ 60;
    final segundos = totalSec % 60;
    final sb = StringBuffer();
    if (dias > 0) sb.write('${dias}d ');
    if (horas > 0 || dias > 0) sb.write('${horas}h ');
    if (minutos > 0 || horas > 0 || dias > 0) sb.write('${minutos}m ');
    sb.write('${segundos}s');
    return sb.toString();
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
                    onPressed: () => _ligar(_pedido.cliente!.telefone!),
                  ),
                ],
              ),
            if (_pedido.cliente?.endereco != null)
              _linhaDado(Icons.location_on, _enderecoCompleto()),
          ],
        ),
      );

  String _enderecoCompleto() {
    final c = _pedido.cliente;
    if (c == null) return 'Endereço não informado';
    final b = StringBuffer();
    if (c.endereco != null && c.endereco!.isNotEmpty) b.write(c.endereco);
    if (c.numero != null && c.numero!.isNotEmpty) b.write(', ${c.numero}');
    if (c.complemento != null && c.complemento!.isNotEmpty)
      b.write(' - ${c.complemento}');
    if (c.bairro != null && c.bairro!.isNotEmpty) b.write(' - ${c.bairro}');
    if (c.cidade != null && c.cidade!.isNotEmpty) b.write(' - ${c.cidade}');
    if (c.uf != null && c.uf!.isNotEmpty) b.write('/${c.uf}');
    if (c.cep != null && c.cep!.isNotEmpty) b.write(' - CEP: ${c.cep}');
    final s = b.toString().trim();
    return s.isEmpty ? 'Endereço não informado' : s;
  }

  Widget _cardRecebedor() => _card(
        titulo: 'Recebedor',
        child: _linhaDado(Icons.person_outline,
            _pedido.recebedor?.nome ?? 'Não informado',
            negrito: true, size: 16),
      );

  Widget _cardMotivo() {
    final motivos = _pedido.motivo;
    final status = _pedido.status.toUpperCase();
    final badges = <Widget>[];
    if (motivos != null && motivos.isNotEmpty) {
      for (final m in motivos) {
        final t = m.texto;
        if (t == null || t.isEmpty) continue;
        badges.add(Text(t,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDC2626))));
      }
    } else if (status == 'CANCELADO' || status == 'DEVOLVIDO') {
      badges.add(Text(
          status == 'CANCELADO'
              ? 'Cancelado sem motivo informado'
              : 'Devolvido sem motivo informado',
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFDC2626))));
    }
    if (badges.isEmpty) return const SizedBox.shrink();
    return _card(
      titulo: 'Motivo do cancelamento',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: badges,
      ),
    );
  }

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
                    'R\$ ${CurrencyFormatter.formatarMoeda(_pedido.valorTotal)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CD137))),
              ],
            ),
          ],
        ),
      );

  Widget _itemRow(Item i) => _ItemRowDetalhe(item: i);

  Future<void> _ligar(String numero) async {
    final limpo = numero.replaceAll(RegExp(r'[^0-9+]'), '');
    if (limpo.isEmpty) return;
    try {
      await launchUrl(Uri.parse('tel:$limpo'));
    } catch (_) {}
  }

  Widget _cardTokens() => _card(
        titulo: 'Tokens do pedido',
        headerTrailing: SizedBox(
          width: 30,
          height: 30,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              _mostrarTokens ? Icons.visibility : Icons.visibility_off,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _mostrarTokens = !_mostrarTokens),
            tooltip: _mostrarTokens ? 'Ocultar tokens' : 'Mostrar tokens',
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _linhaToken('Token Cliente', _tkMasc('tokenCliente')),
            const SizedBox(height: 2),
            _linhaToken('Token Retirada', _tkMasc('tokenRetirada')),
            const SizedBox(height: 2),
            _linhaToken('Token Insucesso', _tkMasc('tokenInsucesso')),
          ],
        ),
      );

  Widget _linhaToken(String label, String valor) => RichText(
        text: TextSpan(
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            TextSpan(
                text: valor,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
          ],
        ),
      );

  String _tkMasc(String k) {
    final v = _tk(k);
    if (v == '--' || v.isEmpty) return v;
    return _mostrarTokens ? v : '••••••••';
  }

  String _tk(String k) {
    final dt = _pedido.deliveryToken;
    final doPedido = dt == null
        ? null
        : <String, dynamic>{
            'tokenCliente': dt.tokenCliente,
            'tokenRetirada': dt.tokenRetirada,
            'tokenInsucesso': dt.tokenInsucesso,
          }[k];
    var v = _tokens?[k] ?? doPedido;
    // Fallback: token persistido localmente na retirada (Kotlin getDeliveryToken)
    if ((v == null || v.toString().isEmpty) && k == 'tokenRetirada') {
      final salvo = widget.session.getDeliveryToken(_pedido.numero);
      if (salvo != null && salvo.isNotEmpty) v = salvo;
    }
    return (v == null || v.toString().isEmpty) ? '--' : v.toString();
  }

  Widget _card(
          {required String titulo,
          required Widget child,
          Widget? headerTrailing}) =>
      Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(_cinzaBorda), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: const BoxDecoration(
                color: const Color(0xFFEF2E2E),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(titulo,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (headerTrailing != null) headerTrailing,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ],
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
            Text('R\$ ${CurrencyFormatter.formatarMoeda(v)}',
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
      if (_temMaisDe3Dias()) {
        // RETIRAR PEDIDO + CANCELAR PEDIDO lado a lado (larguras/alturas iguais)
        badges.add(Row(
          children: [
            Expanded(
              child: _badgeAcao(
                  'RETIRAR PEDIDO', const Color(0xFFFFAA02), _acaoRetirar),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _badgeAcao(
                  'CANCELAR PEDIDO', const Color(0xFFF80032), _acaoCancelarRetirada,
                  raio: 8),
            ),
          ],
        ));
      } else {
        badges.add(_badgeAcao(
            'RETIRAR PEDIDO', const Color(0xFFFFAA02), _acaoRetirar));
      }
    } else if (s.contains('ENTREGA')) {
      badges.add(_badgeAcao(
          'ENTREGADOR VOLTOU', const Color(0xFFF80032), _acaoEntregadorVoltou));
    } else if (s.contains('RETORNAR')) {
      badges.add(_badgeAcao('DEVOLVER PARA O ESTOQUE', const Color(0xFFF80032),
          _acaoDevolverEstoque));
    } else if (s.contains('FINALIZADO')) {
      badges.add(_badgeAcao(
          'CANCELAR', const Color(0xFFF80032), _acaoCancelarHistorico,
          raio: 8));
    }
    if (badges.isEmpty) return const SizedBox.shrink();

    // NOTA FISCAL: só para pedidos entregues (Histórico / FINALIZADO / ENTREGUE)
    final temNota = (_pedido.notaFiscalChave ?? '').isNotEmpty &&
        (s.contains('FINALIZADO') || s.contains('ENTREGUE'));

    final children = <Widget>[];
    if (temNota) {
      if (badges.length == 1) {
        children.add(Row(
          children: [
            Expanded(child: _badgeAcaoNotaFiscal()),
            const SizedBox(width: 8),
            Expanded(child: badges.first),
          ],
        ));
      } else {
        children.add(_badgeAcaoNotaFiscal());
        children.add(const SizedBox(height: 8));
        children.addAll(badges);
      }
    } else {
      children.addAll(badges);
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _mostrarAcao ? 1 : 0,
      child: IgnorePointer(
        ignoring: !_mostrarAcao,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          color: const Color(_bgTela),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _badgeAcaoNotaFiscal() => Container(
        height: 48,
        decoration: BoxDecoration(
            color: Colors.black, borderRadius: BorderRadius.circular(8)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VisualizarDanfeScreen(
                  session: widget.session,
                  apiService: widget.apiService,
                  chave: _pedido.notaFiscalChave!,
                  url: _pedido.notaFiscalUrl,
                ),
              ));
            },
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.description, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('NOTA FISCAL',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _badgeAcao(String texto, Color cor, VoidCallback onTap,
          {double raio = 8}) =>
      Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
            color: cor, borderRadius: BorderRadius.circular(raio)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(raio),
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

  String _normOrigem(String? origem) =>
      (origem ?? 'SHIP_FROM_STORE').trim().replaceAll(' ', '_').toUpperCase();

  void _sucesso(String msg) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SucessoAnimado(),
              const SizedBox(height: 16),
              const Text('Sucesso',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A))),
              const SizedBox(height: 8),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF555555), fontSize: 14)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE31837),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('OK',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _aviso(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _acaoSeparar() async {
    try {
      await widget.apiService.separarPedido(
          _normOrigem(_pedido.origem), _pedido.codigoExterno ?? _pedido.numero);
      _sucesso('Pedido em separação.');
    } catch (e) {
      _erroMsg(e);
    }
  }

  Future<void> _acaoConfirmar() async {
    final temSmartphone =
        _pedido.itens.any((i) => i.quantidadeImeis > 0);
    if (temSmartphone) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => SmartphoneConfirmacaoDialog(
          pedido: _pedido,
          onConfirm: (quantidades, imeis) async {
            await _confirmarComImeis(quantidades, imeis);
          },
          onCancel: () {
            _aviso('Confirmação cancelada');
          },
        ),
      );
      return;
    }

    final res = await MaestroDialogs.quantidadeNovo(context, _pedido);
    if (res == null) return;
    final (quantidadesEditadas, nenhum) = res;
    final itens = _pedido.itens;
    final origem = _normOrigem(_pedido.origem);
    final codigoExterno = _pedido.codigoExterno ?? _pedido.numero;
    final numero = _pedido.numero;

    int novaQtd(Item it) {
      final sap = it.codigoSAP ?? '';
      if (nenhum) return 0;
      return quantidadesEditadas[sap] ?? it.quantidade;
    }

    // Recusa total: todos os itens com quantidade 0
    final recusaTotal = nenhum ||
        itens.isNotEmpty &&
            itens.every((it) => novaQtd(it) == 0);

    if (recusaTotal) {
      final motivos = await _carregarMotivosRecusa(origem, _pedido.status ?? '');
      final motivo = motivos.isEmpty
          ? 'RECUSA_TOTAL'
          : await MaestroDialogs.motivoRadio(
              context, titulo: 'Selecione o motivo da recusa', opcoes: motivos);
      if (motivo == null || motivo.isEmpty) return;
      try {
        await widget.apiService.updateInventory(numero, [], 0.0,
            corpoVazio: true);
        await widget.apiService.recusarPedido(origem, codigoExterno, motivo);
        _sucesso('Pedido recusado.');
      } catch (e) {
        _erroMsg(e);
      }
      return;
    }

    final houveAlteracao =
        itens.any((it) => novaQtd(it) != it.quantidade);

    if (houveAlteracao) {
      // Salvar flag de edição IMEDIATAMENTE (antes da API, espelha Kotlin)
      try {
        final itensJson = jsonEncode(itens.map((it) => {
          'codigoEAN': it.codigoEAN,
          'codigoSAP': it.codigoSAP,
          'descricao': it.descricao,
          'quantidade': it.quantidade,
        }).toList());
        widget.session.savePedidoItens(
            _pedido.id, itensJson,
            numero: _pedido.numero,
            codigoExterno: _pedido.codigoExterno ?? '');
        widget.session.saveEditFlag(
            _pedido.id,
            numero: _pedido.numero,
            codigoExterno: _pedido.codigoExterno ?? '');
      } catch (_) {}
      // 2º diálogo: confirmação parcial com motivo
      // 2º diálogo: confirmação parcial com motivo
      final alterados = <(String, int, int)>[];
      for (final it in itens) {
        final n = novaQtd(it);
        if (n != it.quantidade) {
          alterados.add((it.codigoSAP ?? it.descricao ?? 'item', it.quantidade, n));
        }
      }
      final total = itens.fold<int>(0, (s, it) => s + novaQtd(it));
      final motivos = await _carregarMotivosRecusa(origem, _pedido.status ?? '');
      final motivo = motivos.isEmpty
          ? null
          : await MaestroDialogs.confirmacaoParcial(context,
              totalItens: total, alterados: alterados, motivos: motivos);
      if (motivo == null) return;
      // atualiza inventário (somente itens alterados) e confirma
      try {
        final itensComErro = _buildItensBody(itens, novaQtd)
            .where((m) {
              final sap = m['codigoSAP'] ?? '';
              final it = itens.firstWhere(
                  (x) => (x.codigoSAP ?? '') == sap,
                  orElse: () => itens.first);
              return novaQtd(it) != it.quantidade;
            })
            .toList();
        final novoValorTotal = _calcularValorTotal(itens, novaQtd);
        await widget.apiService.updateInventory(numero, itensComErro, novoValorTotal);
        await _executarConfirmacao(origem, codigoExterno, itens, novaQtd,
            editado: true, motivo: motivo);
      } catch (e) {
        _erroMsg(e);
      }
      return;
    }

    // Sem alteração: diálogo "tudo certo"
    final conf = await MaestroDialogs.tudoCerto(context, itens.length);
    if (conf != true) return;
    try {
      await _executarConfirmacao(origem, codigoExterno, itens, novaQtd,
          editado: false, motivo: null);
      _sucesso('Separação confirmada.');
    } catch (e) {
      _erroMsg(e);
    }
  }

  Future<void> _confirmarComImeis(
      Map<String, int> quantidades, Map<String, List<String>> imeis) async {
    final itens = _pedido.itens;
    final origem = _normOrigem(_pedido.origem);
    final codigoExterno = _pedido.codigoExterno ?? _pedido.numero;
    final numero = _pedido.numero;

    int novaQtd(Item it) {
      final key = it.codigoSAP ?? it.codigoEAN ?? it.descricao ?? '';
      return quantidades[key] ?? it.quantidade;
    }

    final houveAlteracao =
        itens.any((it) => novaQtd(it) != it.quantidade);

    if (houveAlteracao) {
      // Salvar flag de edição IMEDIATAMENTE (antes da API, espelha Kotlin)
      try {
        final itensJson = jsonEncode(itens.map((it) => {
          'codigoEAN': it.codigoEAN,
          'codigoSAP': it.codigoSAP,
          'descricao': it.descricao,
          'quantidade': it.quantidade,
        }).toList());
        widget.session.savePedidoItens(
            _pedido.id, itensJson,
            numero: _pedido.numero,
            codigoExterno: _pedido.codigoExterno ?? '');
        widget.session.saveEditFlag(
            _pedido.id,
            numero: _pedido.numero,
            codigoExterno: _pedido.codigoExterno ?? '');
      } catch (_) {}
      final alterados = <(String, int, int)>[];
      for (final it in itens) {
        final n = novaQtd(it);
        if (n != it.quantidade) {
          alterados.add(
              (it.codigoSAP ?? it.descricao ?? 'item', it.quantidade, n));
        }
      }
      final total = itens.fold<int>(0, (s, it) => s + novaQtd(it));
      final motivos = await _carregarMotivosRecusa(origem, _pedido.status ?? '');
      final motivo = motivos.isEmpty
          ? null
          : await MaestroDialogs.confirmacaoParcial(context,
              totalItens: total, alterados: alterados, motivos: motivos);
      if (motivo == null) return;
      try {
        final itensComErro = _buildItensBody(itens, novaQtd, imeis)
            .where((m) {
              final sap = m['codigoSAP'] ?? '';
              final it = itens.firstWhere((x) => (x.codigoSAP ?? '') == sap,
                  orElse: () => itens.first);
              return novaQtd(it) != it.quantidade;
            })
            .toList();
        final novoValorTotal = _calcularValorTotal(itens, novaQtd);
        await widget.apiService.updateInventory(numero, itensComErro, novoValorTotal);
        await _executarConfirmacao(origem, codigoExterno, itens, novaQtd,
            editado: true, motivo: motivo, imeisEditados: imeis);
      } catch (e) {
        _erroMsg(e);
      }
      return;
    }

    final conf = await MaestroDialogs.tudoCerto(context, itens.length);
    if (conf != true) return;
    try {
      await _executarConfirmacao(origem, codigoExterno, itens, novaQtd,
          editado: false, motivo: null, imeisEditados: imeis);
      _sucesso('Separação confirmada.');
    } catch (e) {
      _erroMsg(e);
    }
  }

  List<Map<String, dynamic>> _buildItensBody(
      List<Item> itens, int Function(Item) novaQtd,
      [Map<String, List<String>>? imeisEditados]) {
    return itens.map((it) {
      final n = novaQtd(it);
      final valorUnitario = it.valorUnitario;
      final sap = it.codigoSAP ?? '';
      final digitados = imeisEditados?[sap];
      final List<dynamic> imeisFinal;
      final int qtdImeis;
      if (digitados != null && digitados.isNotEmpty) {
        imeisFinal = [digitados];
        qtdImeis = digitados.length;
      } else {
        imeisFinal = it.imeis;
        qtdImeis = (it.imeis as List?)?.length ?? 0;
      }
      return <String, dynamic>{
        'codigoEAN': it.codigoEAN ?? '',
        'codigoSAP': it.codigoSAP ?? '',
        'descricao': it.descricao ?? '',
        'quantidade': it.quantidade,
        'quantidadeTotal': n,
        'valorUnitario': valorUnitario,
        'valorTotal': valorUnitario * n,
        'estoque': it.estoque ?? 0,
        'estoqueInicial': it.estoque ?? 0,
        'precoVenda': it.precoVenda ?? 0.0,
        'peso': 0.0,
        'quantidadeImeis': qtdImeis,
        'imeis': imeisFinal,
        'preVenda': false,
      };
    }).toList();
  }

  double _calcularValorTotal(List<Item> itens, int Function(Item) novaQtd) {
    final subtotal =
        itens.fold<double>(0.0, (s, it) => s + it.valorUnitario * novaQtd(it));
    return subtotal -
        (_pedido.valorDesconto ?? 0.0) +
        (_pedido.valorEntrega ?? 0.0);
  }

  Future<void> _executarConfirmacao(
      String origem,
      String codigoExterno,
      List<Item> itens,
      int Function(Item) novaQtd,
      {required bool editado,
      String? motivo,
      Map<String, List<String>>? imeisEditados}) async {
    final itensAtualizados =
        _buildItensBody(itens, novaQtd, imeisEditados);
    final novoValorTotal = _calcularValorTotal(itens, novaQtd);
    final codigosSapAlterados = <String>[];
    for (final it in itens) {
      if (novaQtd(it) != it.quantidade) {
        codigosSapAlterados.add(it.codigoSAP ?? '');
      }
    }
    final body = <String, dynamic>{
      'valorTotal': novoValorTotal,
      'valorDesconto': _pedido.valorDesconto,
      'valorEntrega': _pedido.valorEntrega,
      'editado': editado,
      'recusado': null,
      'retry': false,
      'itens': itensAtualizados,
      if (motivo != null) 'motivo': motivo,
    };
    final itensQuery =
        codigosSapAlterados.isNotEmpty ? codigosSapAlterados.join(',') : null;
    await widget.apiService.confirmarPedido(origem, codigoExterno,
        body: body,
        editado: editado,
        motivo: motivo,
        itens: itensQuery);
    // Salvar flag de edição e itens originais localmente (espelha Kotlin)
    if (editado) {
      try {
        final itensJson = jsonEncode(itens.map((it) => {
          'codigoEAN': it.codigoEAN,
          'codigoSAP': it.codigoSAP,
          'descricao': it.descricao,
          'quantidade': it.quantidade,
        }).toList());
        widget.session.savePedidoItens(
            _pedido.id, itensJson,
            numero: _pedido.numero,
            codigoExterno: _pedido.codigoExterno ?? '');
        widget.session.saveEditFlag(
            _pedido.id,
            numero: _pedido.numero,
            codigoExterno: _pedido.codigoExterno ?? '');
      } catch (_) {}
    }
    _sucesso('Separação confirmada.');
    // Atualiza localmente os itens com a quantidade alterada, para o card
    // do item ficar vermelho (foiAlterado) sem depender do reload da API.
    if (mounted) {
      setState(() {
        _pedido = _pedido.copyWith(itens: itens.map((it) {
          final n = novaQtd(it);
          if (n != it.quantidade) {
            return it.copyWith(quantidadeTotal: n);
          }
          return it;
        }).toList());
      });
    }
  }

  Future<List<String>> _carregarMotivosRecusa(String origem, String status) async {
    try {
      return await widget.apiService.getMotivosRecusa();
    } catch (_) {
      return [];
    }
  }

  Future<void> _acaoRetirar() async {
    final numero = _pedido.numero;
    final tipo = (_pedido.tipoEntrega ?? '').toUpperCase();
    final canal = (_pedido.canalDeVendas ?? '').toUpperCase();
    final origem = _normOrigem(_pedido.origem);
    // "Pegue na Loja Hoje" (cliente retira na loja) é o fluxo da loja: nós
    // digitamos o token informado e finalizamos (Packk/FINALIZADO). Corresponde
    // a tipoEntrega == 'RETIRADA' ou origem == 'PEGUE_NA_LOJA_HOJE'.
    final isPegueNaLoja =
        tipo == 'RETIRADA' || origem == 'PEGUE_NA_LOJA_HOJE';
    // EXTERNA + Americanas/Magazine (e NÃO Pegue na Loja) => fluxo inverso:
    // exibimos o token para o entregador que vem buscar (SAIU_PARA_ENTREGA).
    final isReserva = !isPegueNaLoja &&
        tipo == 'EXTERNA' &&
        (canal.contains('MAGAZINE') || canal.contains('AMERICANAS'));

    String? tokenRetirada;
    String? tokenInsucesso;
    try {
      final tokens = await widget.apiService.getDeliveryTokens(numero);
      tokenRetirada = tokens['tokenRetirada']?.toString();
      tokenInsucesso = tokens['tokenInsucesso']?.toString();
    } catch (_) {}
    tokenRetirada ??= _pedido.deliveryToken?.tokenRetirada;
    tokenInsucesso ??= _pedido.deliveryToken?.tokenInsucesso;

    // Kotlin: se há tokenRetirada, valida o código localmente (sem rede);
    // caso contrário, chama a API de verificação.
    Future<bool> validarCodigo(String codigo) async {
      if (tokenRetirada != null && tokenRetirada!.isNotEmpty) {
        if (codigo != tokenRetirada) {
          _erroMsg('Código inválido!');
          return false;
        }
        return true;
      }
      final v = await widget.apiService.validarCodigoRetirada(codigo, numero);
      if (!v) {
        _erroMsg('Código inválido!');
        return false;
      }
      return true;
    }

    try {
      if (isReserva) {
        // Americanas/Magazine Delivery: mostramos o token alfa-numérico p/ o
        // entregador colocar no app dele; nós confirmamos -> SAIU_PARA_ENTREGA.
        // Kotlin inicia o polling ANTES de confirmar (aguarda o entregador).
        final tk = (tokenRetirada?.isNotEmpty == true)
            ? tokenRetirada!
            : (tokenInsucesso?.isNotEmpty == true ? tokenInsucesso! : '---');
        _iniciarPollingEntregador();
        final ok = await MaestroDialogs.tokenInsucesso(context, tk,
            reserva: true);
        if (ok != true) {
          _pollingEntregador?.cancel();
          return;
        }
        await _confirmarRetirada(token: tk);
      } else if (isPegueNaLoja) {
        // Pegue na Loja Hoje (cliente retira na loja): a loja DIGITA o código
        // informado pelo cliente e finaliza (Packk/FINALIZADO). Nunca exibe o
        // dialog de token de insucesso (esse é para fluxo de entrega/entregador).
        final codigo = await MaestroDialogs.token(context,
            nome: _pedido.cliente?.nome ?? '',
            numero: _pedido.codigoExterno ?? _pedido.numero);
        if (codigo == null || codigo.isEmpty) return;
        if (!await validarCodigo(codigo)) return;
        await _confirmarRetirada(token: codigo);
      } else if (tokenInsucesso != null && tokenInsucesso!.isNotEmpty) {
        // Demais deliveries (ex.: iFood EXTERNA): token de insucesso é
        // informativo; ao fechar, volta para a lista (Kotlin finaliza a activity).
        await MaestroDialogs.tokenInsucesso(context, tokenInsucesso!,
            reserva: false);
        Navigator.of(context).maybePop();
      } else {
        // iFood Delivery (sem token de insucesso): digitamos o token informado
        final codigo = await MaestroDialogs.token(context,
            nome: _pedido.cliente?.nome ?? '',
            numero: _pedido.codigoExterno ?? _pedido.numero);
        if (codigo == null || codigo.isEmpty) return;
        if (!await validarCodigo(codigo)) return;
        await _confirmarRetirada(token: codigo);
      }
    } catch (e) {
      _erroMsg(e);
    }
  }

  Future<void> _confirmarRetirada({String? token}) async {
    final isLoja = _normOrigem(_pedido.origem) == 'PEGUE_NA_LOJA_HOJE' ||
        (_pedido.tipoEntrega ?? '').toUpperCase() == 'RETIRADA';
    if (isLoja) {
      await widget.apiService.retirarPedidoPackk(
          _pedido.codigoExterno ?? _pedido.numero);
    } else {
      await widget.apiService.retirarPedidoShipFromStore(
          _pedido.codigoExterno ?? _pedido.numero);
    }
    // Persiste o token digitado/validado (Kotlin: salvarTokenEPedido) para
    // exibir depois (ex.: histórico como ENTREGUE).
    if (token != null && token.isNotEmpty) {
      widget.session.saveDeliveryToken(_pedido.numero, token);
    }
    _sucesso('Pedido retirado.');
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
          _normOrigem(_pedido.origem), _pedido.codigoExterno ?? _pedido.numero,
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
          _normOrigem(_pedido.origem),
          _pedido.codigoExterno ?? _pedido.numero,
          recaptchaToken: res.$3,
          observacao: res.$2);
      _sucesso('Pedido retornado ao estoque.');
    } catch (e) {
      _erroMsg(e);
    }
  }

  Future<void> _acaoDevolverEstoque() async {
    final numero = _pedido.codigoExterno ?? _pedido.numero;
    final ok = await MaestroDialogs.confirmar(context,
        titulo: 'Devolver ao estoque',
        mensagem:
            'Deseja realmente cancelar este pedido e devolvê-lo ao estoque?\n\nPedido: $numero',
        textoSim: 'SIM, CANCELAR');
    if (ok != true) return;
    try {
      await widget.apiService.retornarParaEstoque(
          _normOrigem(_pedido.origem), numero);
      _sucesso('Pedido devolvido ao estoque.');
    } catch (e) {
      _erroMsg(e);
    }
  }

  Future<void> _acaoCancelarHistorico() async {
    final res = await MaestroDialogs.devolverHistorico(context);
    if (res == null) return;
    try {
      await widget.apiService.cancelarPedido(
          _normOrigem(_pedido.origem),
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

  class _ItemRowDetalhe extends StatefulWidget {
    final Item item;
    const _ItemRowDetalhe({required this.item});
    @override
    State<_ItemRowDetalhe> createState() => _ItemRowDetalheState();
  }

  class _ItemRowDetalheState extends State<_ItemRowDetalhe> {
    bool _expanded = false;
    late final List<String> _secundarios;

    @override
    void initState() {
      super.initState();
      final ean = widget.item.codigoEAN;
      _secundarios = widget.item.eans
          .where((e) => ean == null || ean.isEmpty || e != ean)
          .toList();
    }

    @override
    Widget build(BuildContext context) {
      final i = widget.item;
      final alterado = i.foiAlterado;
      final recusado = i.foiRecusado;
      final corItem = recusado
          ? const Color(0xFFDC2626)
          : alterado
              ? const Color(0xFFDC2626)
              : const Color(0xFF2B2B2B);
      final corSecundaria = recusado || alterado
          ? const Color(0xFFDC2626)
          : const Color(0xFF888888);
      final qtd = i.quantidadeEfetiva;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 45,
                  child: Text('${qtd}x',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: corItem)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.descricao ?? '',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: corItem)),
                      InkWell(
                        onTap: _secundarios.isNotEmpty
                            ? () => setState(() => _expanded = !_expanded)
                            : null,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('EAN: ${i.codigoEAN ?? ''}',
                                  style: TextStyle(
                                      fontSize: 11, color: corSecundaria)),
                            ),
                            if (_secundarios.isNotEmpty)
                              const SizedBox(width: 6),
                            if (_secundarios.isNotEmpty)
                              Icon(
                                  _expanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: const Color(0xFF6B7280)),
                          ],
                        ),
                      ),
                      if (_expanded && _secundarios.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _secundarios
                                .map((e) => Text('EAN: $e',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: corSecundaria)))
                                .toList(),
                          ),
                        ),
                      Text('SAP: ${i.codigoSAP ?? ''}',
                          style: TextStyle(
                              fontSize: 11, color: corSecundaria)),
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
                      Text('R\$ ${CurrencyFormatter.formatarMoeda(i.valorUnitario * qtd)}',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: corItem)),
                      Text(
                          '${qtd}x R\$ ${CurrencyFormatter.formatarMoeda(i.valorUnitario)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: corItem,
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
    }
  }


/// Animação de sucesso: o círculo verde surge e o check é desenhado
/// progressivamente por traço.
class _SucessoAnimado extends StatefulWidget {
  const _SucessoAnimado();

  @override
  State<_SucessoAnimado> createState() => _SucessoAnimadoState();
}

class _SucessoAnimadoState extends State<_SucessoAnimado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            color: Color(0xFFE8F6EE),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(
              painter: _CheckPainter(progress: _ctrl.value),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  _CheckPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // Círculo desenhado na primeira metade da animação.
    final circleT = (progress / 0.5).clamp(0.0, 1.0);
    if (circleT > 0) {
      final circlePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2E7D32);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 3),
        -pi / 2,
        2 * pi * circleT,
        false,
        circlePaint,
      );
    }

    // Check desenhado na segunda metade.
    if (progress > 0.45) {
      final checkT = ((progress - 0.45) / 0.55).clamp(0.0, 1.0);
      final p1 = center + Offset(-radius * 0.5, 0);
      final p2 = center + Offset(-radius * 0.08, radius * 0.38);
      final p3 = center + Offset(radius * 0.55, -radius * 0.38);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy);
      final metrics = path.computeMetrics().first;
      final extracted = metrics.extractPath(0, metrics.length * checkT);
      final checkPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF2E7D32);
      canvas.drawPath(extracted, checkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
