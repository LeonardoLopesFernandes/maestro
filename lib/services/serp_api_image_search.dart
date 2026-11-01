import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../utils/constants.dart';
import 'bluesoft_api.dart';

/// Equivalente a io.amer.scanner.SerpApiImageSearch (imagem do produto).
class SerpApiImageSearch {
  static Future<String?> searchImageByEan(String ean, String? productName) async {
    // 1. Bluesoft (imagem oficial)
    var bluesoft = await BluesoftApi.searchProductByEan(ean);
    if (bluesoft == null) {
      bluesoft = await BluesoftApi.searchProductByDescription(ean);
    }
    if (bluesoft != null && bluesoft.imageUrl != null && bluesoft.imageUrl!.isNotEmpty) {
      return bluesoft.imageUrl;
    }

    // 2. Fallback Google Images
    final query = (productName != null &&
            productName.isNotEmpty &&
            productName != 'Produto EAN: $ean')
        ? '${productName.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim().length > 40 ? productName.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim().substring(0, 40) : productName.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim()} $ean'
        : ean;

    return _searchGoogleImage(query);
  }

  static Future<String?> _searchGoogleImage(String query) async {
    try {
      final encoded = Uri.encodeQueryComponent('$query produto');
      final uri = Uri.parse(
        'https://serpapi.com/search?engine=google&q=$encoded&tbm=isch&api_key=${ApiKeys.serpApiKey}&ijn=0',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 5));
      final json = jsonDecode(response.body);
      final images = json['images_results'];
      if (images is List) {
        final limit = min(3, images.length);
        for (var i = 0; i < limit; i++) {
          final img = images[i];
          var url = img['original']?.toString() ?? '';
          if (url.isEmpty) url = img['thumbnail']?.toString() ?? '';
          if (url.isNotEmpty &&
              url.startsWith('http') &&
              !url.contains('placeholder') &&
              !url.contains('default') &&
              !url.contains('no-image')) {
            return url;
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
