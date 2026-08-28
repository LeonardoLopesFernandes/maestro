import 'package:flutter/material.dart';
import '../models/pedido.dart';
import 'recaptcha_dialog.dart';

// Cores conforme drawables do Kotlin
const _verde = 0xFF12CD0C;
const _verdeEscuro = 0xFF2E7D32;
const _vermelho = 0xFFF80032;
const _vermelhoDark = 0xFFD50000;
const _laranja = 0xFFFFAA02;

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
  static Future<String?> token(BuildContext context,
      {String nome = '', String numero = ''}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        title: Column(
          children: [
            if (nome.isNotEmpty)
              Text(nome,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(_vermelhoDark)),
                  textAlign: TextAlign.center),
            if (numero.isNotEmpty)
              Text('#$numero',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.infinity,
          child: TextField(
            controller: c,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            maxLength: 20,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4),
            decoration: InputDecoration(
              hintText: 'TOKEN',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(_verdeEscuro)),
              onPressed: () => Navigator.of(context).pop(c.text.trim()),
              child: const Text('CONFIRMAR',
                  style:
                      TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(_vermelhoDark)),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCELAR',
                  style:
                      TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // Dialog de exibição de token (fluxo EXTERNA: entregador coloca no app; nós confirmamos)
  static Future<bool?> tokenExibir(BuildContext context, String token,
      {String instrucao =
          'Informe o código para o entregador e aguarde a validação para liberar o pedido.'}) {
    bool liberado = false;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          // Libera o botão CONFIRMAR após 4s (animação de validação)
          Future.delayed(const Duration(seconds: 4), () {
            if (ctx.mounted && !liberado) set(() => liberado = true);
          });
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(24),
            title: const Text('Token de Retirada',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            content: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFFD1D5DB)),
                    ),
                    child: Text(token,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3),
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 14),
                  Text(instrucao,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  if (!liberado)
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.check_circle,
                        color: Color(_verde), size: 22),
                ],
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: liberado
                          ? const Color(_verde)
                          : const Color(0xFFD1D5DB)),
                  onPressed: liberado
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  child: const Text('CONFIRMAR',
                      style:
                          TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(_vermelhoDark)),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('CANCELAR',
                      style:
                          TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Dialog informativo de token de insucesso (somente exibição)
  static Future<void> tokenExibirInfo(BuildContext context, String token) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        title: const Text('Token de Insucesso',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFD1D5DB)),
                ),
                child: Text(token,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 14),
              const Text(
                  'Token de insucesso gerado!\n\n'
                  '📍 INFORME AO ENTREGADOR:\n'
                  '1. Copie este token\n'
                  '2. Entregue ao entregador\n'
                  '3. Ele deve inserir no app dele\n'
                  '4. Após inserir, o pedido será finalizado',
                  style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(_vermelhoDark)),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('FECHAR',
                  style:
                      TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // Confirmação "Tudo certo" (sem alterações)
  static Future<bool?> tudoCerto(BuildContext context, int itens) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(28),
        title: Text('Confirma a separação de $itens itens?',
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
    for (var i = 0; i < pedido.itens.length; i++) {
      selecionados[i] = false;
      qtd[i] = pedido.itens[i].quantidade;
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
                            final alterado =
                                (qtd[i] ?? it.quantidade) != it.quantidade;
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
                                            Text(
                                                'Estoque estimado: ${it.estoque}',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Color(0xFF1565C0))),
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
                                        controller: TextEditingController(
                                            text: '${qtd[i]}'),
                                        onChanged: (v) {
                                          final nova =
                                              int.tryParse(v) ?? 0;
                                          set(() {
                                            qtd[i] = nova > it.quantidade
                                                ? it.quantidade
                                                : nova;
                                          });
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

  // 2º Diálogo (quando houve alteração): confirmação parcial com motivo.
  // Mostra as quantidades alteradas e pede o motivo da recusa/alteração.
  static Future<String?> confirmacaoParcial(
    BuildContext context, {
    required int totalItens,
    required List<(String, int, int)> alterados,
    required List<String> motivos,
  }) {
    String? motivo;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(20),
          title: Text(
              'Confirmação Parcial de $totalItens itens. Selecione o motivo para o(s) produto(s) recusado(s):',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Column(
                      children: alterados
                          .map((a) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: Text(a.$1,
                                            style:
                                                const TextStyle(fontSize: 12))),
                                    Text(
                                        '${a.$2} → ${a.$3}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFE61937))),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                            value: m,
                            child: Text(m, style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (v) => set(() => motivo = v),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('FECHAR',
                  style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: motivo != null
                      ? const Color(_verde)
                      : const Color(0xFFD1D5DB)),
              onPressed: motivo != null
                  ? () => Navigator.of(ctx).pop(motivo)
                  : null,
              child: const Text('CONFIRMAR',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Escolha de motivo (rádio)
  static Future<String?> motivoRadio(BuildContext context,
      {String titulo = 'Selecione o motivo', List<String> opcoes = const []}) {
    String? sel;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(titulo,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: opcoes
                    .map((o) => RadioListTile<String>(
                          title: Text(o,
                              style: const TextStyle(
                                  fontSize: 14, color: Color(0xFF333333))),
                          value: o,
                          groupValue: sel,
                          activeColor: const Color(0xFFE60014),
                          onChanged: (v) => set(() => sel = v),
                        ))
                    .toList(),
              ),
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
                  backgroundColor: const Color(_verde)),
              onPressed: () => Navigator.of(ctx).pop(sel),
              child: const Text('CONFIRMAR',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
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
}
