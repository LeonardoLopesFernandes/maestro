import 'package:flutter/material.dart';
import 'dart:async';
import '../models/pedido.dart';
import '../network/api_service.dart';
import '../network/session_manager.dart';
import '../utils/constants.dart';
import 'historico_screen.dart';
import 'price_tags_screen.dart';
import '../widgets/pedido_card.dart';
import 'detalhes_pedido_screen.dart';

// Cores da marca Maestro (vermelho) — não copiamos o azul do Kotlin.
const int _red = 0xFFE60000;
const int _redDark = 0xFFF80032;
const int _bgLight = 0xFFF0F0F0;

// Cores próprias de cada aba (como no Kotlin). O azul original da aba
// Separação foi trocado por rosa para não usar a cor de tema azul.
const List<int> _tabColors = [
  0xFF12CD0C, // Novos - verde
  0xFFDB2777, // Separação - rosa (substitui o azul)
  0xFFFFAA02, // Retirada - laranja
  0xFFCE00FF, // Entrega - roxo
  0xFFB62F2C, // Estoque - vermelho escuro
  0xFF7F8C8D, // Histórico - cinza
];

const List<IconData> _tabIcons = [
  Icons.assignment_outlined,
  Icons.autorenew,
  Icons.shopping_bag_outlined,
  Icons.local_shipping_outlined,
  Icons.inventory_2_outlined,
  Icons.history,
];

class HomeScreen extends StatefulWidget {
  final SessionManager session;
  final ApiService apiService;

  const HomeScreen({super.key, required this.session, required this.apiService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CountResponse _counts = CountResponse();
  bool _carregandoCounts = true;
  final TextEditingController _searchController = TextEditingController();
  bool _buscando = false;
  Timer? _pollTimer;
  int _currentIndex = 0;

  // Filtros
  int _minDias = 7;
  bool _ordemDataInclusao = true;
  bool _retirada = true;
  bool _pagamento = true;

  final List<_Aba> _abas = const [
    _Aba('Novos', Constants.statusNovoPedido, 0),
    _Aba('Separação', Constants.statusEmSeparacao, 1),
    _Aba('Retirada', Constants.statusProntoParaSair, 2),
    _Aba('Entrega', Constants.statusSaiuParaEntrega, 3),
    _Aba('Estoque', Constants.statusRetornarEstoque, 4),
    _Aba('Histórico', 'HISTORICO', 5),
  ];

  @override
  void initState() {
    super.initState();
    _carregarCounts();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 45), (_) => _carregarCounts());
  }

  Future<void> _carregarCounts() async {
    try {
      final c = await widget.apiService
          .getCounts(widget.session.getUserStore() ?? Constants.defaultStore);
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

  void _onNavTap(int i) => setState(() => _currentIndex = i);

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
    final nome = widget.session.getUserName() ??
        widget.session.getUserEmail() ??
        'Usuário';
    final email = widget.session.getUserEmail() ?? '-';
    final loja = widget.session.getUserStore() ?? Constants.defaultStore;
    showDialog(
      context: context,
      barrierColor: const Color(0xFFFDECEC),
      builder: (_) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: const Color(0xFFFDECEC),
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            children: [
              const SizedBox(height: 20),
              IconButton(
                icon: const Icon(Icons.arrow_back, color: const Color(_redDark), size: 40),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 8),
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child:
                    const Icon(Icons.person, size: 86, color: const Color(_redDark)),
              ),
              const SizedBox(height: 12),
              Text(nome,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(_redDark))),
              const SizedBox(height: 4),
              Text(email,
                  style: const TextStyle(fontSize: 16, color: const Color(_redDark))),
              const SizedBox(height: 12),
              Container(width: 80, height: 1, color: const Color(0xFFE0B4B4)),
              const SizedBox(height: 12),
              Text('Loja $loja',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(_redDark))),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      widget.session.clearToken();
                      widget.session.clearAll();
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                    child: const Text('SAIR',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmarSaida() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sair do Maestro',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: const Text('Tem certeza que deseja sair do aplicativo?',
            textAlign: TextAlign.center),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32)),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('SIM, SAIR',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD50000)),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('NÃO',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
    return sair == true;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmarSaida,
      child: Scaffold(
        backgroundColor: const Color(_bgLight),
        body: Column(
          children: [
            _header(),
            _statusBar(),
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
              child: IndexedStack(
                index: _currentIndex,
                children: _abas.map(_conteudo).toList(),
              ),
            ),
            _bottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
        height: 56,
        color: const Color(_red),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (_buscando)
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Buscar pedido...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              )
            else
              Image.asset('assets/ic_maestro_logo.png',
                  height: 40, width: 40, color: Colors.white),
            const Spacer(),
            IconButton(
              icon: Icon(_buscando ? Icons.close : Icons.search,
                  color: Colors.white),
              onPressed: () => setState(() {
                _buscando = !_buscando;
                if (!_buscando) _searchController.clear();
              }),
            ),
            IconButton(
              icon: const Icon(Icons.person, color: Colors.white),
              onPressed: _abrirPerfil,
            ),
            IconButton(
              icon: const Icon(Icons.label, color: Colors.white),
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
        ),
      );

  Widget _statusBar() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(_red),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_contagemPara(0)} Novos Pedidos',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _abrirFiltro,
                  icon: const Icon(Icons.filter_list,
                      color: Colors.white, size: 16),
                  label: const Text('Filtrar',
                      style:
                          TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(_redDark),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Loja ${widget.session.getUserStore() ?? Constants.defaultStore}',
                style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 11,
                    fontWeight: FontWeight.normal),
              ),
            ),
          ],
        ),
      );

  Widget _bottomNav() => Container(
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, -1)),
          ],
        ),
        child: Row(
          children: _abas.asMap().entries.map((e) {
            final i = e.key;
            final aba = e.value;
            final ativo = _currentIndex == i;
            final count = _contagemPara(i);
            final cor = Color(_tabColors[i]);
            return Expanded(
              child: InkWell(
                onTap: () => _onNavTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 3,
                      width: 28,
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: ativo ? cor : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(_tabIcons[i], size: 26, color: cor),
                        if (count > 0)
                          Positioned(
                            top: -8,
                            right: -10,
                            child: Container(
                              constraints: const BoxConstraints(
                                  minWidth: 16, minHeight: 16),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: cor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('$count',
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(aba.titulo,
                        style: TextStyle(
                            color: cor,
                            fontSize: 10,
                            fontWeight: ativo
                                ? FontWeight.bold
                                : FontWeight.w600)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );

  Widget _conteudo(_Aba aba) {
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
      return const Center(
          child: CircularProgressIndicator(color: Color(_red)));
    }
    if (_pedidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 90, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Não há pedidos!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(_red),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Filtrar pedidos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Buscar por código ou cliente',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: _minDias,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [7, 15, 30, 60, 90]
                  .map((d) => DropdownMenuItem(value: d, child: Text('$d dias')))
                  .toList(),
              onChanged: (v) => setState(() => _minDias = v ?? 7),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Ordenar por data de inclusão'),
              value: _ordem,
              activeColor: Color(_red),
              onChanged: (v) => setState(() => _ordem = v),
            ),
            SwitchListTile(
              title: const Text('Retirada'),
              value: _retirada,
              activeColor: Color(_red),
              onChanged: (v) => setState(() => _retirada = v),
            ),
            SwitchListTile(
              title: const Text('Pagamento'),
              value: _pagamento,
              activeColor: Color(_red),
              onChanged: (v) => setState(() => _pagamento = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Limpar',
              style: TextStyle(color: Color(0xFF333333))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Color(_redDark)),
          onPressed: () => Navigator.of(context).pop({
            'minDias': _minDias,
            'ordemDataInclusao': _ordem,
            'retirada': _retirada,
            'pagamento': _pagamento,
          }),
          child: const Text('Aplicar',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
