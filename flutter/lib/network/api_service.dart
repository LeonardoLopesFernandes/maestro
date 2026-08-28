import 'dart:typed_data';
import '../models/pedido.dart';
import 'api_client.dart';

class ApiService {
  final ApiClient client;

  ApiService(this.client);

  Future<CountResponse> getCounts(String store) async {
    final json = await client.get('v2/backend/pedido/count')
        as Map<String, dynamic>;
    return CountResponse.fromJson(json);
  }

  Future<PedidoResponse> getPedidos({
    required String store,
    required String status,
    int skip = 0,
    int limit = 20,
    int minDias = 7,
    bool ordemDataInclusao = true,
    String? find,
    int? aba,
  }) async {
    final query = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
      'minDias': minDias.toString(),
      'ordemDataInclusao': ordemDataInclusao.toString(),
    };
    if (status.isNotEmpty) query['status'] = status;
    if (find != null && find.isNotEmpty) query['find'] = find;
    if (aba != null) query['aba'] = aba.toString();
    final json = await client.get('v2/backend/pedido/skip/$skip/limit/$limit',
        query: query) as Map<String, dynamic>;
    return PedidoResponse.fromJson(json);
  }

  Future<Pedido> getPedidoById(String store, String id) async {
    final json = await client.get('v2/backend/pedido/$id')
        as Map<String, dynamic>;
    return Pedido.fromJson(json);
  }

  Future<Map<String, dynamic>> updateStatus(
    String store,
    String id,
    String status, {
    Map<String, dynamic>? extra,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (extra != null) body.addAll(extra);
    final json = await client.post('v2/backend/pedido/$id/status',
        body: body) as Map<String, dynamic>;
    return json;
  }

  Future<Map<String, dynamic>> cancelarPedido(
    String store,
    String id,
    String motivo,
    String ocorrencia,
  ) async {
    final json = await client.post('v2/backend/pedido/$id/cancelar', body: {
      'motivo': motivo,
      'ocorrencia': ocorrencia,
    }) as Map<String, dynamic>;
    return json;
  }

  Future<Uint8List> getDanfe(String chave) async {
    final bytes = await client.getBytes('v2/backend/danfe/$chave');
    return Uint8List.fromList(bytes);
  }
}
