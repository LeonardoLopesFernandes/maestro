import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/constants.dart';

/// Busca secundária de imagens de produto na API REST do SI5 Global.
class Si5ImageSearch {
  Si5ImageSearch._();

  static const String _base = 'https://global.si5.com.br/api/produtos';

  static Future<String?> searchByEan(String ean) async {
    final codigo = ean.replaceAll(RegExp(r'\D'), '');
    if (codigo.isEmpty) return null;
    try {
      final response = await http
          .get(
            Uri.parse('$_base/$codigo'),
            headers: {
              'Authorization': 'Bearer ${ApiKeys.si5Token}',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      if (json is! Map) return null;
      final url = (json['imagem_url'] ?? '').toString().trim();
      if (url.startsWith('http')) return url;
      return null;
    } catch (_) {
      return null;
    }
  }
}
