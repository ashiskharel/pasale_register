class Product {
  final String id; // barcode or auto-id
  final String name;
  final String barcode;
  final double sellingPrice;
  final double costPrice;
  final double markup;

  Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.sellingPrice,
    required this.costPrice,
    required this.markup,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'sellingPrice': sellingPrice,
      'costPrice': costPrice,
      'markup': markup,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'] as String? ?? '',
      barcode: map['barcode'] as String? ?? '',
      sellingPrice: (map['sellingPrice'] as num? ?? 0.0).toDouble(),
      costPrice: (map['costPrice'] as num? ?? 0.0).toDouble(),
      markup: (map['markup'] as num? ?? 0.0).toDouble(),
    );
  }
}
