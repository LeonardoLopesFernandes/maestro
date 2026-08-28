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
  String _filtro = 'TODOS';
  final _busca = TextEditingController();

  final List<_Filtro> _filtros = const [
    _Filtro('TODOS', 0xFF6B7280, ''),
    _Filtro('PEGUE NA LOJA', 0xFF0086FF, 'PEGUE'),
    _Filtro('DELIVERY', 0xFFFFAA02, 'DELIVERY'),
    _Filtro('IFOOD', 0xFFEF4444, 'IFOOD'),
    _Filtro('CANCELADO', 0xFFF80032, 'CANCELADO'),
    _Filtro('DEVOLVIDO', 0xFF7F8C8D, 'DEVOLVIDO'),
  ];

  @override
  void initState() {
    super.initState();
    _busca.text = widget.search;
    _busca.addListener(() => _carregar(reset: true));
    _carregar(reset: true);
  }

  Map<String, String?> get _params {
    switch (_filtro) {
      case 'CANCELADO':
        return {'status': 'CANCELADO', 'find': null};
      case 'DEVOLVIDO':
        return {'status': 'DEVOLVIDO', 'find': null};
      case 'TODOS':
        return {'status': Constants.statusFinalizado, 'find': null};
      default:
        final f = _filtros.firstWhere((e) => e.nome == _filtro);
        return {'status': Constants.statusFinalizado, 'find': f.find};
    }
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
      final p = _params;
      final resp = await widget.apiService.getPedidosPaged(
        skip: _skip,
        limit: _limit,
        status: p['status']!,
        minDias: 90,
        ordemDataInclusao: false,
        find: _busca.text.isNotEmpty
            ? _busca.text
            : (p['find'] != null ? p['find'] : null),
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
    return Container(
      color: const Color(0xFFF4F7F6),
      child: Column(
        children: [
          _barraBusca(),
          _badges(),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: _conteudo(),
          ),
        ],
      ),
    );
  }

  Widget _barraBusca() => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _busca,
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar no histórico...',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: Color(0xFF999999)),
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            if (_busca.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
                onPressed: () {
                  _busca.clear();
                  _carregar(reset: true);
                },
              ),
          ],
        ),
      );

  Widget _badges() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: Column(
          children: [
            Row(
              children: _filtros
                  .sublist(0, 3)
                  .map((f) => _badge(f))
                  .toList(),
            ),
            const SizedBox(height: 4),
            Row(
              children: _filtros
                  .sublist(3, 6)
                  .map((f) => _badge(f))
                  .toList(),
            ),
          ],
        ),
      );

  Widget _badge(_Filtro f) => Expanded(
        child: Container(
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: Color(f.cor),
            borderRadius: BorderRadius.circular(4),
            border: _filtro == f.nome
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _filtro = f.nome);
                _carregar(reset: true);
              },
              child: Center(
                child: Text(f.nome,
                    style: TextStyle(
                        fontSize: f.nome.length > 8 ? 10 : 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
          ),
        ),
      );

  Widget _conteudo() {
    if (_carregando && _pedidos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pedidos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 80, color: Colors.black12),
            SizedBox(height: 16),
            Text('Nenhum pedido no histórico',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _carregar(reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
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

class _Filtro {
  final String nome;
  final int cor;
  final String find;
  const _Filtro(this.nome, this.cor, this.find);
}
