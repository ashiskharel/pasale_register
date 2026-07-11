class Product {
  final String id; // barcode or auto-id
  final String name;
  final String barcode;
  final double sellingPrice;
  final double costPrice;
  final double markup;

  /// Store that owns this catalog entry (prices are per-store).
  final String? storeId;

  /// Local file path or remote URL of the product photo.
  final String? imagePath;

  Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.sellingPrice,
    required this.costPrice,
    required this.markup,
    this.storeId,
    this.imagePath,
  });

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? sellingPrice,
    double? costPrice,
    double? markup,
    String? storeId,
    String? imagePath,
    bool clearImage = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      costPrice: costPrice ?? this.costPrice,
      markup: markup ?? this.markup,
      storeId: storeId ?? this.storeId,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'sellingPrice': sellingPrice,
      'costPrice': costPrice,
      'markup': markup,
      if (storeId != null) 'storeId': storeId,
      if (imagePath != null) 'imagePath': imagePath,
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
      storeId: map['storeId'] as String?,
      imagePath: map['imagePath'] as String? ?? map['imageUrl'] as String?,
    );
  }
}
