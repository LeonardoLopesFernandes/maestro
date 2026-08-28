import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'session_manager.dart';
import '../utils/constants.dart';

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
      if (token != null && token.isNotEmpty) 'Authorization': token,
    };
  }

  Future<dynamic> get(String path,
      {Map<String, String>? query, bool isPublic = false}) async {
    final uri = Uri.parse(baseUrl + path)
        .replace(queryParameters: query);
    final response = await _http.get(uri, headers: _headers());
    return _handle(response);
  }

  Future<dynamic> getBytes(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse(baseUrl + path).replace(queryParameters: query);
    final response = await _http.get(uri, headers: _headers());
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw ApiException(response.statusCode, response.body);
  }

  Future<dynamic> post(String path, {dynamic body}) async {
    final uri = Uri.parse(baseUrl + path);
    final response = await _http.post(uri,
        headers: _headers(), body: body == null ? null : jsonEncode(body));
    return _handle(response);
  }

  Future<dynamic> put(String path, {dynamic body}) async {
    final uri = Uri.parse(baseUrl + path);
    final response = await _http.put(uri,
        headers: _headers(), body: body == null ? null : jsonEncode(body));
    return _handle(response);
  }

  Future<dynamic> delete(String path, {dynamic body}) async {
    final uri = Uri.parse(baseUrl + path);
    final response = await _http.delete(uri,
        headers: _headers(), body: body == null ? null : jsonEncode(body));
    return _handle(response);
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
