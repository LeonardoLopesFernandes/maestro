import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../utils/constants.dart';

/// Equivalente a io.amer.scanner.BluesoftAPI (cosmos.bluesoft.com.br).
class BluesoftApi {
  static const String _baseUrl = 'https://api.cosmos.bluesoft.com.br';

  static Future<BluesoftProduct?> searchProductByEan(String ean) async {
    try {
      final uri = Uri.parse('$_baseUrl/gtins/$ean');
      final response = await http.get(
        uri,
        headers: {
          'X-API-KEY': ApiKeys.bluesoftApiKey,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (!response.statusCode.toString().startsWith('2')) return null;

      final json = jsonDecode(response.body);
      if (json is Map && json.containsKey('error')) return null;

      final description = json['description']?.toString() ?? '';
      final brand = json['brand']?.toString() ?? '';
      final gpc = json['gpc']?.toString() ?? '';

      String ncm = '';
      if (json['ncm'] is Map) ncm = json['ncm']['code']?.toString() ?? '';

      String? imageUrl;
      if (json['images'] is List && (json['images'] as List).isNotEmpty) {
        for (final img in json['images']) {
          final s = img?.toString() ?? '';
          if (s.isNotEmpty && s.startsWith('http')) {
            imageUrl = s.replaceAll('http://', 'https://');
            break;
          }
        }
      }

      double price = 0.0;
      if (json['average_price'] is Map) {
        price = (json['average_price']['price'] as num?)?.toDouble() ?? 0.0;
      }

      final fullName = brand.isNotEmpty && description.isNotEmpty
          ? '$brand $description'
          : description.isNotEmpty
              ? description
              : brand.isNotEmpty
                  ? brand
                  : null;

      if (fullName != null) {
        return BluesoftProduct(
          name: fullName.length > 100 ? fullName.substring(0, 100) : fullName,
          description: description,
          brand: brand,
          imageUrl: imageUrl,
          price: price,
          ncm: ncm,
          cest: json['cest']?.toString() ?? '',
          gpc: gpc,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<BluesoftProduct?> searchProductByDescription(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/products?query=${Uri.encodeQueryComponent(query)}');
      final response = await http.get(
        uri,
        headers: {
          'X-API-KEY': ApiKeys.bluesoftApiKey,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (!response.statusCode.toString().startsWith('2')) return null;

      final json = jsonDecode(response.body);
      final products = json['products'];
      if (products is List && products.isNotEmpty) {
        final p = products[0];
        final description = p['description']?.toString() ?? '';
        final brand = p['brand']?.toString() ?? '';

        String? imageUrl;
        if (p['images'] is List && (p['images'] as List).isNotEmpty) {
          for (final img in p['images']) {
            final s = img?.toString() ?? '';
            if (s.isNotEmpty && s.startsWith('http')) {
              imageUrl = s.replaceAll('http://', 'https://');
              break;
            }
          }
        }

        final fullName = brand.isNotEmpty && description.isNotEmpty
            ? '$brand $description'
            : description.isNotEmpty
                ? description
                : brand.isNotEmpty
                    ? brand
                    : (p['name']?.toString() ?? '');

        if (fullName.isNotEmpty) {
          return BluesoftProduct(
            name: fullName.length > 100 ? fullName.substring(0, 100) : fullName,
            description: description,
            brand: brand,
            imageUrl: imageUrl,
            price: 0.0,
            ncm: '',
            cest: '',
            gpc: '',
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
