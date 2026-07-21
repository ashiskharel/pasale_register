class Vendor {
  final String id;
  final String name;
  final String storeId;
  final String phone;
  final String contactPerson;
  final String notes;
  final List<String> salespersonPhones;

  Vendor({
    required this.id,
    required this.name,
    required this.storeId,
    this.phone = '',
    this.contactPerson = '',
    this.notes = '',
    this.salespersonPhones = const [],
  });

  Vendor copyWith({
    String? id,
    String? name,
    String? storeId,
    String? phone,
    String? contactPerson,
    String? notes,
    List<String>? salespersonPhones,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      storeId: storeId ?? this.storeId,
      phone: phone ?? this.phone,
      contactPerson: contactPerson ?? this.contactPerson,
      notes: notes ?? this.notes,
      salespersonPhones: salespersonPhones ?? this.salespersonPhones,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'storeId': storeId,
      'phone': phone,
      'contactPerson': contactPerson,
      'notes': notes,
      'salespersonPhones': salespersonPhones,
    };
  }

  factory Vendor.fromMap(Map<String, dynamic> map, String id) {
    return Vendor(
      id: id,
      name: map['name'] as String? ?? '',
      storeId: map['storeId'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      contactPerson: map['contactPerson'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      salespersonPhones: (map['salespersonPhones'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}
