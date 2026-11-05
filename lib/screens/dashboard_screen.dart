import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/dashboard.dart';
import '../network/api_service.dart';
import '../widgets/app_icon.dart';
import '../widgets/maestro_refresh.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService apiService;
  final ValueChanged<String>? onAbrirStatus;
  final ValueChanged<String>? onBuscar;

  const DashboardScreen({
    super.key,
    required this.apiService,
    this.onAbrirStatus,
    this.onBuscar,
  });

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  static const Color _azul = Color(0xFF0EA5E9);
  static const Color _texto = Color(0xFF1A1A1A);
  static const Color _suave = Color(0xFF6B7280);
  static const Color _fundo = Color(0xFFF0F0F0);

  final _buscaController = TextEditingController();
  DashboardData? _dados;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> recarregar() => _carregar();

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resposta = await widget.apiService.getDashboard();
      if (!mounted) return;
      setState(() {
        _dados = resposta.data;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const ColoredBox(color: _fundo, child: SizedBox.shrink());
    }
    if (_erro != null || _dados == null) {
      return ColoredBox(
        color: _fundo,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 44, color: _suave),
                const SizedBox(height: 10),
                const Text(
                  'Não foi possível carregar o dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _texto,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _carregar,
                  child: const Text('TENTAR NOVAMENTE'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dados = _dados!;
    return ColoredBox(
      color: _fundo,
      child: MaestroRefresh(
        cor: _azul,
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          children: [
            _cabecalho(dados.header),
            const SizedBox(height: 10),
            _resumo(dados.summaryCards),
            const SizedBox(height: 10),
            _andamento(dados.ordersInProgress),
            const SizedBox(height: 10),
            if (dados.statusCards.isNotEmpty) ...[
              _status(dados.statusCards),
              const SizedBox(height: 10),
            ],
            _tabela(dados.tables.expiring),
            const SizedBox(height: 10),
            _tabela(dados.tables.overdue),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho(DashboardHeader header) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header.date.isEmpty ? 'Dashboard' : header.date,
            style: const TextStyle(
              color: _texto,
              fontSize: 19,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (header.updatedAt.isNotEmpty)
                Text(
                  'Atualizado às ${header.updatedAt}',
                  style: const TextStyle(color: _suave, fontSize: 11),
                ),
              const SizedBox(width: 2),
              InkWell(
                onTap: _carregar,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.refresh, color: _azul, size: 16),
                ),
              ),
            ],
          ),
          if (widget.onBuscar != null) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _buscaController,
              textInputAction: TextInputAction.search,
              onSubmitted: (texto) => widget.onBuscar?.call(texto),
              style: const TextStyle(color: _texto, fontSize: 13),
              decoration: InputDecoration(
                hintText: header.searchPlaceholder.isEmpty
                    ? 'Busque por pedido'
                    : header.searchPlaceholder,
                hintStyle: const TextStyle(color: _suave, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, color: _suave, size: 19),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resumo(List<DashboardSummaryCard> cards) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _cardResumo(cards[i]),
          ],
        ],
      ),
    );
  }

  Widget _cardResumo(DashboardSummaryCard card) {
    final cor = _corResumo(card);
    final icone = switch (card.id) {
      'onTime' => Icons.sentiment_satisfied_alt,
      'confirmationTime' => Icons.schedule,
      'refusalRate' => Icons.cancel,
      _ => Icons.insights,
    };
    return Container(
      width: 220,
      height: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, color: cor, size: 21),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  card.value,
                  style: const TextStyle(
                    color: _texto,
                    fontSize: 22,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            card.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _suave,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const Spacer(),
          Text(
            card.goal.toUpperCase(),
            style: const TextStyle(
              color: _suave,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Color _corResumo(DashboardSummaryCard card) {
    if (card.status == 'error' || card.status == 'danger') {
      return const Color(0xFFDC2626);
    }
    if (card.id == 'confirmationTime') return const Color(0xFFEAB308);
    return _corHex(card.color, const Color(0xFF65AF84));
  }

  Widget _andamento(OrdersInProgress andamento) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  andamento.title.isEmpty
                      ? 'Pedidos em andamento'
                      : andamento.title,
                  style: const TextStyle(
                    color: _texto,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _azul.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${andamento.total}',
                  style: const TextStyle(
                    color: _azul,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in andamento.items) _linhaAndamento(item, andamento.total),
        ],
      ),
    );
  }

  Widget _linhaAndamento(OrderProgressItem item, int total) {
    final cor = _corAndamento(item.color);
    final valor = total <= 0 ? 0.0 : (item.value / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 124,
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _suave,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: valor,
                minHeight: 8,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(cor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 24,
            child: Text(
              '${item.value}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _texto,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _status(List<DashboardStatusCard> cards) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _cardStatus(cards[i])),
        ],
      ],
    );
  }

  Widget _cardStatus(DashboardStatusCard card) {
    final cor = card.code == 'RETORNAR_PARA_ESTOQUE'
        ? const Color(0xFFB62F2C)
        : const Color(0xFF00CBFE);
    final Widget icone = switch (card.code) {
      'EM_SEPARACAO' =>
        appIcon('assets/icons/ic_sync.svg', width: 22, height: 22, color: cor),
      'RETORNAR_PARA_ESTOQUE' => appIcon(
          'assets/icons/ic_estoque.svg',
          width: 22,
          height: 22,
          color: cor,
        ),
      _ => const Icon(Icons.chevron_right, color: _suave, size: 22),
    };
    final clicavel = widget.onAbrirStatus != null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            clicavel ? () => widget.onAbrirStatus?.call(card.code) : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      card.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _suave,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (clicavel)
                    const Icon(Icons.chevron_right,
                        color: _suave, size: 18),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  icone,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      card.value,
                      style: const TextStyle(
                        color: _texto,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabela(DashboardTable tabela) {
    final cor = _corVariante(tabela.variant);
    if (tabela.rows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 38),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconeVazio(tabela),
              color: const Color(0xFF9CA3AF),
              size: 46,
            ),
            const SizedBox(height: 14),
            Text(
              tabela.emptyTitle.isEmpty
                  ? 'Nenhum pedido encontrado'
                  : tabela.emptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _texto,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (tabela.emptyDescription.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                tabela.emptyDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _suave,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: cor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tabela.title,
            style: const TextStyle(
              color: _texto,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (tabela.infoText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              tabela.infoText,
              style: const TextStyle(
                color: _suave,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _linhasTabela(tabela, cor),
        ],
      ),
    );
  }

  Widget _linhasTabela(DashboardTable tabela, Color cor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final coluna in tabela.columns)
                SizedBox(
                  width: 130,
                  child: Text(
                    coluna,
                    style: TextStyle(
                      color: cor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final row in tabela.rows) _linhaTabela(tabela, row),
        ],
      ),
    );
  }

  Widget _linhaTabela(DashboardTable tabela, dynamic row) {
    final valores = _valoresLinha(tabela, row);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          for (var i = 0; i < valores.length; i++)
            SizedBox(
              width: 130,
              child: i == 0
                  ? InkWell(
                      onTap: () async {
                        await Clipboard.setData(
                            ClipboardData(text: valores[i]));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Pedido copiado: ${valores[i]}'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              valores[i],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _texto,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy, size: 13, color: _suave),
                        ],
                      ),
                    )
                  : Text(
                      valores[i],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _texto,
                        fontSize: 11,
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  List<String> _valoresLinha(DashboardTable tabela, dynamic row) {
    if (row is List) return row.map((e) => e.toString()).toList();
    if (row is Map) {
      if (row['cells'] is List) {
        return (row['cells'] as List).map((e) => e.toString()).toList();
      }
      String pick(List<String> keys) {
        for (final k in keys) {
          final v = row[k];
          if (v != null && v.toString().trim().isNotEmpty) {
            return v.toString();
          }
        }
        return '';
      }

      return tabela.columns.map((col) {
        final c = col.toLowerCase();
        if (c.contains('pedido') || c.contains('nº') || c.contains('n°')) {
          return pick(['externalCode', 'external_code', 'numero', 'id']);
        }
        if (c.contains('vence') || c.contains('aguardando')) {
          return pick(['waiting', 'tempo', 'aguardando']);
        }
        if (c.contains('cliente')) {
          return pick(['client', 'cliente', 'customer']);
        }
        if (c.contains('canal')) {
          return pick(['channel', 'salesChannel', 'canal']);
        }
        if (c.contains('entrega')) {
          return pick(['delivery', 'entrega']);
        }
        return pick([col]);
      }).toList();
    }
    return [row?.toString() ?? ''];
  }

  Color _corHex(String hex, Color fallback) {
    final limpo = hex.replaceAll('#', '').trim();
    if (limpo.length != 6) return fallback;
    final valor = int.tryParse(limpo, radix: 16);
    return valor == null ? fallback : Color(0xFF000000 | valor);
  }

  Color _corAndamento(String nome) {
    switch (nome.toLowerCase()) {
      case 'green':
        return const Color(0xFF16A34A);
      case 'cyan':
        return const Color(0xFF06B6D4);
      case 'yellow':
        return const Color(0xFFEAB308);
      case 'magenta':
        return const Color(0xFFD946EF);
      case 'red':
        return const Color(0xFFDC2626);
      default:
        return _azul;
    }
  }

  IconData _iconeVazio(DashboardTable tabela) {
    if (tabela.variant.toLowerCase() == 'red') {
      return Icons.sentiment_satisfied_alt_outlined;
    }
    return Icons.sentiment_neutral_outlined;
  }

  Color _corVariante(String variante) {
    switch (variante.toLowerCase()) {
      case 'blue':
        return const Color(0xFF2563EB);
      case 'red':
        return const Color(0xFFDC2626);
      case 'yellow':
        return const Color(0xFFD97706);
      default:
        return _azul;
    }
  }
}
