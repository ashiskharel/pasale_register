import 'dart:convert';

import 'store_invoice.dart' show InvoicePayment;

class StoreDeposit {
  const StoreDeposit({
    required this.id,
    required this.createdAt,
    required this.amount,
    required this.payment,
    required this.customerPhone,
    this.customerName,
    this.storeId,
    this.notes,
    this.isPendingSync = false,
    this.isVoided = false,
  });

  final String id;
  final DateTime createdAt;
  final double amount;
  final InvoicePayment payment;
  final String customerPhone;
  final String? customerName;
  final String? storeId;
  final String? notes;

  /// True if the deposit was created while offline and is waiting to sync.
  final bool isPendingSync;

  /// True if the deposit was voided.
  final bool isVoided;

  bool get isCash => payment == InvoicePayment.cash;
  bool get isOnline => payment == InvoicePayment.online;

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'amount': amount,
        'payment': payment.name,
        'customerPhone': customerPhone,
        if (customerName != null) 'customerName': customerName,
        if (storeId != null) 'storeId': storeId,
        if (notes != null) 'notes': notes,
        if (isVoided) 'isVoided': isVoided,
      };

  factory StoreDeposit.fromMap(Map<String, dynamic> map) {
    DateTime created;
    final rawCreated = map['createdAt'];
    if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    final paymentRaw = map['payment'] as String?;
    final payment = paymentRaw == 'online'
        ? InvoicePayment.online
        : InvoicePayment.cash;

    return StoreDeposit(
      id: map['id'] as String? ?? '',
      createdAt: created,
      amount: (map['amount'] as num? ?? 0).toDouble(),
      payment: payment,
      customerPhone: map['customerPhone'] as String? ?? '',
      customerName: map['customerName'] as String?,
      storeId: map['storeId'] as String?,
      notes: map['notes'] as String?,
      isPendingSync: map['isPendingSync'] as bool? ?? false,
      isVoided: map['isVoided'] as bool? ?? false,
    );
  }

  StoreDeposit copyWith({
    double? amount,
    String? notes,
    bool? isVoided,
  }) {
    return StoreDeposit(
      id: id,
      createdAt: createdAt,
      amount: amount ?? this.amount,
      payment: payment,
      customerPhone: customerPhone,
      customerName: customerName,
      storeId: storeId,
      notes: notes ?? this.notes,
      isPendingSync: isPendingSync,
      isVoided: isVoided ?? this.isVoided,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory StoreDeposit.fromJson(String raw) =>
      StoreDeposit.fromMap(jsonDecode(raw) as Map<String, dynamic>);
}
