import 'package:flutter/material.dart';
import '../models/pedido.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';

class PedidoCard extends StatelessWidget {
  final Pedido pedido;
  final VoidCallback onTap;

  const PedidoCard({super.key, required this.pedido, required this.onTap});

  Color get _statusColor {
    switch (pedido.status) {
      case Constants.statusNovoPedido:
        return const Color(Constants.BLUE_500);
      case Constants.statusEmSeparacao:
        return const Color(Constants.ORANGE_500);
      case Constants.statusProntoParaSair:
        return const Color(Constants.GREEN_500);
      case Constants.statusSaiuParaEntrega:
        return const Color(Constants.BLUE_500);
      case Constants.statusRetornarEstoque:
        return const Color(Constants.RED_500);
      default:
        return const Color(Constants.GRAY_400);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itensQtd =
        pedido.itens.fold<int>(0, (s, e) => s + e.quantidade);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      pedido.titulo,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pedido.itens.length} ${pedido.itens.length == 1 ? "item" : "itens"}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pedido.cliente?.nome != null)
                    Text(pedido.cliente!.nome!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  _linha(Icons.store, pedido.loja),
                  _linha(Icons.inventory_2, 'Itens: $itensQtd'),
                  if (pedido.valorTotal > 0)
                    _linha(Icons.attach_money,
                        'Total: ${CurrencyFormatter.format(pedido.valorTotal)}'),
                  if (pedido.tipoEntrega != null)
                    _linha(Icons.local_shipping, pedido.tipoEntrega!),
                  if (pedido.dhEntregaEstimada != null)
                    _linha(Icons.schedule,
                        'Entrega estimada: ${pedido.dhEntregaEstimada!}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linha(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(Constants.GRAY_400)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: Color(Constants.MEDIUM_TEXT))),
          ),
        ],
      ),
    );
  }
}
