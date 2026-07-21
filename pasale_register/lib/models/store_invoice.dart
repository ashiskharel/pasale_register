import 'dart:convert';
import 'dart:math';

import 'cart_item.dart';

enum InvoiceSource {
  cart,
  manual,
}

enum InvoicePayment {
  cash,
  credit,
  online,
}

/// A completed store sale / manual invoice for history.
class StoreInvoice {
  const StoreInvoice({
    required this.id,
    required this.createdAt,
    required this.total,
    required this.payment,
    required this.source,
    this.customerPhone,
    this.customerName,
    this.customerEmail,
    this.storeId,
    this.storeName,
    this.notes,
    this.lineSummary,
    this.isPendingSync = false,
    this.isVoided = false,
  });

  final String id;
  final DateTime createdAt;
  final double total;
  final InvoicePayment payment;
  final InvoiceSource source;
  final String? customerPhone;
  final String? customerName;
  final String? customerEmail;
  final String? storeId;
  final String? storeName;
  final String? notes;

  /// Human-readable lines (e.g. "Soap x2").
  final List<String>? lineSummary;

  /// True if the invoice was created while offline and is waiting to sync.
  final bool isPendingSync;

  /// True if the invoice was voided.
  final bool isVoided;

  bool get isCash => payment == InvoicePayment.cash;
  bool get isCredit => payment == InvoicePayment.credit;
  bool get isOnline => payment == InvoicePayment.online;

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'total': total,
        'payment': payment.name,
        'source': source.name,
        'isPaid': isCash || isOnline,
        if (customerPhone != null) 'customerPhone': customerPhone,
        if (customerName != null) 'customerName': customerName,
        if (customerEmail != null) 'customerEmail': customerEmail,
        if (storeId != null) 'storeId': storeId,
        if (storeName != null) 'storeName': storeName,
        if (notes != null) 'notes': notes,
        if (lineSummary != null) 'lineSummary': lineSummary,
        if (isVoided) 'isVoided': isVoided,
      };

  factory StoreInvoice.fromMap(Map<String, dynamic> map) {
    DateTime created;
    final rawCreated = map['createdAt'];
    if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    final paymentRaw = map['payment'] as String?;
    final isPaid = map['isPaid'] as bool?;
    final payment = paymentRaw == 'online'
        ? InvoicePayment.online
        : (paymentRaw == 'credit' || isPaid == false
            ? InvoicePayment.credit
            : InvoicePayment.cash);

    return StoreInvoice(
      id: map['id'] as String? ?? map['saleId'] as String? ?? '',
      createdAt: created,
      total: (map['total'] as num? ?? map['totalPrice'] as num? ?? 0)
          .toDouble(),
      payment: payment,
      source: (map['source'] as String?) == 'manual'
          ? InvoiceSource.manual
          : InvoiceSource.cart,
      customerPhone: map['customerPhone'] as String?,
      customerName: map['customerName'] as String?,
      customerEmail: map['customerEmail'] as String?,
      storeId: map['storeId'] as String?,
      storeName: map['storeName'] as String?,
      notes: map['notes'] as String?,
      lineSummary: (map['lineSummary'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      isPendingSync: map['isPendingSync'] as bool? ?? false,
      isVoided: map['isVoided'] as bool? ?? false,
    );
  }

  StoreInvoice copyWith({
    double? total,
    String? notes,
    bool? isVoided,
  }) {
    return StoreInvoice(
      id: id,
      createdAt: createdAt,
      total: total ?? this.total,
      payment: payment,
      source: source,
      customerPhone: customerPhone,
      customerName: customerName,
      customerEmail: customerEmail,
      storeId: storeId,
      storeName: storeName,
      notes: notes ?? this.notes,
      lineSummary: lineSummary,
      isPendingSync: isPendingSync,
      isVoided: isVoided ?? this.isVoided,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory StoreInvoice.fromJson(String raw) =>
      StoreInvoice.fromMap(jsonDecode(raw) as Map<String, dynamic>);

  static StoreInvoice fromCart({
    required List<CartItem> cart,
    required double total,
    required InvoicePayment payment,
    String? customerPhone,
    String? customerName,
    String? customerEmail,
    String? storeId,
    String? storeName,
  }) {
    final lines = cart
        .map(
          (i) =>
              '${i.product.name} x${i.quantity} · Rs. ${(i.product.sellingPrice * i.quantity).toStringAsFixed(2)}',
        )
        .toList();
    return StoreInvoice(
      id: 'CART_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
      createdAt: DateTime.now(),
      total: total,
      payment: payment,
      source: InvoiceSource.cart,
      customerPhone: customerPhone,
      customerName: customerName,
      customerEmail: customerEmail,
      storeId: storeId,
      storeName: storeName,
      lineSummary: lines,
    );
  }

  static StoreInvoice fromManual({
    required DateTime date,
    required double total,
    required InvoicePayment payment,
    required String customerPhone,
    String? customerName,
    String? customerEmail,
    String? storeId,
    String? storeName,
    String? notes,
  }) {
    return StoreInvoice(
      id: 'MAN_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
      createdAt: date,
      total: total,
      payment: payment,
      source: InvoiceSource.manual,
      customerPhone: customerPhone,
      customerName: customerName,
      customerEmail: customerEmail,
      storeId: storeId,
      storeName: storeName,
      notes: notes,
      lineSummary: notes != null && notes.isNotEmpty ? [notes] : null,
    );
  }

}

/// Snapshot of invoice list totals.
class InvoiceTotals {
  const InvoiceTotals({
    required this.cashTotal,
    required this.creditTotal,
    required this.count,
  });

  final double cashTotal;
  final double creditTotal;
  final int count;

  double get grandTotal => cashTotal + creditTotal;
  double get revenue => grandTotal;
}

extension StoreInvoiceListX on List<StoreInvoice> {
  InvoiceTotals get totals {
    var cash = 0.0;
    var credit = 0.0;
    for (final inv in this) {
      if (inv.isVoided) continue;
      if (inv.isCash || inv.isOnline) {
        cash += inv.total;
      } else {
        credit += inv.total;
      }
    }
    return InvoiceTotals(
      cashTotal: cash,
      creditTotal: credit,
      count: length,
    );
  }

  List<StoreInvoice> inPeriod(DateTime start, DateTime end) {
    return where(
      (i) =>
          !i.createdAt.isBefore(start) && i.createdAt.isBefore(end),
    ).toList();
  }

  List<StoreInvoice> forPhone(String phone) {
    final p = phone.trim();
    return where((i) => (i.customerPhone ?? '').trim() == p).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
