import 'package:flutter/material.dart';
import '../models/pedido.dart';
import '../network/api_service.dart';
import '../network/session_manager.dart';
import '../utils/constants.dart';
import '../widgets/pedido_card.dart';
import 'detalhes_pedido_screen.dart';

class HistoricoScreen extends StatefulWidget {
  final SessionManager session;
  final ApiService apiService;
  final String search;

  const HistoricoScreen({
    super.key,
    required this.session,
    required this.apiService,
    this.search = "",
  });

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  List<Pedido> _pedidos = [];
  int _skip = 0;
  bool _carregando = true;
  bool _temMais = true;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _carregar(reset: true);
  }

  Future<void> _carregar({bool reset = false}) async {
    if (reset) {
      _skip = 0;
      _pedidos = [];
      _temMais = true;
    }
    if (!_temMais) return;
    setState(() => _carregando = true);
    try {
      final resp = await widget.apiService.getPedidos(
        store: widget.session.getUserStore() ?? Constants.defaultStore,
        status: Constants.statusFinalizado,
        skip: _skip,
        limit: _limit,
        minDias: 90,
        ordemDataInclusao: false,
        find: widget.search.isNotEmpty ? widget.search : null,
      );
      if (mounted) {
        setState(() {
          _pedidos.addAll(resp.pedidos);
          _skip += resp.pedidos.length;
          _temMais = resp.pedidos.length >= _limit;
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

  @override
  Widget build(BuildContext context) {
    if (_carregando && _pedidos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pedidos.isEmpty) {
      return const Center(
        child: Text('Nenhum pedido no histórico.',
            style: TextStyle(color: Color(Constants.GRAY_400))),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _carregar(reset: true),
      child: ListView.builder(
        itemCount: _pedidos.length + (_temMais ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _pedidos.length) {
            _carregar();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final p = _pedidos[i];
          return PedidoCard(
            pedido: p,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DetalhesPedidoScreen(
                  session: widget.session,
                  apiService: widget.apiService,
                  pedidoId: p.id,
                  pedido: p,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
