import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:mlkit_camera/mlkit_camera.dart';
import 'package:pasale_register/models/product.dart';
import 'package:pasale_register/models/store.dart';
import 'package:pasale_register/models/device.dart';
import 'package:pasale_register/services/firestore_service.dart';

class FakeFirestoreService implements FirestoreService {
  static List<Product>? _staticSeededProducts;
  static Future<void>? _staticSeedingFuture;

  final Map<String, String> _stores = {};
  final Map<String, Map<String, Map<String, dynamic>>> _devices = {};
  /// Shared/seed products (no store).
  final Map<String, Product> _products = {};
  /// Per-store catalogs: storeId -> barcode -> product.
  final Map<String, Map<String, Product>> _storeProducts = {};
  final Map<String, CameraScopePolicy> _cameraScopes = {};
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
  Future<void> activateStore(String storeId, String storeName) async {
    final store = Store(
      storeId: storeId,
      name: storeName,
      activationDate: DateTime.now(),
    );
    _stores[storeId] = store.name;
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
  Future<Product?> getProduct(String id, {String? storeId}) async {
    await _ensureSeeded();
    if (storeId != null && storeId.isNotEmpty) {
      final storeMap = _storeProducts[storeId];
      if (storeMap != null && storeMap.containsKey(id)) {
        return storeMap[id];
      }
    }
    return _products[id];
  }

  @override
  Future<void> saveProduct(Product product, {String? storeId}) async {
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
  }

  @override
  Stream<List<Product>> streamCatalog({String? storeId}) {
    final controller = StreamController<List<Product>>();

    _ensureSeeded().then((_) {
      if (!controller.isClosed) {
        if (storeId != null && storeId.isNotEmpty) {
          final storeMap = _storeProducts[storeId] ?? {};
          // Merge store-specific over seeds for same barcode.
          final merged = Map<String, Product>.from(_products)..addAll(storeMap);
          controller.add(merged.values.toList());
        } else {
          controller.add(_products.values.toList());
        }
      }
    });

    final subscription = _catalogController.stream.listen((data) {
      if (!controller.isClosed) {
        if (storeId != null && storeId.isNotEmpty) {
          final storeMap = _storeProducts[storeId] ?? {};
          final merged = Map<String, Product>.from(_products)..addAll(storeMap);
          controller.add(merged.values.toList());
        } else {
          controller.add(data);
        }
      }
    });

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<CameraScopePolicy> getCameraScope(String storeId) async {
    return _cameraScopes[storeId] ??
        CameraScopePolicy.freeDefault(updatedBy: 'fake');
  }

  @override
  Future<void> saveCameraScope(String storeId, CameraScopePolicy policy) async {
    _cameraScopes[storeId] = policy;
  }

  Map<String, CameraScopePolicy> get cameraScopes => _cameraScopes;
}
