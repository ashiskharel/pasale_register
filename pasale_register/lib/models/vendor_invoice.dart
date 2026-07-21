class VendorInvoice {
  final String id;
  final String storeId;
  final String vendorUid;
  final String vendorName;
  final double totalAmount;
  final DateTime issuedAt;
  final DateTime dueDate;
  final String status; // 'pending', 'paid', 'overdue', 'cancelled'
  final List<String> lineItems;
  final double amountPaid;

  VendorInvoice({
    required this.id,
    required this.storeId,
    required this.vendorUid,
    required this.vendorName,
    required this.totalAmount,
    required this.issuedAt,
    required this.dueDate,
    this.status = 'pending',
    this.lineItems = const [],
    this.amountPaid = 0.0,
  });

  VendorInvoice copyWith({
    String? id,
    String? storeId,
    String? vendorUid,
    String? vendorName,
    double? totalAmount,
    DateTime? issuedAt,
    DateTime? dueDate,
    String? status,
    List<String>? lineItems,
    double? amountPaid,
  }) {
    return VendorInvoice(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      vendorUid: vendorUid ?? this.vendorUid,
      vendorName: vendorName ?? this.vendorName,
      totalAmount: totalAmount ?? this.totalAmount,
      issuedAt: issuedAt ?? this.issuedAt,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      lineItems: lineItems ?? this.lineItems,
      amountPaid: amountPaid ?? this.amountPaid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'vendorUid': vendorUid,
      'vendorName': vendorName,
      'totalAmount': totalAmount,
      'issuedAt': issuedAt.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'status': status,
      'lineItems': lineItems,
      'amountPaid': amountPaid,
    };
  }

  factory VendorInvoice.fromMap(Map<String, dynamic> map, String id) {
    return VendorInvoice(
      id: id,
      storeId: map['storeId'] as String? ?? '',
      vendorUid: map['vendorUid'] as String? ?? '',
      vendorName: map['vendorName'] as String? ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      issuedAt: map['issuedAt'] != null
          ? DateTime.parse(map['issuedAt'].toString())
          : DateTime.now(),
      dueDate: map['dueDate'] != null
          ? DateTime.parse(map['dueDate'].toString())
          : DateTime.now(),
      status: map['status'] as String? ?? 'pending',
      lineItems: (map['lineItems'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
