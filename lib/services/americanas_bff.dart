import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

/// Equivalente a io.amer.scanner.ApiClient / ApiService (BFF da Americanas).
class AmericanasBff {
  static const String _baseUrl = 'https://sl-bff-report.americanas.io/';

  static Future<ProductResponse> getProduct(String barcode, {String store = 'L291'}) async {
    final uri = Uri.parse(
        '${_baseUrl}web/price-scanner/store/$store/ean/$barcode');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return ProductResponse.fromJson(json);
    }
    throw Exception('HTTP ${response.statusCode}');
  }
}
