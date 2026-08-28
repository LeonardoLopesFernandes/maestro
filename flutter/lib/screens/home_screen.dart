import 'package:flutter/material.dart';
import 'dart:async';
import '../models/pedido.dart';
import '../network/api_service.dart';
import '../network/session_manager.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import 'historico_screen.dart';
import 'price_tags_screen.dart';
import '../widgets/pedido_card.dart';
import 'detalhes_pedido_screen.dart';

class HomeScreen extends StatefulWidget {
  final SessionManager session;
  final ApiService apiService;

  const HomeScreen({super.key, required this.session, required this.apiService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CountResponse _counts = CountResponse();
  bool _carregandoCounts = true;
  final TextEditingController _searchController = TextEditingController();
  bool _buscando = false;
  Timer? _pollTimer;

  // Filtros
  int _minDias = 7;
  bool _ordemDataInclusao = true;
  bool _retirada = true;
  bool _pagamento = true;

  final List<_Aba> _abas = const [
    _Aba('Novos', Constants.statusNovoPedido, 0),
    _Aba('Em Separação', Constants.statusEmSeparacao, 1),
    _Aba('Prontos', Constants.statusProntoParaSair, 2),
    _Aba('Em Entrega', Constants.statusSaiuParaEntrega, 3),
    _Aba('Retornar', Constants.statusRetornarEstoque, 4),
    _Aba('Histórico', 'HISTORICO', 5),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _abas.length, vsync: this);
    _carregarCounts();
    _pollTimer = Timer.periodic(const Duration(seconds: 45), (_) => _carregarCounts());
  }

  Future<void> _carregarCounts() async {
    try {
      final c = await widget.apiService.getCounts(widget.session.getUserStore() ?? Constants.defaultStore);
      if (mounted) setState(() => _counts = c);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _carregandoCounts = false);
    }
  }

  int _contagemPara(int index) {
    switch (index) {
      case 0:
        return _counts.novoPedido;
      case 1:
        return _counts.emSeparacao;
      case 2:
        return _counts.prontoParaSair;
      case 3:
        return _counts.saiuParaEntrega;
      case 4:
        return _counts.retornarEstoque;
      default:
        return _counts.finalizado;
    }
  }

  Widget _tabLabel(_Aba aba) {
    final count = _contagemPara(aba.index);
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(aba.titulo),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      color: Color(Constants.RED_600),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmarSaida,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(Constants.RED_600),
          title: _buscando
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Buscar pedido...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                )
              : const Text('Maestro'),
          actions: [
            IconButton(
              icon: Icon(_buscando ? Icons.close : Icons.search),
              onPressed: () => setState(() {
                _buscando = !_buscando;
                if (!_buscando) _searchController.clear();
              }),
            ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _abrirFiltro,
            ),
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: _abrirPerfil,
            ),
            IconButton(
              icon: const Icon(Icons.label),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PriceTagsScreen(
                    session: widget.session,
                    apiService: widget.apiService,
                  ),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.white,
            tabs: _abas.map(_tabLabel).toList(),
          ),
        ),
        body: Column(
          children: [
            if (widget.session.isDemo())
              Container(
                width: double.infinity,
                color: Colors.black87,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: const Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.amber, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'MODO DEMONSTRAÇÃO — dados fictícios, sem login real.',
                        style: TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _abas.map((aba) {
            if (aba.status == 'HISTORICO') {
              return HistoricoScreen(
                session: widget.session,
                apiService: widget.apiService,
                search: _searchController.text,
              );
            }
            return _PedidoListTab(
              key: ValueKey(aba.status + _searchController.text),
              apiService: widget.apiService,
              session: widget.session,
              status: aba.status,
              search: _searchController.text,
              minDias: _minDias,
              ordemDataInclusao: _ordemDataInclusao,
            );
          }).toList(),
        ),
      ),
    ],
  ),
    ),
  );
  }

  Future<void> _abrirFiltro() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _FiltroDialog(
        minDias: _minDias,
        ordemDataInclusao: _ordemDataInclusao,
        retirada: _retirada,
        pagamento: _pagamento,
      ),
    );
    if (result != null) {
      setState(() {
        _minDias = result['minDias'];
        _ordemDataInclusao = result['ordemDataInclusao'];
        _retirada = result['retirada'];
        _pagamento = result['pagamento'];
      });
    }
  }

  void _abrirPerfil() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Perfil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usuário: ${widget.session.getUserEmail() ?? "-"}'),
            const SizedBox(height: 4),
            Text('Loja: ${widget.session.getUserStore() ?? Constants.defaultStore}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.session.clearToken();
              widget.session.clearAll();
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmarSaida() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair do app?'),
        content: const Text('Deseja realmente sair do Maestro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return sair == true;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class _Aba {
  final String titulo;
  final String status;
  final int index;

  const _Aba(this.titulo, this.status, this.index);
}

class _PedidoListTab extends StatefulWidget {
  final ApiService apiService;
  final SessionManager session;
  final String status;
  final String search;
  final int minDias;
  final bool ordemDataInclusao;

  const _PedidoListTab({
    super.key,
    required this.apiService,
    required this.session,
    required this.status,
    required this.search,
    required this.minDias,
    required this.ordemDataInclusao,
  });

  @override
  State<_PedidoListTab> createState() => _PedidoListTabState();
}

class _PedidoListTabState extends State<_PedidoListTab> {
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

  @override
  void didUpdateWidget(covariant _PedidoListTab old) {
    super.didUpdateWidget(old);
    if (old.search != widget.search ||
        old.minDias != widget.minDias ||
        old.ordemDataInclusao != widget.ordemDataInclusao) {
      _carregar(reset: true);
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
      final resp = await widget.apiService.getPedidosPaged(
        skip: _skip,
        limit: _limit,
        status: widget.status,
        minDias: widget.minDias,
        ordemDataInclusao: widget.ordemDataInclusao,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar: $e')),
        );
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
        child: Text('Nenhum pedido nesta aba.',
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
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DetalhesPedidoScreen(
                    session: widget.session,
                    apiService: widget.apiService,
                    pedidoId: p.id,
                    pedido: p,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FiltroDialog extends StatefulWidget {
  final int minDias;
  final bool ordemDataInclusao;
  final bool retirada;
  final bool pagamento;

  const _FiltroDialog({
    required this.minDias,
    required this.ordemDataInclusao,
    required this.retirada,
    required this.pagamento,
  });

  @override
  State<_FiltroDialog> createState() => _FiltroDialogState();
}

class _FiltroDialogState extends State<_FiltroDialog> {
  late int _minDias;
  late bool _ordem;
  late bool _retirada;
  late bool _pagamento;

  @override
  void initState() {
    super.initState();
    _minDias = widget.minDias;
    _ordem = widget.ordemDataInclusao;
    _retirada = widget.retirada;
    _pagamento = widget.pagamento;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtros'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            value: _minDias,
            decoration: const InputDecoration(labelText: 'Dias'),
            items: [7, 15, 30, 60, 90]
                .map((d) => DropdownMenuItem(value: d, child: Text('$d dias')))
                .toList(),
            onChanged: (v) => setState(() => _minDias = v ?? 7),
          ),
          SwitchListTile(
            title: const Text('Ordenar por data de inclusão'),
            value: _ordem,
            onChanged: (v) => setState(() => _ordem = v),
          ),
          SwitchListTile(
            title: const Text('Retirada'),
            value: _retirada,
            onChanged: (v) => setState(() => _retirada = v),
          ),
          SwitchListTile(
            title: const Text('Pagamento'),
            value: _pagamento,
            onChanged: (v) => setState(() => _pagamento = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop({
            'minDias': _minDias,
            'ordemDataInclusao': _ordem,
            'retirada': _retirada,
            'pagamento': _pagamento,
          }),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
