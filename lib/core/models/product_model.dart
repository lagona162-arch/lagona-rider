class ProductModel {
  final String id;
  final String merchantId;
  final String? category;
  final String name;
  final double price;
  final int stock;
  final DateTime createdAt;

  ProductModel({
    required this.id,
    required this.merchantId,
    this.category,
    required this.name,
    required this.price,
    required this.stock,
    required this.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      category: json['category'] as String?,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      stock: json['stock'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_id': merchantId,
      'category': category,
      'name': name,
      'price': price,
      'stock': stock,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

