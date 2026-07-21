/// Customer derived from sales / credit invoices (phone is stable id).
class StoreCustomer {
  const StoreCustomer({
    required this.phone,
    required this.name,
    this.email,
    this.creditBalance = 0,
    this.lastActivityAt,
    this.transactionCount = 0,
  });

  final String phone;
  final String name;
  final String? email;

  /// Outstanding credit (positive = amount owed by customer).
  final double creditBalance;
  final DateTime? lastActivityAt;
  final int transactionCount;

  String get id => phone;

  Map<String, dynamic> toMap() => {
        'phone': phone,
        'name': name,
        if (email != null && email!.isNotEmpty) 'email': email,
        'creditBalance': creditBalance,
        if (lastActivityAt != null)
          'lastActivityAt': lastActivityAt!.toIso8601String(),
        'transactionCount': transactionCount,
      };

  factory StoreCustomer.fromMap(Map<String, dynamic> map) {
    DateTime? last;
    final raw = map['lastActivityAt'];
    if (raw is String) last = DateTime.tryParse(raw);
    return StoreCustomer(
      phone: map['phone'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String?,
      creditBalance: (map['creditBalance'] as num? ?? 0).toDouble(),
      lastActivityAt: last,
      transactionCount: map['transactionCount'] as int? ?? 0,
    );
  }

  StoreCustomer copyWith({
    String? phone,
    String? name,
    String? email,
    double? creditBalance,
    DateTime? lastActivityAt,
    int? transactionCount,
  }) {
    return StoreCustomer(
      phone: phone ?? this.phone,
      name: name ?? this.name,
      email: email ?? this.email,
      creditBalance: creditBalance ?? this.creditBalance,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      transactionCount: transactionCount ?? this.transactionCount,
    );
  }
}
