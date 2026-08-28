import 'package:flutter/material.dart';
import '../models/pedido.dart';

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
                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // Dialog de token (retirada na loja)
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
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: '----',
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
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // Diálogo de quantidade (itens sem smartphone)
  static Future<bool?> quantidadeNovo(
      BuildContext context, Pedido pedido) {
    final selecionados = <int, bool>{};
    final qtd = <int, int>{};
    for (var i = 0; i < pedido.itens.length; i++) {
      selecionados[i] = true;
      qtd[i] = pedido.itens[i].quantidade;
    }
    bool nenhum = false;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
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
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ...pedido.itens.asMap().entries.map((e) {
                          final i = e.key;
                          final it = e.value;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: Color(0xFFCCCCCC)))),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: nenhum ? false : selecionados[i]!,
                                  activeColor: const Color(0xFFE61937),
                                  onChanged: (v) =>
                                      set(() => selecionados[i] = v ?? false),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${it.quantidade}x ${it.descricao}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                      Text(
                                          'EAN: ${it.codigoEAN} / SAP: ${it.codigoSAP}',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF555555))),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 55,
                                  child: TextField(
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
                                    onChanged: (v) =>
                                        qtd[i] = int.tryParse(v) ?? 0,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        Row(
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
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('FECHAR',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333))),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(_verde)),
                        onPressed: () => Navigator.of(ctx).pop(true),
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
                  style: TextStyle(color: Color(0xFFDC2626))),
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

  // Entregador voltou (insucesso)
  static Future<(String motivo, String obs)?> entregadorVoltou(
      BuildContext context, List<String> motivos) {
    String? motivo;
    final obs = TextEditingController();
    bool recaptcha = false;
    return showDialog<(String, String)>(
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
                  title: const Text('Não sou um robô',
                      style: TextStyle(fontSize: 14)),
                  value: recaptcha,
                  onChanged: (v) => set(() => recaptcha = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CANCELAR',
                  style: TextStyle(color: Color(0xFFDC2626))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: recaptcha
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD1D5DB)),
              onPressed: (motivo != null && recaptcha)
                  ? () => Navigator.of(ctx)
                      .pop((motivo!, obs.text))
                  : null,
              child: const Text('CONFIRMAR',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Retornar ao estoque (com motivo)
  static Future<String?> retornarEstoque(BuildContext context) {
    final m = TextEditingController();
    bool recaptcha = false;
    return showDialog<String>(
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
                  title: const Text('Não sou um robô',
                      style: TextStyle(fontSize: 14)),
                  value: recaptcha,
                  onChanged: (v) => set(() => recaptcha = v ?? false),
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
                    ? () => Navigator.of(ctx).pop(m.text)
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
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(_vermelho)),
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

  // Devolver no histórico (cancelar finalizado)
  static Future<String?> devolverHistorico(BuildContext context) {
    final m = TextEditingController();
    bool recaptcha = false;
    return showDialog<String>(
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
                  title: const Text('Não sou um robô',
                      style: TextStyle(fontSize: 14)),
                  value: recaptcha,
                  onChanged: (v) => set(() => recaptcha = v ?? false),
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
                    ? () => Navigator.of(ctx).pop(m.text)
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
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(_vermelho)),
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
