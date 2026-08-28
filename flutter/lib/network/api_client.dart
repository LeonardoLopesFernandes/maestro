import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'session_manager.dart';
import '../utils/constants.dart';
import 'mock_data.dart';

class ApiClient {
  final String baseUrl;
  final SessionManager session;
  final http.Client _http;

  ApiClient({required this.session, http.Client? client})
      : baseUrl = Constants.baseUrl,
        _http = client ?? http.Client();

  Map<String, String> _headers() {
    final token = session.getToken();
    final store = session.getUserStore() ?? Constants.defaultStore;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'loja': store,
      'maestro_version': Constants.maestroVersion,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path,
      {Map<String, String>? query, bool isPublic = false}) async {
    if (session.isDemo()) return _demoGet(path, query);
    final uri = Uri.parse(baseUrl + path)
        .replace(queryParameters: query);
    final response = await _http.get(uri, headers: _headers());
    return _handle(response);
  }

  Future<dynamic> getBytes(String path, {Map<String, String>? query}) async {
    if (session.isDemo()) return <int>[];
    final uri = Uri.parse(baseUrl + path).replace(queryParameters: query);
    final response = await _http.get(uri, headers: _headers());
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw ApiException(response.statusCode, response.body);
  }

  Future<dynamic> post(String path, {dynamic body}) async {
    if (session.isDemo()) return _demoWrite(path, body);
    final uri = Uri.parse(baseUrl + path);
    final response = await _http.post(uri,
        headers: _headers(), body: body == null ? null : jsonEncode(body));
    return _handle(response);
  }

  Future<dynamic> put(String path,
      {dynamic body, Map<String, String>? query}) async {
    if (session.isDemo()) return _demoWrite(path, body);
    final uri = Uri.parse(baseUrl + path).replace(queryParameters: query);
    final response = await _http.put(uri,
        headers: _headers(), body: body == null ? null : jsonEncode(body));
    return _handle(response);
  }

  Future<dynamic> delete(String path, {dynamic body}) async {
    if (session.isDemo()) return _demoWrite(path, body);
    final uri = Uri.parse(baseUrl + path);
    final response = await _http.delete(uri,
        headers: _headers(), body: body == null ? null : jsonEncode(body));
    return _handle(response);
  }

  // ---------- Modo Demonstração ----------
  dynamic _demoGet(String path, Map<String, String>? query) {
    if (path.contains('/pedido/count')) return MockData.count();
    if (path.contains('/pedido/skip/')) {
      return {
        'data': MockData.pedidos(),
      };
    }
    if (path.contains('/pedido/') && path.contains('/status') == false) {
      final id = path.split('/pedido/').last;
      return MockData.pedidoById(id);
    }
    if (path.contains('/price-tag/store/') && path.contains('/filter') == false) {
      if (path.contains('/printing/report')) return MockData.priceTagSummary();
      if (path.contains('/printing')) return MockData.priceTags();
      return MockData.priceTagSummary();
    }
    if (path.contains('/delivery-tokens/')) {
      return {
        'tokenRetirada': 'tok_demo_ret',
        'tokenInsucesso': 'tok_demo_ins',
        'tokenCliente': 'tok_demo_cli',
      };
    }
    if (path.contains('/motivo/')) return ['Motivo de exemplo (demo)'];
    return {};
  }

  dynamic _demoWrite(String path, dynamic body) {
    // Ações de status: no demo apenas simulam sucesso sem rede.
    return {'demo': true, 'ok': true};
  }

  dynamic _handle(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body.isEmpty) return {};
      try {
        return jsonDecode(body);
      } catch (_) {
        return body;
      }
    }
    throw ApiException(response.statusCode, body);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
