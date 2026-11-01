import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../utils/constants.dart';

/// Equivalente a io.amer.scanner.ImageSearchAPI (busca por texto -> shopping).
class ImageSearchApi {
  static Future<List<ProductSearchResult>> searchByText(String text) async {
    try {
      final encoded = Uri.encodeQueryComponent(text);
      final uri = Uri.parse(
        'https://serpapi.com/search.json?engine=google&q=$encoded&tbm=shop&api_key=${ApiKeys.serpApiKey}&gl=br&hl=pt',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 20));
      final json = jsonDecode(response.body);
      final shopping = json['shopping_results'];
      if (shopping is List) {
        final results = <ProductSearchResult>[];
        final limit = min(10, shopping.length);
        for (var i = 0; i < limit; i++) {
          final item = shopping[i];
          final title = item['title']?.toString() ?? '';
          var priceRaw = item['price']?.toString() ?? '';
          final source = item['source']?.toString() ?? '';
          var imageUrl = (item['thumbnail']?.toString() ?? '')
              .replaceAll('http://', 'https://');
          final link = item['link']?.toString() ?? '';

          var price = priceRaw;
          if (priceRaw.isNotEmpty && !priceRaw.contains('R\$')) {
            final v = _extractPrice(priceRaw);
            if (v > 0) price = 'R\$ ${_format(v)}';
          }

          if (title.isNotEmpty) {
            results.add(ProductSearchResult(
              title: title.length > 80 ? title.substring(0, 80) : title,
              price: price,
              source: source,
              imageUrl: imageUrl,
              link: link,
              ean: '',
            ));
          }
        }
        return results;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static double _extractPrice(String s) {
    final dec = RegExp(r'(\d+[.,]\d{2})').firstMatch(s);
    if (dec != null) {
      return double.tryParse(dec.group(1)!.replaceAll(',', '.')) ?? 0.0;
    }
    final intMatch = RegExp(r'(\d+)').firstMatch(s);
    if (intMatch != null) {
      return double.tryParse(intMatch.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  static String _format(double n) {
    final s = n.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final buffer = StringBuffer();
    var count = 0;
    for (var i = intPart.length - 1; i >= 0; i--) {
      buffer.write(intPart[i]);
      count++;
      if (count % 3 == 0 && i != 0) buffer.write('.');
    }
    return buffer.toString().split('').reversed.join('');
  }
}
