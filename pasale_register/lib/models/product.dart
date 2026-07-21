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

  /// Free-text notes (e.g. OCR expiry / price-tag snippets) for training.
  final String? notes;

  /// Current physical stock quantity of the product in this store.
  final double quantity;

  /// Vendors who supply this product, if explicitly assigned.
  final List<String>? vendorIds;

  Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.sellingPrice,
    required this.costPrice,
    required this.markup,
    this.quantity = 0.0,
    this.storeId,
    this.imagePath,
    this.notes,
    this.vendorIds,
  });

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? sellingPrice,
    double? costPrice,
    double? markup,
    double? quantity,
    String? storeId,
    String? imagePath,
    String? notes,
    List<String>? vendorIds,
    bool clearImage = false,
    bool clearNotes = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      costPrice: costPrice ?? this.costPrice,
      markup: markup ?? this.markup,
      quantity: quantity ?? this.quantity,
      storeId: storeId ?? this.storeId,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      notes: clearNotes ? null : (notes ?? this.notes),
      vendorIds: vendorIds ?? this.vendorIds,
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
      'quantity': quantity,
      if (storeId != null) 'storeId': storeId,
      if (imagePath != null) 'imagePath': imagePath,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (vendorIds != null && vendorIds!.isNotEmpty) 'vendorIds': vendorIds,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name']?.toString() ?? '',
      barcode: map['barcode']?.toString() ?? '',
      sellingPrice: (map['sellingPrice'] as num? ?? 0.0).toDouble(),
      costPrice: (map['costPrice'] as num? ?? 0.0).toDouble(),
      markup: (map['markup'] as num? ?? 0.0).toDouble(),
      quantity: (map['quantity'] as num? ?? 0.0).toDouble(),
      storeId: map['storeId'] as String?,
      imagePath: map['imagePath'] as String? ?? map['imageUrl'] as String?,
      notes: map['notes'] as String?,
      vendorIds: (map['vendorIds'] as List?)?.map((e) => e as String).toList() ?? 
                 (map['vendorId'] != null ? [map['vendorId'] as String] : null),
    );
  }
}
