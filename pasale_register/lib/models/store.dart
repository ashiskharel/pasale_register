class Store {
  final String storeId;
  final String name;
  final DateTime activationDate;

  Store({
    required this.storeId,
    required this.name,
    required this.activationDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'name': name,
      'activationDate': activationDate.toIso8601String(),
    };
  }

  factory Store.fromMap(Map<String, dynamic> map, String storeId) {
    final rawDate = map['activationDate'];
    DateTime activationDate = DateTime.now();
    if (rawDate is String) {
      activationDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is DateTime) {
      activationDate = rawDate;
    } else if (rawDate != null) {
      try {
        activationDate = (rawDate as dynamic).toDate();
      } catch (_) {}
    }
    return Store(
      storeId: storeId,
      name: map['name'] as String? ?? '',
      activationDate: activationDate,
    );
  }
}
