import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/pedido.dart';
import '../network/api_service.dart';
import '../network/session_manager.dart';
import '../utils/constants.dart';
import '../utils/log_helper.dart';
import 'historico_screen.dart';
import '../widgets/pedido_card.dart';
import '../widgets/app_icon.dart';
import 'detalhes_pedido_screen.dart';

// Cores da marca Maestro (vermelho) — não copiamos o azul do Kotlin.
const int _red = 0xFFE60000;
const int _redDark = 0xFFF80032;
const int _bgLight = 0xFFF0F0F0;

// Cores próprias de cada aba (como no Kotlin). O azul original da aba
// Cores exatas das abas conforme activity_main.xml do Kotlin.
const List<int> _tabColors = [
  0xFF12CD0C, // Novos - verde
  0xFF00CBFE, // Separação - ciano
  0xFFFFAA02, // Retirada - laranja
  0xFFCE00FF, // Entrega - roxo
  0xFFB62F2C, // Estoque - vermelho escuro
  0xFF7F8C8D, // Histórico - cinza
];

const List<String> _tabIconAssets = [
  'assets/icons/ic_clipboard.svg',
  'assets/icons/ic_sync.svg',
  'assets/icons/ic_bag.svg',
  'assets/icons/ic_truck.svg',
  'assets/icons/ic_estoque.svg',
  'assets/icons/ic_historico.svg',
];

class HomeScreen extends StatefulWidget {
  final SessionManager session;
  final ApiService apiService;

  const HomeScreen({super.key, required this.session, required this.apiService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  CountResponse _counts = CountResponse();
  final TextEditingController _searchController = TextEditingController();
  Timer? _pollTimer;
  int _currentIndex = 0;
  final Map<String, GlobalKey<_PedidoListTabState>> _listKeys = {};
  final GlobalKey<HistoricoScreenState> _historicoKey =
      GlobalKey<HistoricoScreenState>();

  final AudioPlayer _player = AudioPlayer();
  int _prevNovo = 0;
  bool _somTocado = false;

  // Filtros
  int _minDias = 7;
  bool _ordemDataInclusao = true;

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
    WidgetsBinding.instance.addObserver(this);
    _carregarCounts();
    // Polling em tempo real: atualiza os counts E recarrega a lista da aba
    // visível, para os pedidos aparecerem sem pull-to-refresh.
    _iniciarPolling();
  }

  void _iniciarPolling() {
    _pollTimer?.cancel();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => _pollAtualizar());
    _pollAtualizar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pausa o polling em segundo plano (evita toasts de erro de rede ao
    // voltar sem conexão); retoma ao voltar para o app.
    if (state == AppLifecycleState.resumed) {
      _iniciarPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pollTimer?.cancel();
    }
  }

  Future<void> _pollAtualizar() async {
    await _carregarCounts();
    _recarregarAbaAtiva();
  }

  void _recarregarAbaAtiva() {
    if (!mounted) return;
    final aba = _abas[_currentIndex];
    if (aba.status == 'HISTORICO') {
      _historicoKey.currentState?.reload();
    } else {
      _listKeys[aba.status]?.currentState?._carregar(reset: true);
    }
  }

  // Recarrega todas as abas de pedido + histórico. Usado ao voltar da tela de
  // detalhes: um pedido que mudou de status (separação/confirmar/retirar)
  // precisa sumir da aba atual e aparecer imediatamente na aba de destino.
  void _recarregarTodasAbas() {
    if (!mounted) return;
    for (final aba in _abas) {
      if (aba.status == 'HISTORICO') {
        _historicoKey.currentState?.reload();
      } else {
        _listKeys[aba.status]?.currentState?._carregar(reset: true);
      }
    }
  }

  Future<void> _carregarCounts() async {
    try {
      final c = await widget.apiService
          .getCounts(widget.session.getUserStore() ?? Constants.defaultStore);
      if (mounted) setState(() => _counts = c);
      _verificarSomNovo(c.novoPedido);
    } catch (_) {
    }
  }

  // Toca o som de novo pedido ao entrar na home (se houver) e quando a
  // contagem de novos aumenta durante o polling (igual ao web/app Kotlin).
  void _verificarSomNovo(int novo) {
    if (novo > 0 && (novo > _prevNovo || !_somTocado)) {
      _tocarSomNovo();
    }
    _prevNovo = novo;
    _somTocado = true;
  }

  Future<void> _tocarSomNovo() async {
    try {
      await _player.play(UrlSource(Constants.orderAlertSoundUrl));
    } catch (_) {
      // CDN pode bloquear no dispositivo; som silencioso em caso de falha.
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

  // Texto do badge abaixo do header, ex: "1 Novo", "2 Em Separação",
  // "X Pronto para Retirada", "XXXX em Histórico".
  String _contagemTexto(int index) {
    final n = _contagemPara(index);
    switch (index) {
      case 0:
        return '$n ${n == 1 ? 'Novo pedido' : 'Novos pedidos'}';
      case 1:
        return '$n Em Separação';
      case 2:
        return '$n Pronto para Retirada';
      case 3:
        return '$n Saiu Para Entrega';
      case 4:
        return '$n Retornar ao Estoque';
      case 5:
        return '$n em Histórico';
      default:
        return '$n';
    }
  }

  void _onNavTap(int i) {
    setState(() => _currentIndex = i);
    // Recarrega a aba ao entrar para mostrar dados atualizados na hora.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recarregarAbaAtiva());
  }

  Color get _corAba => Color(_tabColors[_currentIndex]);

  void _abrirPerfil() {
    showDialog(
      context: context,
      builder: (_) => _PerfilDialog(session: widget.session),
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
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('SIM, SAIR',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD50000),
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('NÃO',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
    if (sair == true) {
      // Sai do app sem deslogar (mantém a sessão).
      SystemNavigator.pop();
    }
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _searchController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _confirmarSaida();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: const Color(_bgLight),
        body: Column(
          children: [
            _header(),
            // No Histórico o contador já está no header, então a barra branca
            // (statusBar) não aparece: a pesquisa sobe no lugar dela.
            if (_currentIndex != 5) _statusBar(),
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
      ),
    );
  }

  Widget _header() => Container(
        decoration: BoxDecoration(
          color: _corAba,
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 8,
        ),
        child: Row(
          children: [
            Image.asset('assets/icons/ic_logo_header.webp',
                height: 40, width: 40),
            // No Histórico o contador fica no header, ao lado do ícone, e a
            // barra de pesquisa sobe para o lugar dele.
            if (_currentIndex == 5) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _contagemTexto(5),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const Spacer(),
            IconButton(
              icon: appIcon('assets/icons/ic_profile.svg',
                  width: 24, height: 24, color: Colors.white),
              onPressed: _abrirPerfil,
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
                    color: _corAba,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _contagemTexto(_currentIndex),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _bottomNav() => Container(
        height: 76,
        margin: const EdgeInsets.only(top: 6, bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          ),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 8, offset: Offset(0, -2)),
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
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        appIcon(
                            _tabIconAssets[i],
                            width: 28,
                            height: 28,
                            color: ativo ? cor : const Color(0xFF9AA0A6)),
                        if (count > 0)
                          Positioned(
                            top: -8,
                            right: -10,
                            child: Container(
                              alignment: Alignment.center,
                              constraints: const BoxConstraints(
                                  minWidth: 16, minHeight: 16),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: cor,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                  count > 99 ? '99+' : '$count',
                                  style: const TextStyle(
                                      color: Colors.white,
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
                            color: ativo ? cor : const Color(0xFF9AA0A6),
                            fontSize: 10,
                            fontWeight:
                                ativo ? FontWeight.bold : FontWeight.w600)),
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
        key: _historicoKey,
        session: widget.session,
        apiService: widget.apiService,
        search: _searchController.text,
      );
    }
    return _PedidoListTab(
      key: _listKeys.putIfAbsent(
          aba.status, () => GlobalKey<_PedidoListTabState>()),
      apiService: widget.apiService,
      session: widget.session,
      status: aba.status,
      search: _searchController.text,
      minDias: _minDias,
      ordemDataInclusao: _ordemDataInclusao,
      tabIcon: _tabIconAssets[aba.index],
      onVoltarDetalhes: _recarregarTodasAbas,
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
  final String tabIcon;
  final VoidCallback? onVoltarDetalhes;

  const _PedidoListTab({
    super.key,
    required this.apiService,
    required this.session,
    required this.status,
    required this.search,
    required this.minDias,
    required this.ordemDataInclusao,
    required this.tabIcon,
    this.onVoltarDetalhes,
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
  bool _buscando = false;
  int _geracao = 0;
  // Filtro de aba da Retirada ('' = GERAL).
  String _aba = '';
  Map<String, int> _abaCounts = const {};

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
    if (_buscando && !reset) return; // evita corrida, mas reset sempre recarrega
    final ger = ++_geracao;
    if (reset) {
      _skip = 0;
      _pedidos = [];
      _temMais = true;
    }
    if (!_temMais) return;
    _buscando = true;
    setState(() => _carregando = true);
    try {
      final resp = await widget.apiService.getPedidosPaged(
        skip: _skip,
        limit: _limit,
        status: widget.status,
        minDias: widget.minDias,
        ordemDataInclusao: widget.ordemDataInclusao,
        find: widget.search.isNotEmpty ? widget.search : null,
        aba: _aba.isEmpty ? null : _aba,
      );
      if (mounted && ger == _geracao) {
        setState(() {
          _pedidos.addAll(resp.pedidos);
          _skip += resp.pedidos.length;
          _temMais = resp.pedidos.length >= _limit;
          if (resp.counts.isNotEmpty) _abaCounts = resp.counts;
        });
      }
    } catch (e) {
      if (mounted &&
          ger == _geracao &&
          !LogHelper.ehErroDeRede(e) &&
          !LogHelper.ehErroDeSessao(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar: $e')),
        );
      }
    } finally {
      _buscando = false;
      if (mounted && ger == _geracao) setState(() => _carregando = false);
    }
  }

  void _selecionarAba(String aba) {
    if (_aba == aba) return;
    setState(() => _aba = aba);
    _carregar(reset: true);
  }

  Widget _chip(String label, String aba, String icon, int? count) {
    final ativo = _aba == aba;
    final bg = ativo ? const Color(_red) : const Color(0xFFE6E6E6);
    final fg = ativo ? Colors.white : const Color(0xFF616161);
    return GestureDetector(
      onTap: () => _selecionarAba(aba),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            appIcon(icon,
                width: 16, height: 16, color: fg),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: ativo ? Colors.white24 : const Color(0xFFCFCFCF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _abasRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip('GERAL', '', 'assets/icons/geral.svg', null),
            _chip('COLETA TARDIA', 'COLETA_TARDIA', 'assets/icons/tardia.svg',
                _abaCounts['coletaTardia']),
            _chip('EM ANÁLISE', 'EM_ANALISE', 'assets/icons/analise.svg',
                _abaCounts['emAnalise']),
            _chip('+3 DIAS PARADO', 'PARADO_3_DIAS', 'assets/icons/3dias.svg',
                _abaCounts['parado3Dias']),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status != Constants.statusProntoParaSair) {
      return _buildConteudo();
    }
    return Column(
      children: [
        _abasRow(),
        Expanded(child: _buildConteudo()),
      ],
    );
  }

  Widget _buildConteudo() {
    if (_carregando && _pedidos.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: Color(_red)));
    }
    if (_pedidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            appIcon(
              widget.tabIcon,
              width: 90,
              height: 90,
              color: Colors.grey.shade400,
            ),
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
          final editado = widget.session.pedidoFoiEditado(
              p.id, numero: p.numero, codigoExterno: p.codigoExterno);
          return PedidoCard(
            pedido: p,
            editado: editado,
            onAnalisarColeta: (opcao) async {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(opcao == 'confirmar'
                    ? 'Coleta do pedido confirmada!'
                    : 'Registrado: pedido não coletado.'),
              ));
            },
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DetalhesPedidoScreen(
                    session: widget.session,
                    apiService: widget.apiService,
                    pedidoId: p.id,
                    pedido: p,
                  ),
                ),
              );
              if (mounted) widget.onVoltarDetalhes?.call();
            },
          );
        },
      ),
    );
  }
}

class _PerfilDialog extends StatefulWidget {
  final SessionManager session;
  const _PerfilDialog({required this.session});

  @override
  State<_PerfilDialog> createState() => _PerfilDialogState();
}

class _PerfilDialogState extends State<_PerfilDialog> {
  final ImagePicker _picker = ImagePicker();
  File? _foto;

  @override
  void initState() {
    super.initState();
    final path = widget.session.getProfilePhoto();
    if (path != null) {
      final f = File(path);
      if (f.existsSync()) _foto = f;
    }
  }

  Future<void> _escolherFoto() async {
    try {
      final picked = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70, maxWidth: 1200);
      if (picked == null) return;
      final arquivo = File(picked.path);
      final dir = await getApplicationDocumentsDirectory();
      final destino =
          File('${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await arquivo.copy(destino.path);
      widget.session.saveProfilePhoto(destino.path);
      setState(() => _foto = destino);
    } catch (e) {
      LogHelper.e('Perfil: erro ao escolher foto', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nome = widget.session.getUserName() ??
        widget.session.getUserEmail() ??
        'Usuário';
    final email = widget.session.getUserEmail() ?? '-';
    final loja = widget.session.getUserStore() ?? Constants.defaultStore;
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  icon: const Icon(Icons.close,
                      color: Color(_redDark), size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _escolherFoto,
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFFF1F3F4)),
                child: ClipOval(
                  child: _foto != null
                      ? Image.file(_foto!, fit: BoxFit.cover)
                      : const Icon(Icons.person,
                          size: 90, color: Color(_redDark)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Toque para alterar a foto',
                style:
                    TextStyle(color: Color(0xFF888888), fontSize: 12)),
            const SizedBox(height: 16),
            Text(nome,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(_redDark))),
            const SizedBox(height: 4),
            Text(email,
                style:
                    const TextStyle(fontSize: 16, color: Color(0xFF555555))),
            const SizedBox(height: 12),
            Text('Loja $loja',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(_redDark))),
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
                    final nav = Navigator.of(context);
                    widget.session.logout();
                    nav.pop();
                    nav.pushNamedAndRemoveUntil(
                        '/login', (route) => false);
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
    );
  }
}
