import 'package:flutter/material.dart';
import 'dart:async';
import '../models/pedido.dart';
import '../utils/currency_formatter.dart';

class PedidoCard extends StatelessWidget {
  final Pedido pedido;
  final VoidCallback onTap;
  final VoidCallback? onAcao;

  const PedidoCard(
      {super.key, required this.pedido, required this.onTap, this.onAcao});

  String get _statusNormalizado =>
      (pedido.status ?? '').toUpperCase().trim();

  ({String texto, Color cor}) get _badge {
    switch (_statusNormalizado) {
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
        return (texto: _formatStatus(pedido.status ?? ''),
            cor: Colors.transparent);
    }
  }

  String _formatStatus(String s) {
    if (s.isEmpty) return '—';
    return s
        .split('_')
        .map((p) => p.isEmpty ? p : p[0] + p.substring(1).toLowerCase())
        .join(' ');
  }

  bool get _mostraDuracao =>
      _statusNormalizado.contains('NOVO') ||
      _statusNormalizado.contains('SEPARACAO');

  String get _canalTexto {
    final c = pedido.canalDeVendas ?? '';
    if (c.toUpperCase().contains('EXTERNA')) return 'Delivery';
    if (c.toUpperCase().contains('AMERICANAS EXTERNA')) {
      return 'Americanas Delivery';
    }
    return c;
  }

  bool get _canalAzul =>
      (pedido.canalDeVendas ?? '').toUpperCase().contains('MAGAZINE');

  String get _entregaTexto {
    final t = pedido.tipoEntrega ?? '';
    if (t.toUpperCase().contains('RETIRADA')) return 'Pegue na Loja Hoje';
    if (t.toUpperCase().contains('EXTERNA')) return 'Delivery';
    return t;
  }

  String get _dataFormatada {
    final d = pedido.dataInclusao;
    if (d == null || d.isEmpty) return '--/--/---- --:--';
    try {
      final dt = DateTime.parse(d).toLocal();
      final p = (int n) => n.toString().padLeft(2, '0');
      return '${p(dt.day)}/${p(dt.month)}/${dt.year} ${p(dt.hour)}:${p(dt.minute)}';
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badge;
    final mostraCanal =
        pedido.canalDeVendas != null && pedido.canalDeVendas!.isNotEmpty;
    final mostraEntrega =
        pedido.tipoEntrega != null && pedido.tipoEntrega!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF475569), width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bloco A: cliente + número + badge
                Text(pedido.cliente?.nome ?? 'Cliente não informado',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(pedido.codigoExterno ?? '',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B))),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: badge.cor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(badge.texto,
                          style: TextStyle(
                              color: badge.cor == Colors.transparent
                                  ? const Color(0xFF1A1A1A)
                                  : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  height: 1,
                  color: const Color(0xFFF1F5F9),
                ),
                // Bloco B: tags
                if (mostraCanal || mostraEntrega)
                  Row(
                    children: [
                      if (mostraCanal)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _canalAzul
                                ? const Color(0xFF0086FF)
                                : const Color(0xFFF80032),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_canalTexto,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      if (mostraEntrega)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF760018),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(_entregaTexto,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                if (mostraCanal || mostraEntrega) const SizedBox(height: 8),
                // Bloco D: data + valor
                Row(
                  children: [
                    Expanded(
                      child: Text(_dataFormatada,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ),
                    Text(
                        'R\$ ${CurrencyFormatter.formatarMoeda(pedido.valorTotal)}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF16A34A))),
                  ],
                ),
                // Bloco E: barra de duração de separação (NOVO / EM SEPARAÇÃO)
                if (_mostraDuracao)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _DuracaoSeparacao(pedido),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Barra de duração de separação (igual ao Kotlin item_pedido): aparece em
// NOVO/EM_SEPARAÇÃO, fica verde até 35 min e vermelha depois.
class _DuracaoSeparacao extends StatefulWidget {
  final Pedido pedido;
  const _DuracaoSeparacao(this.pedido);

  @override
  State<_DuracaoSeparacao> createState() => _DuracaoSeparacaoState();
}

class _DuracaoSeparacaoState extends State<_DuracaoSeparacao> {
  static const int _limiteMin = 35;
  late final int _baseMs;
  late final int _momento;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _momento = DateTime.now().millisecondsSinceEpoch;
    final tc = widget.pedido.tempoConfirmacao;
    if (tc != null) {
      _baseMs = tc;
    } else {
      final di = widget.pedido.dataInclusao;
      if (di != null && di.isNotEmpty) {
        try {
          final dt = DateTime.parse(di).toLocal();
          _baseMs =
              DateTime.now().millisecondsSinceEpoch - dt.millisecondsSinceEpoch;
        } catch (_) {
          _baseMs = 0;
        }
      } else {
        _baseMs = 0;
      }
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _totalMin {
    final decorrido =
        _baseMs + (DateTime.now().millisecondsSinceEpoch - _momento);
    return (decorrido / 60000).toInt();
  }

  bool _dentroHorario() {
    final now = DateTime.now();
    final wd = now.weekday; // 1=seg .. 7=dom
    final horaAbre = wd == 7 ? 14 : 10;
    final horaFecha = wd == 7 ? 19 : 22;
    return now.hour >= horaAbre && now.hour < horaFecha;
  }

  @override
  Widget build(BuildContext context) {
    // Fallback (sem tempoConfirmacao) só conta dentro do horário da loja.
    if (widget.pedido.tempoConfirmacao == null && !_dentroHorario()) {
      return const SizedBox.shrink();
    }
    final totalMin = _totalMin;
    late final String texto;
    if (totalMin < 60) {
      texto = '$totalMin ${totalMin == 1 ? 'minuto' : 'minutos'}';
    } else {
      final h = totalMin ~/ 60;
      final m = totalMin % 60;
      final hs = h == 1 ? '1 hora' : '$h horas';
      final ms = m == 0
          ? ''
          : (m == 1 ? ' 1 minuto' : ' $m minutos');
      texto = '$hs$ms';
    }
    final verde = totalMin <= _limiteMin;
    final cor = verde ? const Color(0xFF28A745) : const Color(0xFFDC3545);
    final pct = (totalMin / _limiteMin * 100).clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Duração: $texto',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF555555))),
        const SizedBox(height: 4),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: pct / 100,
            child: Container(
              decoration: BoxDecoration(
                color: cor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
