class ProductResponse {
  final String ean;
  final String sapId;
  final String? imageUrl;
  final String description;
  final PriceResponse? price;

  ProductResponse({
    this.ean = '',
    this.sapId = '',
    this.imageUrl,
    this.description = '',
    this.price,
  });

  factory ProductResponse.fromJson(Map<String, dynamic> json) {
    return ProductResponse(
      ean: json['ean']?.toString() ?? '',
      sapId: json['sapId']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      description: json['description']?.toString() ?? '',
      price: json['price'] != null ? PriceResponse.fromJson(json['price']) : null,
    );
  }
}

class PriceResponse {
  final String? regular;
  final String? promotional;

  PriceResponse({this.regular, this.promotional});

  factory PriceResponse.fromJson(Map<String, dynamic> json) {
    return PriceResponse(
      regular: json['regular']?.toString(),
      promotional: json['promotional']?.toString(),
    );
  }
}

class BluesoftProduct {
  final String name;
  final String description;
  final String brand;
  final String? imageUrl;
  final double price;
  final String ncm;
  final String cest;
  final String gpc;

  BluesoftProduct({
    required this.name,
    required this.description,
    required this.brand,
    this.imageUrl,
    required this.price,
    required this.ncm,
    required this.cest,
    required this.gpc,
  });
}

class ProductSearchResult {
  final String title;
  final String price;
  final String source;
  final String imageUrl;
  final String link;
  final String ean;
  final String brand;
  final String ncm;
  final String cest;
  final String gpc;

  ProductSearchResult({
    required this.title,
    required this.price,
    required this.source,
    required this.imageUrl,
    required this.link,
    this.ean = '',
    this.brand = '',
    this.ncm = '',
    this.cest = '',
    this.gpc = '',
  });
}
