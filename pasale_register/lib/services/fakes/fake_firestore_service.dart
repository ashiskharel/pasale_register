import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:mlkit_camera/mlkit_camera.dart';
import 'package:pasale_register/models/product.dart';
import 'package:pasale_register/models/store.dart';
import 'package:pasale_register/models/device.dart';
import 'package:pasale_register/models/store_customer.dart';
import 'package:pasale_register/models/store_deposit.dart';
import 'package:pasale_register/models/store_invoice.dart';
import 'package:pasale_register/models/vendor.dart';
import 'package:pasale_register/models/vendor_invoice.dart';
import 'package:pasale_register/models/inventory_log.dart';
import 'package:pasale_register/services/firestore_service.dart';

class FakeFirestoreService implements FirestoreService {
  static List<Product>? _staticSeededProducts;
  static Future<void>? _staticSeedingFuture;

  final Map<String, String> _stores = {};
  final Map<String, Map<String, dynamic>> _storeMeta = {};
  final Map<String, Map<String, dynamic>> _users = {};
  final Map<String, Map<String, dynamic>> _businesses = {};
  final Map<String, Map<String, Map<String, dynamic>>> _devices = {};
  /// Shared/seed products (no store).
  final Map<String, Product> _products = {};
  /// Per-store catalogs: storeId -> barcode -> product.
  final Map<String, Map<String, Product>> _storeProducts = {};
  /// businessId -> productId -> product (shared master catalog)
  final Map<String, Map<String, Product>> _businessCatalog = {};
  final Map<String, CameraScopePolicy> _cameraScopes = {};
  /// storeId -> invoiceId -> invoice
  final Map<String, Map<String, StoreInvoice>> _invoices = {};
  /// storeId -> depositId -> deposit
  final Map<String, Map<String, StoreDeposit>> _deposits = {};
  /// storeId -> phone -> customer
  final Map<String, Map<String, StoreCustomer>> _customers = {};
  final Map<String, Map<String, Vendor>> _vendors = {};
  final Map<String, Map<String, InventoryLog>> _inventoryLogs = {};
  final _invoiceControllers =
      <String, StreamController<List<StoreInvoice>>>{};
  final _depositControllers =
      <String, StreamController<List<StoreDeposit>>>{};
  final _customerControllers =
      <String, StreamController<List<StoreCustomer>>>{};
  final _vendorControllers =
      <String, StreamController<List<Vendor>>>{};
  final _inventoryLogControllers =
      <String, StreamController<List<InventoryLog>>>{};
  bool checkStoreActivation = false;
  bool _seeded = false;
  Future<void>? _seedingFuture;

  FakeFirestoreService() {
    _ensureSeeded();
  }

  Future<void> _ensureSeeded() async {
    if (_seeded) return;
    if (_staticSeededProducts != null) {
      for (var p in _staticSeededProducts!) {
        _products[p.id] = p;
      }
      _seeded = true;
      return;
    }
    _seedingFuture ??= _loadSeedData();
    await _seedingFuture;
  }

  Future<void> _loadSeedData() async {
    if (_staticSeedingFuture != null) {
      await _staticSeedingFuture;
      if (_staticSeededProducts != null) {
        for (var p in _staticSeededProducts!) {
          _products[p.id] = p;
        }
        _seeded = true;
        return;
      }
    }

    final completer = Completer<void>();
    _staticSeedingFuture = completer.future;

    try {
      final jsonString =
          await rootBundle.loadString('assets/seeded_products.json');
      final List<dynamic> data = json.decode(jsonString) as List<dynamic>;
      final List<Product> loaded = [];
      for (var item in data) {
        final map = item as Map<String, dynamic>;
        final id = map['id'] as String;
        final product = Product.fromMap(map, id);
        loaded.add(product);
        _products[id] = product;
      }
      _staticSeededProducts = loaded;
      _catalogController.add(_products.values.toList());
      _seeded = true;
      completer.complete();
    } catch (e) {
      print("FakeFirestoreService: Seed loading bypassed or failed: $e");
      _seeded = true;
      completer.complete();
    }
  }

  final StreamController<List<Product>> _catalogController =
      StreamController<List<Product>>.broadcast();

  Map<String, String> get stores => _stores;
  Map<String, Map<String, Map<String, dynamic>>> get devices => _devices;
  Map<String, Product> get products => _products;
  Map<String, Map<String, Product>> get storeProducts => _storeProducts;

  @override
  Future<MembershipProfile> ensureMembershipProfile({
    required String uid,
    String? phone,
    String? displayName,
    String? email,
    String? authProvider,
  }) async {
    final existingUser = _users[uid];
    final existingBizIds =
        (existingUser?['businessIds'] as List?)?.map((e) => '$e').toList() ??
            const <String>[];
    var businessId = existingBizIds.isNotEmpty ? existingBizIds.first : null;
    if (businessId == null || businessId.isEmpty) {
      businessId = 'biz_$uid';
      _businesses[businessId] = {
        'businessId': businessId,
        'ownerUid': uid,
        if (phone != null) 'primaryPhone': phone,
        'name': displayName ?? phone ?? 'Business',
        'storeIds': <String>[],
      };
    }
    _users[uid] = {
      'uid': uid,
      if (phone != null) 'primaryPhone': phone,
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email,
      if (authProvider != null) 'authProvider': authProvider,
      'businessIds': [businessId],
      if (existingUser?['defaultStoreId'] != null)
        'defaultStoreId': existingUser!['defaultStoreId'],
    };
    final storeIds =
        List<String>.from(_businesses[businessId]?['storeIds'] as List? ?? []);
    return MembershipProfile(
      uid: uid,
      businessId: businessId,
      defaultStoreId: _users[uid]!['defaultStoreId'] as String?,
      storeIds: storeIds,
    );
  }

  @override
  Future<void> activateStore(
    String storeId,
    String storeName, {
    required String ownerUid,
    String? businessId,
    String? ownerPhone,
  }) async {
    final store = Store(
      storeId: storeId,
      name: storeName,
      activationDate: DateTime.now(),
    );
    _stores[storeId] = store.name;
    var bid = businessId;
    if (bid == null || bid.isEmpty) {
      final profile = await ensureMembershipProfile(
        uid: ownerUid,
        phone: ownerPhone,
        displayName: storeName,
      );
      bid = profile.businessId;
    }
    _storeMeta[storeId] = {
      'storeId': storeId,
      'name': storeName,
      'businessId': bid,
      'ownerUid': ownerUid,
      'memberUids': [ownerUid],
      'catalogMode': 'shared',
      'isActive': true,
    };
    final biz = _businesses[bid] ??
        {
          'businessId': bid,
          'ownerUid': ownerUid,
          'storeIds': <String>[],
        };
    final ids = List<String>.from(biz['storeIds'] as List? ?? []);
    if (!ids.contains(storeId)) ids.add(storeId);
    biz['storeIds'] = ids;
    _businesses[bid] = biz;
    final user = _users[ownerUid] ?? {'uid': ownerUid, 'businessIds': [bid]};
    user['defaultStoreId'] = storeId;
    user['businessIds'] = [bid];
    _users[ownerUid] = user;
  }

  @override
  Future<List<Map<String, dynamic>>> listMemberStores({
    required String uid,
  }) async {
    return _storeMeta.values
        .where((m) {
          final members = (m['memberUids'] as List?)?.map((e) => '$e').toList() ??
              const <String>[];
          return m['ownerUid'] == uid || members.contains(uid);
        })
        .map((m) => Map<String, dynamic>.from(m))
          .toList();
  }

  @override
  Future<String> getOrGeneratePasscode(String storeId) async {
    final meta = _storeMeta[storeId];
    if (meta != null && meta.containsKey('passcode')) {
      return meta['passcode'] as String;
    }
    final code = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
    if (meta != null) {
      meta['passcode'] = code;
    } else {
      _storeMeta[storeId] = {'storeId': storeId, 'passcode': code};
    }
    return code;
  }

  @override
  Future<void> joinStore({
    required String storeId,
    required String passcode,
    required String uid,
    String? phone,
    String? displayName,
  }) async {
    final meta = _storeMeta[storeId];
    if (meta == null) throw Exception('Store not found');
    if (meta['passcode'] != passcode) throw Exception('Invalid passcode');
    
    await ensureMembershipProfile(uid: uid, phone: phone, displayName: displayName);
    final members = (meta['memberUids'] as List?)?.cast<String>() ?? [];
    if (!members.contains(uid)) members.add(uid);
    meta['memberUids'] = members;
  }

  @override
  Future<void> healStoreMembership({
    required String storeId,
    required String ownerUid,
    String? businessId,
    String? ownerPhone,
    String? storeName,
  }) async {
    final profile = await ensureMembershipProfile(
      uid: ownerUid,
      phone: ownerPhone,
      displayName: storeName,
    );
    final bid = (businessId != null && businessId.isNotEmpty)
        ? businessId
        : profile.businessId;
    final existing = _storeMeta[storeId];
    if (existing != null) {
      final eo = existing['ownerUid'] as String?;
      if (eo != null && eo.isNotEmpty && eo != ownerUid) return;
    }
    final name = storeName ??
        existing?['name'] as String? ??
        _stores[storeId] ??
        storeId;
    _stores[storeId] = name;
    _storeMeta[storeId] = {
      'storeId': storeId,
      'name': name,
      'businessId': bid,
      'ownerUid': ownerUid,
      'memberUids': [ownerUid],
      'catalogMode': 'shared',
      'isActive': true,
    };
    final biz = _businesses[bid] ??
        {'businessId': bid, 'ownerUid': ownerUid, 'storeIds': <String>[]};
    final ids = List<String>.from(biz['storeIds'] as List? ?? []);
    if (!ids.contains(storeId)) ids.add(storeId);
    biz['storeIds'] = ids;
    _businesses[bid] = biz;
  }

  @override
  Future<void> createBranchStore({
    required String storeId,
    required String storeName,
    required String ownerUid,
    required String businessId,
    String? ownerPhone,
  }) async {
    await activateStore(
      storeId,
      storeName,
      ownerUid: ownerUid,
      businessId: businessId,
      ownerPhone: ownerPhone,
    );
    final master = _businessCatalog[businessId] ?? {};
    for (final p in master.values) {
      await saveProduct(
        p.copyWith(storeId: storeId),
        storeId: storeId,
        businessId: businessId,
        syncToBusiness: false,
      );
    }
  }

  @override
  Future<void> registerDevice(
    String storeId,
    String deviceId,
    Map<String, dynamic> deviceMetadata,
  ) async {
    if (checkStoreActivation && !_stores.containsKey(storeId)) {
      throw Exception('Store not activated');
    }
    final device = Device(
      deviceId: deviceId,
      model: deviceMetadata['model'] as String? ?? 'Unknown',
      osVersion: deviceMetadata['osVersion'] as String? ?? 'Unknown',
      lastActive: DateTime.now(),
    );
    _devices.putIfAbsent(storeId, () => {})[deviceId] = {
      ...deviceMetadata,
      ...device.toMap(),
    };
  }

  @override
  Future<Product?> getProduct(
    String id, {
    String? storeId,
    String? businessId,
  }) async {
    await _ensureSeeded();
    if (storeId != null && storeId.isNotEmpty) {
      final storeMap = _storeProducts[storeId];
      if (storeMap != null && storeMap.containsKey(id)) {
        return storeMap[id];
      }
    }
    if (businessId != null && businessId.isNotEmpty) {
      final master = _businessCatalog[businessId]?[id];
      if (master != null) {
        return storeId != null ? master.copyWith(storeId: storeId) : master;
      }
    }
    return _products[id];
  }

  @override
  Future<void> saveProduct(
    Product product, {
    String? storeId,
    String? businessId,
    bool syncToBusiness = true,
  }) async {
    await _ensureSeeded();
    final sid = product.storeId ?? storeId;
    final toSave = (product.storeId == null && sid != null)
        ? product.copyWith(storeId: sid)
        : product;
    if (sid != null && sid.isNotEmpty) {
      _storeProducts.putIfAbsent(sid, () => {})[toSave.id] = toSave;
      _catalogController.add(_storeProducts[sid]!.values.toList());
    } else {
      _products[toSave.id] = toSave;
      _catalogController.add(_products.values.toList());
    }
    if (syncToBusiness &&
        businessId != null &&
        businessId.isNotEmpty) {
      _businessCatalog.putIfAbsent(businessId, () => {})[toSave.id] =
          toSave.copyWith(storeId: null);
    }
  }

  List<Product> _catalogSnapshot(String? storeId, {String? businessId}) {
    final byId = Map<String, Product>.from(_products);
    if (businessId != null && businessId.isNotEmpty) {
      final master = _businessCatalog[businessId] ?? {};
      for (final e in master.entries) {
        byId[e.key] = storeId != null
            ? e.value.copyWith(storeId: storeId)
            : e.value;
      }
    }
    if (storeId != null && storeId.isNotEmpty) {
      byId.addAll(_storeProducts[storeId] ?? {});
    }
    return byId.values.toList();
  }

  @override
  Stream<List<Product>> streamCatalog({
    String? storeId,
    String? businessId,
  }) async* {
    await _ensureSeeded();
    yield _catalogSnapshot(storeId, businessId: businessId);
    await for (final _ in _catalogController.stream) {
      yield _catalogSnapshot(storeId, businessId: businessId);
    }
  }

  @override
  Future<CameraScopePolicy> getCameraScope(String storeId) async {
    var policy = _cameraScopes[storeId] ??
        CameraScopePolicy.freeDefault(updatedBy: 'fake');
    if (!policy.allows(CameraCapability.textOcr)) {
      policy = policy.withCapability(
        CameraCapability.textOcr,
        enabled: true,
        updatedBy: 'system-migrate-ocr',
      );
      _cameraScopes[storeId] = policy;
    }
    return policy;
  }

  @override
  Future<void> saveCameraScope(String storeId, CameraScopePolicy policy) async {
    _cameraScopes[storeId] = policy;
  }

  Map<String, CameraScopePolicy> get cameraScopes => _cameraScopes;

  void _emitInvoices(String storeId) {
    final list = (_invoices[storeId] ?? {}).values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _invoiceControllers[storeId]?.add(list);
  }

  void _emitCustomers(String storeId) {
    final list = (_customers[storeId] ?? {}).values.toList()
      ..sort((a, b) {
        final aa = a.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bb = b.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bb.compareTo(aa);
      });
    _customerControllers[storeId]?.add(list);
  }

  @override
  Future<void> saveInvoice(
    StoreInvoice invoice, {
    required String storeId,
  }) async {
    final withStore = invoice.storeId == null || invoice.storeId!.isEmpty
        ? StoreInvoice(
            id: invoice.id,
            createdAt: invoice.createdAt,
            total: invoice.total,
            payment: invoice.payment,
            source: invoice.source,
            customerPhone: invoice.customerPhone,
            customerName: invoice.customerName,
            customerEmail: invoice.customerEmail,
            storeId: storeId,
            storeName: invoice.storeName,
            notes: invoice.notes,
            lineSummary: invoice.lineSummary,
          )
        : invoice;
    _invoices.putIfAbsent(storeId, () => {})[withStore.id] = withStore;
    _emitInvoices(storeId);

    final phone = withStore.customerPhone?.trim();
    if (phone != null && phone.isNotEmpty) {
      final map = _customers.putIfAbsent(storeId, () => {});
      final existing = map[phone];
      final creditDelta = invoice.isCredit ? invoice.total : 0.0;
      map[phone] = StoreCustomer(
        phone: phone,
        name: (withStore.customerName?.trim().isNotEmpty == true)
            ? withStore.customerName!.trim()
            : (existing?.name ?? phone),
        email: withStore.customerEmail ?? existing?.email,
        creditBalance: (existing?.creditBalance ?? 0) + creditDelta,
        lastActivityAt: withStore.createdAt,
        transactionCount: (existing?.transactionCount ?? 0) + 1,
      );
      _emitCustomers(storeId);
    }
  }

  @override
  Stream<List<StoreInvoice>> streamInvoices({required String storeId}) {
    final controller = _invoiceControllers.putIfAbsent(
      storeId,
      () => StreamController<List<StoreInvoice>>.broadcast(),
    );
    // Immediate snapshot for new listeners.
    Future.microtask(() => _emitInvoices(storeId));
    return controller.stream;
  }

  @override
  Future<List<StoreInvoice>> fetchInvoices({required String storeId}) async {
    final list = (_invoices[storeId] ?? {}).values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  void _emitDeposits(String storeId) {
    final list = (_deposits[storeId] ?? {}).values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _depositControllers[storeId]?.add(list);
  }

  @override
  Future<void> saveDeposit(
    StoreDeposit deposit, {
    required String storeId,
  }) async {
    final id = deposit.id.isNotEmpty
        ? deposit.id
        : 'DEP_${DateTime.now().millisecondsSinceEpoch}';
    final toSave = StoreDeposit(
      id: id,
      createdAt: deposit.createdAt,
      amount: deposit.amount,
      payment: deposit.payment,
      customerPhone: deposit.customerPhone,
      customerName: deposit.customerName,
      storeId: storeId,
      notes: deposit.notes,
    );
    _deposits.putIfAbsent(storeId, () => {})[id] = toSave;
    _emitDeposits(storeId);

    final phone = toSave.customerPhone.trim();
    if (phone.isNotEmpty) {
      final map = _customers.putIfAbsent(storeId, () => {});
      final existing = map[phone];
      map[phone] = StoreCustomer(
        phone: phone,
        name: (toSave.customerName?.trim().isNotEmpty == true)
            ? toSave.customerName!.trim()
            : (existing?.name ?? phone),
        email: existing?.email,
        creditBalance: (existing?.creditBalance ?? 0) - toSave.amount,
        lastActivityAt: toSave.createdAt,
        transactionCount: (existing?.transactionCount ?? 0) + 1,
      );
      _emitCustomers(storeId);
    }
  }

  @override
  Stream<List<StoreDeposit>> streamDeposits({required String storeId}) {
    final controller = _depositControllers.putIfAbsent(
      storeId,
      () => StreamController<List<StoreDeposit>>.broadcast(),
    );
    Future.microtask(() => _emitDeposits(storeId));
    return controller.stream;
  }

  @override
  Future<List<StoreDeposit>> fetchDeposits({required String storeId}) async {
    final list = (_deposits[storeId] ?? {}).values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> upsertCustomer(
    StoreCustomer customer, {
    required String storeId,
  }) async {
    _customers.putIfAbsent(storeId, () => {})[customer.phone] = customer;
    _emitCustomers(storeId);
  }

  @override
  Stream<List<StoreCustomer>> streamCustomers({required String storeId}) {
    final controller = _customerControllers.putIfAbsent(
      storeId,
      () => StreamController<List<StoreCustomer>>.broadcast(),
    );
    Future.microtask(() => _emitCustomers(storeId));
    return controller.stream;
  }

  @override
  Future<List<StoreCustomer>> fetchCustomers({required String storeId}) async {
    final list = (_customers[storeId] ?? {}).values.toList()
      ..sort((a, b) {
        final aa = a.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bb = b.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bb.compareTo(aa);
      });
    return list;
  }

  void _emitVendors(String storeId) {
    final list = (_vendors[storeId] ?? {}).values.toList();
    _vendorControllers[storeId]?.add(list);
  }

  @override
  Future<void> saveVendor(Vendor vendor, {required String storeId}) async {
    final id = vendor.id.isNotEmpty ? vendor.id : 'VEND_${DateTime.now().millisecondsSinceEpoch}';
    final v = vendor.copyWith(id: id, storeId: storeId);
    _vendors.putIfAbsent(storeId, () => {})[id] = v;
    _emitVendors(storeId);
  }

  @override
  Stream<List<Vendor>> streamVendors({required String storeId}) {
    final controller = _vendorControllers.putIfAbsent(
      storeId,
      () => StreamController<List<Vendor>>.broadcast(),
    );
    Future.microtask(() => _emitVendors(storeId));
    return controller.stream;
  }

  @override
  Future<List<Vendor>> fetchVendors({required String storeId}) async {
    return (_vendors[storeId] ?? {}).values.toList();
  }

  void _emitInventoryLogs(String storeId) {
    final list = (_inventoryLogs[storeId] ?? {}).values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _inventoryLogControllers[storeId]?.add(list);
  }

  @override
  Future<void> saveInventoryLog(InventoryLog log, {required String storeId}) async {
    final id = log.id.isNotEmpty ? log.id : 'INVLOG_${DateTime.now().millisecondsSinceEpoch}';
    final l = InventoryLog(
      id: id,
      storeId: storeId,
      productId: log.productId,
      productName: log.productName,
      changeAmount: log.changeAmount,
      previousQuantity: log.previousQuantity,
      newQuantity: log.newQuantity,
      reason: log.reason,
      timestamp: log.timestamp,
    );
    _inventoryLogs.putIfAbsent(storeId, () => {})[id] = l;
    _emitInventoryLogs(storeId);
  }

  @override
  Stream<List<InventoryLog>> streamInventoryLogs({required String storeId}) {
    final controller = _inventoryLogControllers.putIfAbsent(
      storeId,
      () => StreamController<List<InventoryLog>>.broadcast(),
    );
    Future.microtask(() => _emitInventoryLogs(storeId));
    return controller.stream;
  }

  @override
  Future<List<InventoryLog>> fetchInventoryLogs({required String storeId}) async {
    final list = (_inventoryLogs[storeId] ?? {}).values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  final Map<String, Map<String, VendorInvoice>> _vendorInvoices = {};
  final _vendorInvoiceControllers = <String, StreamController<List<VendorInvoice>>>{};

  @override
  Stream<List<Map<String, dynamic>>> streamStoresForVendor({required String vendorPhone}) async* {
    yield _storeMeta.values.where((meta) {
      final storeId = meta['storeId'] as String;
      final storeVendors = _vendors[storeId]?.values ?? [];
      return storeVendors.any((v) => v.salespersonPhones.contains(vendorPhone));
    }).map((m) => Map<String, dynamic>.from(m)).toList();
  }

  void _emitVendorInvoices(String storeId) {
    final list = (_vendorInvoices[storeId] ?? {}).values.toList()
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    _vendorInvoiceControllers[storeId]?.add(list);
  }

  @override
  Future<void> saveVendorInvoice(VendorInvoice invoice, {required String storeId}) async {
    final id = invoice.id.isNotEmpty ? invoice.id : 'V_INV_${DateTime.now().millisecondsSinceEpoch}';
    final inv = invoice.copyWith(id: id, storeId: storeId);
    _vendorInvoices.putIfAbsent(storeId, () => {})[id] = inv;
    _emitVendorInvoices(storeId);
  }

  @override
  Stream<List<VendorInvoice>> streamVendorInvoices({required String storeId, String? vendorUid}) {
    final controller = _vendorInvoiceControllers.putIfAbsent(
      storeId,
      () => StreamController<List<VendorInvoice>>.broadcast(),
    );
    Future.microtask(() => _emitVendorInvoices(storeId));
    if (vendorUid == null || vendorUid.isEmpty) {
      return controller.stream;
    } else {
      return controller.stream.map((list) => list.where((i) => i.vendorUid == vendorUid).toList());
    }
  }
}
