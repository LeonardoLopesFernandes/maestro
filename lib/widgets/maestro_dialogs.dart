import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/pedido.dart';
import 'recaptcha_dialog.dart';

// Cores conforme drawables do Kotlin
const _verde = 0xFF12CD0C;
const _verdeEscuro = 0xFF2E7D32;
const _vermelho = 0xFFF80032;
const _vermelhoDark = 0xFFD50000;
const _ifoodRed = 0xFFEA1D2C;

class MaestroDialogs {
  // Confirmação simples (usado em vários fluxos)
  static Future<bool?> confirmar(
    BuildContext context, {
    required String titulo,
    required String mensagem,
    String textoSim = 'SIM',
    String textoNao = 'NÃO',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(titulo,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: Text(mensagem, textAlign: TextAlign.center),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: const Color(_vermelho)),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(textoSim,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(_verdeEscuro)),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(textoNao,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // Dialog de token (digitado pelo operador — iFood, Pegue na Loja, etc.)
  // Dialog de digitação de token (Pegue na Loja / iFood) — igual ao XML dialog_token.
  // Campo numérico limitado a 4 dígitos; CONFIRMAR habilita só com código preenchido.
  static Future<String?> token(BuildContext context,
      {String nome = '', String numero = ''}) {
    final c = TextEditingController();
    bool habilitado = false;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (nome.isNotEmpty) ...[
                Text(nome,
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(_vermelhoDark)),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
              ],
              if (numero.isNotEmpty) ...[
                Text('#$numero',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
              ],
              TextField(
                controller: c,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Insira o código de retirada',
                  hintStyle: const TextStyle(
                      color: Color(0xFF8C8C8C), fontSize: 18),
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF5A7EB0))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF5A7EB0))),
                ),
                onChanged: (v) => set(() => habilitado = v.trim().isNotEmpty),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(_verdeEscuro),
                      disabledBackgroundColor: const Color(0xFF9E9E9E)),
                  onPressed: habilitado
                      ? () => Navigator.of(ctx).pop(c.text.trim())
                      : null,
                  child: const Text('CONFIRMAR',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(_vermelhoDark)),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('CANCELAR',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dialog de token (fluxo EXTERNA) — igual ao XML dialog_token_insucesso.
  // reserva=true  => Americanas/Magazine: entregador valida; libera CONFIRMAR RETIRADA
  // reserva=false => iFood/demais: token de insucesso informativo; FECHAR volta p/ lista
  static Future<bool?> tokenInsucesso(BuildContext context, String token,
      {bool reserva = false}) {
    final instrucao = reserva
        ? 'Informe o código para o entregador e aguarde a validação para liberar o pedido.'
        : 'Token de insucesso gerado!\n\n'
            '📍 INFORME AO ENTREGADOR:\n'
            '1. Copie este token\n'
            '2. Entregue ao entregador\n'
            '3. Ele deve inserir no app dele\n'
            '4. Após inserir, o pedido será finalizado';
    bool validado = false;
    bool liberado = false;
    bool confirmarHabilitado = false;
    bool ajudaAberta = false;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          if (reserva) {
            Future.delayed(const Duration(seconds: 2), () {
              if (ctx.mounted && !validado) set(() => validado = true);
            });
            Future.delayed(const Duration(seconds: 4), () {
              if (ctx.mounted && !confirmarHabilitado) {
                set(() {
                  liberado = true;
                  confirmarHabilitado = true;
                });
              }
            });
          }
          final fecharTexto = reserva ? 'CANCELAR' : 'FECHAR';
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.all(20),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 20),
                  // Código de retirada em destaque (com check verde)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Color(_verde), size: 24),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Código de retirada:',
                              style: TextStyle(
                                  fontSize: 15, color: Color(0xFF333333))),
                        ),
                        Text(token,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF222222))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(instrucao,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333)),
                      textAlign: TextAlign.left),
                  const SizedBox(height: 20),
                  _statusRetirada(
                    feito: validado,
                    titulo: 'Validação do código de retirada',
                    detalhe: validado
                        ? 'Entregador validou o código'
                        : 'Aguardando o entregador',
                  ),
                  const SizedBox(height: 12),
                  _statusRetirada(
                    feito: liberado,
                    titulo: 'Pedido liberado para entrega',
                    detalhe: liberado
                        ? 'Pedido liberado para entrega'
                        : 'Aguardando validação',
                  ),
                  const SizedBox(height: 24),
                  // Ajuda / SAL (expansível)
                  InkWell(
                    onTap: () => set(() => ajudaAberta = !ajudaAberta),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Se houver problemas na validação ou na retirada do pacote, entre em contato com o SAL.',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF666666)),
                          ),
                        ),
                        Icon(
                            ajudaAberta
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 12,
                            color: const Color(0xFF666666)),
                      ],
                    ),
                  ),
                  if (ajudaAberta)
                    Padding(
                      padding: const EdgeInsets.only(left: 40, top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('WhatsApp: (11) 99149-2204',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333))),
                          SizedBox(height: 4),
                          Text(
                              'Segunda a Sexta, das 09h às 21h Sábado, das 09h as 19h.',
                              style: TextStyle(
                                  fontSize: 14, color: Color(0xFF666666))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Color(0xFFB32645), width: 1.5),
                              foregroundColor: const Color(0xFFB32645),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(fecharTexto,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      if (reserva) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: confirmarHabilitado
                                    ? const Color(_verde)
                                    : const Color(0xFFE0E0E0),
                                foregroundColor: confirmarHabilitado
                                    ? Colors.white
                                    : const Color(0xFF999999),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                              onPressed: confirmarHabilitado
                                  ? () => Navigator.of(ctx).pop(true)
                                  : null,
                              child: const Text('CONFIRMAR RETIRADA',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _statusRetirada(
      {required bool feito,
      required String titulo,
      required String detalhe}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: feito
                ? const Icon(Icons.check_circle,
                    color: Color(_verde), size: 26)
                : const CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333))),
                const SizedBox(height: 2),
                Text(detalhe,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF999999))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Confirmação "Tudo certo" (sem alterações)
  static Future<bool?> tudoCerto(BuildContext context, int quantidade) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(28),
        title: Text('Confirma a separação de $quantidade itens?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(_vermelho)),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar',
                  style:
                      TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(_verde)),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmar',
                  style:
                      TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // 1º Diálogo: edição de quantidades na separação.
  // Retorna (mapa codigoSAP->quantidade dos itens selecionados, flag "nenhum item").
  // null = cancelado.
  static Future<(Map<String, int>, bool)?> quantidadeNovo(
      BuildContext context, Pedido pedido) {
    final selecionados = <int, bool>{};
    final qtd = <int, int>{};
    final controllers = <int, TextEditingController>{};
    for (var i = 0; i < pedido.itens.length; i++) {
      selecionados[i] = false;
      qtd[i] = pedido.itens[i].quantidade;
      controllers[i] =
          TextEditingController(text: '${pedido.itens[i].quantidade}');
    }
    bool nenhum = false;

    Color fundoItem(int i, Item it) {
      final sel = nenhum ? false : (selecionados[i] ?? false);
      final alterado = (qtd[i] ?? it.quantidade) != it.quantidade;
      if (!sel) return const Color(0xFFF1F3F4); // GRAY_100
      if (alterado) return const Color(0xFFFFE5E5); // RED_LIGHT
      return const Color(0xFFE6F4EA); // GREEN_600 claro
    }

    return showDialog<(Map<String, int>, bool)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          bool temAlteracao = pedido.itens.any((it) {
            final i = pedido.itens.indexOf(it);
            return (qtd[i] ?? it.quantidade) != it.quantidade;
          });
          bool algumSelecionado = selecionados.values.any((v) => v);
          bool habilitado = algumSelecionado || nenhum;
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                        'Confirme os itens do pedido #${pedido.codigoExterno}.',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          ...pedido.itens.asMap().entries.map((e) {
                            final i = e.key;
                            final it = e.value;
                            final sel = nenhum ? false : (selecionados[i] ?? false);
                            return InkWell(
                              onTap: () {
                                if (nenhum) return;
                                set(() => selecionados[i] = !(selecionados[i] ?? false));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                    color: fundoItem(i, it),
                                    border: const Border(
                                        bottom: BorderSide(
                                            color: Color(0xFFCCCCCC)))),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: sel,
                                      activeColor: const Color(0xFFE61937),
                                      onChanged: nenhum
                                          ? null
                                          : (v) => set(
                                              () => selecionados[i] = v ?? false),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              '${it.quantidade}x ${it.descricao ?? ""}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14)),
                                          Text(
                                              'EAN: ${it.codigoEAN ?? "---"} / SAP: ${it.codigoSAP ?? "---"}',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF555555))),
                                          if (it.estoque != null)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  top: 4),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                  color: const Color(0xFF4CAF50),
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              child: Text(
                                                  'Estoque estimado: ${it.estoque}',
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold)),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 55,
                                      child: TextField(
                                        enabled: !nenhum,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 4),
                                        ),
                                        controller: controllers[i],
                                        onChanged: (v) {
                                          final nova = int.tryParse(v) ?? 0;
                                          // Não permite adicionar acima da
                                          // quantidade pedida pelo cliente.
                                          if (nova > it.quantidade) {
                                            controllers[i]!.text =
                                                '${it.quantidade}';
                                            controllers[i]!.selection =
                                                TextSelection.fromPosition(
                                                    TextPosition(
                                                        offset:
                                                            controllers[i]!
                                                                .text
                                                                .length));
                                            set(() => qtd[i] = it.quantidade);
                                          } else {
                                            set(() => qtd[i] = nova);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          InkWell(
                            onTap: () =>
                                set(() => nenhum = !nenhum),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: nenhum,
                                  activeColor: const Color(0xFFE61937),
                                  onChanged: (v) => set(() => nenhum = v ?? false),
                                ),
                                const Text('A loja não possui nenhum item.',
                                    style: TextStyle(
                                        color: Color(0xFFE61937),
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('FECHAR',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333))),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: temAlteracao
                                  ? const Color(_vermelho)
                                  : const Color(_verde)),
                          onPressed: habilitado
                              ? () {
                                  if (nenhum) {
                                    Navigator.of(ctx)
                                        .pop((<String, int>{}, true));
                                    return;
                                  }
                                  final result = <String, int>{};
                                  for (var i = 0;
                                      i < pedido.itens.length;
                                      i++) {
                                    if (selecionados[i] == true) {
                                      final sap =
                                          pedido.itens[i].codigoSAP ??
                                              'idx_$i';
                                      result[sap] = qtd[i] ?? 0;
                                    }
                                  }
                                  Navigator.of(ctx).pop((result, false));
                                }
                              : null,
                          child: const Text('CONFIRMAR',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===== Passo 1: "Itens do Pedido" — escolha do motivo (retorna o code) =====
  static Future<String?> recusaMotivo(
    BuildContext context, {
    required String titulo,
    required List<MotivoRecusa> motivos,
  }) {
    String? selecionado;
    final expandidos = <String>{};
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Widget radio(bool sel) => Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sel ? const Color(_vermelho) : Colors.transparent,
                  border: Border.all(
                    color: sel
                        ? const Color(_vermelho)
                        : const Color(0xFFBDBDBD),
                    width: 2,
                  ),
                ),
                child: sel
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              );

          Widget linha({required Widget leading, required String texto}) =>
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Color(0xFFEEEEEE))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 24, child: leading),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(texto,
                          style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF757575),
                              height: 1.4)),
                    ),
                  ],
                ),
              );

          Widget motivoWidget(MotivoRecusa m) {
            if (m.subItems.isEmpty) {
              final sel = selecionado == m.code;
              return InkWell(
                onTap: () => set(() => selecionado = m.code),
                child: linha(leading: radio(sel), texto: m.description),
              );
            }
            final aberto = expandidos.contains(m.code);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => set(() {
                    if (aberto) {
                      expandidos.remove(m.code);
                    } else {
                      expandidos.add(m.code);
                    }
                  }),
                  child: linha(
                    leading: Text(aberto ? '-' : '+',
                        style: const TextStyle(
                            color: Color(_vermelho),
                            fontSize: 22,
                            height: 1,
                            fontWeight: FontWeight.w500)),
                    texto: m.description,
                  ),
                ),
                if (aberto)
                  ...m.subItems.map((s) {
                    final sel = selecionado == s.code;
                    return InkWell(
                      onTap: () => set(() => selecionado = s.code),
                      child: Container(
                        padding: const EdgeInsets.only(
                            left: 40, top: 12, bottom: 12),
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: Color(0xFFEEEEEE))),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            radio(sel),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(s.description,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF757575),
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          }

          return _dialogFull(
            header: _stepperHeader(
                passo: 1, onBack: () => Navigator.of(ctx).pop()),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF212121),
                          height: 1.4,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...motivos.map(motivoWidget),
                ],
              ),
            ),
            footer: _stepFooter(
              onFechar: () => Navigator.of(ctx).pop(),
              onSim: selecionado == null
                  ? null
                  : () => Navigator.of(ctx).pop(selecionado),
            ),
          );
        },
      ),
    );
  }

  // ===== Passo 2: "Confirmação" — reconfirma as quantidades alteradas =====
  static Future<bool?> confirmarQuantidades(
    BuildContext context, {
    required List<(String, int, int)> alterados,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _dialogFull(
        header: _stepperHeader(passo: 2),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Deseja confirmar a solicitação com as quantidades abaixo?',
                  style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF212121),
                      height: 1.4,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ...alterados.map((a) {
                final diff = a.$3 - a.$2;
                final recusa = diff < 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.$1,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('${a.$2}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[500],
                                        decoration:
                                            TextDecoration.lineThrough)),
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(Icons.arrow_forward,
                                      size: 14, color: Colors.grey),
                                ),
                                Text('${a.$3}',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFE61937))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: recusa
                              ? const Color(0xFFFFEBEE)
                              : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(diff > 0 ? '+$diff' : '$diff',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: recusa
                                    ? const Color(0xFFE60014)
                                    : const Color(0xFF2E7D32))),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        footer: _stepFooter(
          onFechar: () => Navigator.of(ctx).pop(false),
          onSim: () => Navigator.of(ctx).pop(true),
        ),
      ),
    );
  }

  static Widget _dialogFull({
    required Widget header,
    required Widget body,
    required Widget footer,
  }) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Column(
            children: [
              header,
              Expanded(child: body),
              footer,
            ],
          ),
        ),
      ),
    );
  }

  static Widget _stepperHeader({required int passo, VoidCallback? onBack}) {
    const vermelho = Color(0xFFD32F2F);
    Widget item({required bool check, required String label, String? numero}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
                color: vermelho, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: check
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(numero ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121))),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: onBack == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Color(0xFF212121)),
                    onPressed: onBack,
                  ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                item(check: true, label: 'Itens do Pedido'),
                Expanded(
                  child: Container(
                    height: 2,
                    margin:
                        const EdgeInsets.only(top: 11, left: 8, right: 8),
                    color: const Color(0xFFE0E0E0),
                  ),
                ),
                item(check: passo >= 2, label: 'Confirmação', numero: '2'),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  static Widget _stepFooter({
    required VoidCallback onFechar,
    required VoidCallback? onSim,
  }) {
    final habilitado = onSim != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: onFechar,
            child: const Text('FECHAR',
                style: TextStyle(
                    color: Color(0xFF212121), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: onSim,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  habilitado ? const Color(_verde) : const Color(0xFFE0E0E0),
              foregroundColor:
                  habilitado ? Colors.white : const Color(0xFF9E9E9E),
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Row(
              children: [
                const Text('SIM',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Icon(Icons.check,
                    size: 16,
                    color: habilitado ? Colors.white : const Color(0xFF9E9E9E)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Entregador voltou (insucesso) — retorna (motivo, observacao, tokenRecaptcha)
  static Future<(String, String, String)?> entregadorVoltou(
      BuildContext context, List<String> motivos) {
    String? motivo;
    String? token;
    final obs = TextEditingController();
    bool recaptcha = false;
    return showDialog<(String, String, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(20),
          title: const Text('Selecione o motivo de Retorno:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Selecione um motivo...'),
                    value: motivo,
                    underline: const SizedBox(),
                    items: motivos
                        .map((m) => DropdownMenuItem(
                            value: m, child: Text(m, style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (v) => set(() => motivo = v),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: obs,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Digite aqui a observação',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  secondary: Image.asset('assets/icons/ic_recaptcha_logo.png',
                      height: 28),
                  title: const Text('Não sou um robô',
                      style: TextStyle(fontSize: 14)),
                  value: recaptcha,
                  onChanged: (v) async {
                    if (v == true) {
                      final t = await RecaptchaDialog.show(ctx);
                      set(() => recaptcha = t != null);
                      if (t != null) token = t;
                    } else {
                      set(() => recaptcha = false);
                      token = null;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CANCELAR',
                  style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: recaptcha
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD1D5DB)),
              onPressed: (motivo != null && recaptcha)
                  ? () => Navigator.of(ctx)
                      .pop((motivo!, obs.text, token!))
                  : null,
              child: const Text('CONFIRMAR',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Retornar ao estoque (com motivo) — retorna (motivo, tokenRecaptcha)
  static Future<(String, String)?> retornarEstoque(BuildContext context) {
    final m = TextEditingController();
    String? token;
    bool recaptcha = false;
    return showDialog<(String, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(24),
          title: const Text('📦 Devolver ao Estoque',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          content: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Informe o motivo da devolução ao estoque:',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextField(
                  controller: m,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Digite o motivo da devolução...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  secondary: Image.asset('assets/icons/ic_recaptcha_logo.png',
                      height: 28),
                  title: const Text('Não sou um robô',
                      style: TextStyle(fontSize: 14)),
                  value: recaptcha,
                  onChanged: (v) async {
                    if (v == true) {
                      final t = await RecaptchaDialog.show(ctx);
                      set(() => recaptcha = t != null);
                      if (t != null) token = t;
                    } else {
                      set(() => recaptcha = false);
                      token = null;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(_vermelho),
                    disabledBackgroundColor: const Color(0xFFE0E0E0)),
                onPressed: (m.text.isNotEmpty && recaptcha)
                    ? () => Navigator.of(ctx).pop((m.text, token!))
                    : null,
                child: const Text('Devolver',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CA3AF),
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Devolver no histórico (cancelar finalizado) — retorna (motivo, tokenRecaptcha)
  static Future<(String, String)?> devolverHistorico(BuildContext context) {
    final m = TextEditingController();
    String? token;
    bool recaptcha = false;
    return showDialog<(String, String)>(
      context: context,
        builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(20),
          title: const Row(
            children: [
              Text('⚠️ ', style: TextStyle(fontSize: 18)),
              Text('ATENÇÃO',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cliente está com o produto na loja para devolução?',
                    style: TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                TextField(
                  controller: m,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Motivo do cancelamento',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  secondary: Image.asset('assets/icons/ic_recaptcha_logo.png',
                      height: 28),
                  title: const Text('Não sou um robô',
                      style: TextStyle(fontSize: 14)),
                  value: recaptcha,
                  onChanged: (v) async {
                    if (v == true) {
                      final t = await RecaptchaDialog.show(ctx);
                      set(() => recaptcha = t != null);
                      if (t != null) token = t;
                    } else {
                      set(() => recaptcha = false);
                      token = null;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(_vermelho),
                    disabledBackgroundColor: const Color(0xFFE0E0E0)),
                onPressed: (m.text.isNotEmpty && recaptcha)
                    ? () => Navigator.of(ctx).pop((m.text, token!))
                    : null,
                child: const Text('CANCELAR PEDIDO',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CA3AF),
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('NÃO',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Atenção genérica (devolver ao estoque sem token)
  static Future<bool?> atencao(BuildContext context,
      {required String titulo, required String mensagem, String sim = 'SIM'}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(28),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️ ', style: TextStyle(fontSize: 28)),
            Text(titulo,
                style:
                    TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(_vermelhoDark))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mensagem,
                style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(_vermelho)),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('NÃO',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(_verde)),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(sim,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Analisar coleta do pedido (iFood parado > 1 dia): confirma ou marca como
  // não coletado. CONFIRMAR só habilita com uma opção selecionada.
  // Retorna 'confirmar', 'nao_coletado' ou null (fechar).
  static Future<String?> analisarColeta(BuildContext context) {
    String? sel;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Widget opcao(String valor, String titulo, String descricao) {
            final ativo = sel == valor;
            return InkWell(
              onTap: () => set(() => sel = valor),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ativo ? const Color(0xFFF8F9FA) : Colors.white,
                  border: Border.all(
                      color: ativo
                          ? const Color(0xFFC7CBD1)
                          : const Color(0xFFE6E6E6)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ativo
                              ? const Color(_ifoodRed)
                              : const Color(0xFF9AA0A6),
                          width: 2,
                        ),
                      ),
                      child: ativo
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(_ifoodRed),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E1E1E))),
                          const SizedBox(height: 6),
                          Text(descricao,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.35,
                                  color: Color(0xFF5E6164))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Analisar coleta do pedido',
                        style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E))),
                    const SizedBox(height: 18),
                    opcao(
                        'confirmar',
                        'Confirmar coleta',
                        'Marque essa opção se o entregador já retirou este pedido na loja.'),
                    opcao(
                        'nao_coletado',
                        'Pedido não coletado',
                        'Marque essa opção se o pedido não foi coletado e está na loja. Entre em contato com o SAL para analisarem o pedido.'),
                    const Divider(height: 8, color: Color(0xFFE6E6E6)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        border: Border.all(color: const Color(0xFFE6E6E6)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.chat,
                              color: Color(0xFF25D366), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                    'SAL - Serviço de Atendimento à Loja',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E1E1E))),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Text('WhatsApp: ',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF5E6164))),
                                    InkWell(
                                      onTap: _abrirWhatsapp,
                                      child: const Text('(11) 99149-2204',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF1E1E1E),
                                              decoration:
                                                  TextDecoration.underline)),
                                    ),
                                  ],
                                ),
                                const Text(
                                    'Segunda a Sexta, das 09h às 21h.',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF5E6164))),
                                const Text('Sábado, das 09h às 19h.',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF5E6164))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 8, color: Color(0xFFE6E6E6)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(_ifoodRed),
                            side: const BorderSide(color: Color(0xFFFFCDD2)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('FECHAR',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                        ),
                        ElevatedButton(
                          onPressed: sel == null
                              ? null
                              : () => Navigator.of(ctx).pop(sel),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(_ifoodRed),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE0E0E0),
                            disabledForegroundColor: const Color(0xFF9E9E9E),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('CONFIRMAR',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static Future<void> _abrirWhatsapp() async {
    try {
      await launchUrl(Uri.parse('https://wa.me/5511991492204'),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
