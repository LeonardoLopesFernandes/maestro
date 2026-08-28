import 'package:flutter/material.dart';
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

  ({String texto, Color cor})? get _acao {
    switch (_statusNormalizado) {
      case 'NOVO_PEDIDO':
      case 'INCLUIDO':
      case 'VISUALIZADO':
      case 'NOVO':
        return (texto: 'Em Separação', cor: const Color(0xFF12CD0C));
      case 'EM_SEPARACAO':
      case 'SEPARACAO':
        return (texto: 'Confirmar Separação', cor: const Color(0xFF12CD0C));
      case 'PRONTO_PARA_SAIR':
      case 'PRONTO':
        return (texto: 'Retirar Pedido', cor: const Color(0xFFFFAA02));
      default:
        return null;
    }
  }

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
    final acao = _acao;
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
                        'R\$ ${CurrencyFormatter.format(pedido.valorTotal)}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF16A34A))),
                  ],
                ),
                // Bloco E: botão de ação
                if (acao != null)
                  Container(
                    width: double.infinity,
                    height: 44,
                    margin: const EdgeInsets.only(top: 8),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: acao.cor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: onAcao ?? onTap,
                      child: Text(acao.texto,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
