import 'dart:typed_data';
import '../models/pedido.dart';
import 'api_client.dart';

class ApiService {
  final ApiClient client;

  ApiService(this.client);

  // ---------- Pedidos ----------
  Future<CountResponse> getCounts(String store) async {
    final json = await client.get('v2/backend/pedido/count')
        as Map<String, dynamic>;
    return CountResponse.fromJson(json);
  }

  Future<Pedido> getPedidoById(String id) async {
    final json = await client.get('v2/backend/pedido/$id')
        as Map<String, dynamic>;
    return Pedido.fromJson(json);
  }

  Future<PedidoResponse> getPedidosPaged({
    required int skip,
    required int limit,
    String status = '',
    int minDias = 7,
    bool ordemDataInclusao = true,
    String? find,
    String? aba,
  }) async {
    final query = <String, String>{
      if (status.isNotEmpty) 'status': status,
      'minDias': minDias.toString(),
      'ordemDataInclusao': ordemDataInclusao.toString(),
    };
    if (find != null && find.isNotEmpty) query['find'] = find;
    if (aba != null && aba.isNotEmpty) query['aba'] = aba;
    final json = await client.get(
        'v2/backend/pedido/skip/$skip/limit/$limit',
        query: query) as Map<String, dynamic>;
    return PedidoResponse.fromJson(json);
  }

  // ---------- Ações por status ----------
  Future<Map<String, dynamic>> _putStatus(String path, Map<String, dynamic> body,
      {Map<String, String>? query}) async {
    final json = await client.put('v2/backend/$path',
        body: body, query: query) as Map<String, dynamic>;
    return json;
  }

  Future<void> separarPedido(String origem, String codigoExterno) =>
      _putStatus('api/pedidos/$origem/$codigoExterno/emSeparacao', {});

  Future<void> confirmarPedido(
    String origem,
    String codigoExterno, {
    required Map<String, dynamic> body,
    bool editado = false,
    String? recusado,
    String? motivo,
    String? itens,
  }) {
    final query = <String, String>{
      'editado': editado.toString(),
      'retry': 'false',
      if (recusado != null) 'recusado': recusado,
      if (motivo != null) 'motivo': motivo,
      if (itens != null) 'itens': itens,
    };
    return _putStatus('api/pedidos/$origem/$codigoExterno/prontoParaSair',
        body,
        query: query);
  }

  Future<void> updateInventory(String numero, List<Map<String, dynamic>> itens,
      double valorTotal,
      {bool corpoVazio = false}) {
    final body = corpoVazio
        ? <String, dynamic>{'itens': [], 'valorTotal': 0.0}
        : <String, dynamic>{
            'itens': itens,
            'valorTotal': valorTotal,
          };
    return _putStatus('pedido/$numero/update-inventory', body);
  }

  Future<void> recusarPedido(String origem, String codigoExterno,
          String motivo) =>
      cancelarPedido(origem, codigoExterno, motivo, 'recusa',
          recusado: true);

  Future<void> retirarPedidoShipFromStore(String codigoExterno) =>
      _putStatus('api/pedidos/SHIP_FROM_STORE/$codigoExterno/saiuParaEntrega', {});

  Future<void> retirarPedidoPackk(String codigoExterno) =>
      _putStatus('api/pedidos/PEGUE_NA_LOJA_HOJE/$codigoExterno/finalizado', {});

  Future<void> cancelarPedido(String origem, String codigoExterno, String motivo,
      String ocorrencia,
      {bool recusado = false}) =>
      _putStatus('api/pedidos/$origem/$codigoExterno/cancelado', {
        'motivo': motivo,
        'ocorrencia': ocorrencia,
        if (recusado) 'recusado': true,
      });

  Future<void> cancelarPedidoProntoRetirada(
          String origem, String codigoExterno) =>
      _putStatus('api/pedidos/$origem/$codigoExterno/cancelado', {});

  Future<void> retornarParaEstoque(String origem, String codigoExterno,
          {String? captchaToken, String? motivo}) =>
      _putStatus('api/pedidos/$origem/$codigoExterno/retornarParaEstoque', {
        if (captchaToken != null) 'captchaToken': captchaToken,
        if (motivo != null) 'motivo': motivo,
      });

  Future<void> devolverPedido(String origem, String codigoExterno,
          {String? recaptchaToken, String? observacao}) =>
      _putStatus('api/pedidos/$origem/$codigoExterno/devolvido', {
        if (recaptchaToken != null) 'recaptchaToken': recaptchaToken,
        if (observacao != null) 'observacao': observacao,
      });

  Future<Map<String, dynamic>> confirmarDevolucao(
          Map<String, dynamic> body) async =>
      (await client.post('v2/backend/api/pedidos/loja/devolucao', body: body))
          as Map<String, dynamic>;

  // ---------- Status genérico (fallback) ----------
  Future<Map<String, dynamic>> updateStatus(String numero, String status,
      {Map<String, dynamic>? extra}) async {
    final body = <String, dynamic>{'status': status};
    if (extra != null) body.addAll(extra);
    final json = await client.put('v2/backend/pedido/$numero/status',
        body: body) as Map<String, dynamic>;
    return json;
  }

  // ---------- Tokens / código ----------
  Future<Map<String, dynamic>> getDeliveryTokens(String numero) async =>
      (await client.get('v2/backend/api/pedidos/delivery-tokens/$numero'))
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> verificarCodigoRetirada(String codigo) async =>
      (await client.get('v2/backend/pedido/codigo/$codigo'))
          as Map<String, dynamic>;

  Future<bool> validarCodigoRetirada(String codigo, String numero) async {
    try {
      final json = await client.get('v2/backend/pedido/codigo/$codigo',
          query: {'numero': numero}) as Map<String, dynamic>;
      final data = json['data'];
      if (data is Map) return data['codigoStatus'] == true;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getMotivosInsucesso() async {
    final json = await client.get('v2/backend/pedido/motivo/insucesso')
        as Map<String, dynamic>;
    final data = json['data'];
    if (data is List) {
      return data
          .map<String>((e) => (e is Map
              ? (e['nome'] ?? e['motivo'] ?? '')
              : e.toString()))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  Future<List<MotivoRecusa>> getMotivosRecusa(
      {String? origem, String? status}) async {
    final json = await client.get('v2/backend/pedido/motivo/recusa', query: {
      if (origem != null && origem.isNotEmpty) 'origem': origem,
      if (status != null && status.isNotEmpty) 'status': status,
    }) as Map<String, dynamic>;
    final data = json['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => MotivoRecusa.fromJson(Map<String, dynamic>.from(e)))
          .where((m) => m.code.isNotEmpty)
          .toList();
    }
    return [];
  }

  // ---------- DANFE ----------
  Future<Uint8List> getDanfe(String chave) async {
    final bytes = await client.getBytes('v2/backend/danfe/$chave');
    return Uint8List.fromList(bytes);
  }

  // DANFE via URL direta (host externo inventti/lasa)
  Future<Uint8List> getDanfeUrl(String url) async {
    final bytes = await client.getBytesDirect(url, withAuth: false);
    return bytes;
  }

  // ---------- Price Tags (etiquetas de preço) ----------
  Future<Map<String, dynamic>> getPriceTagSummary(String loja) async =>
      (await client.get('web/price-tag/store/$loja'))
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> getPriceTagFilters(String loja) async =>
      (await client.get('web/price-tag/store/$loja/filter'))
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> getPriceTags(String loja,
      {Map<String, String>? query}) async {
    final json = await client.get('web/price-tag/store/$loja/printing',
        query: query) as Map<String, dynamic>;
    return json;
  }

  Future<Map<String, dynamic>> sendPriceTags(
      String loja, String printerId, String tagId) async {
    final json = await client.post(
        'web/price-tag/store/$loja/printer/$printerId/tag/$tagId/send',
        body: {});
    return json as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPriceTagReport(String loja) async =>
      (await client.get('web/price-tag/store/$loja/printing/report'))
          as Map<String, dynamic>;
}
