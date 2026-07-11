import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mlkit_camera/mlkit_camera.dart';

import '../models/device.dart';
import '../models/product.dart';
import '../models/store.dart';
import 'firestore_service.dart';

/// Production Firestore access. Paths and fields match [docs/FIRESTORE_SCHEMA.md].
class RealFirestoreService implements FirestoreService {
  RealFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _cameraScopeRef(String storeId) {
    return _firestore
        .collection('stores')
        .doc(storeId)
        .collection('settings')
        .doc('cameraScope');
  }

  CollectionReference<Map<String, dynamic>> _productsCol(String? storeId) {
    if (storeId != null && storeId.isNotEmpty) {
      return _firestore
          .collection('stores')
          .doc(storeId)
          .collection('products');
    }
    return _firestore.collection('products');
  }

  Map<String, dynamic> _withServerTimes(
    Map<String, dynamic> data, {
    bool isCreate = false,
  }) {
    final out = Map<String, dynamic>.from(data);
    out['updatedAt'] = FieldValue.serverTimestamp();
    if (isCreate) {
      out['createdAt'] = FieldValue.serverTimestamp();
    }
    return out;
  }

  @override
  Future<void> activateStore(String storeId, String storeName) async {
    final store = Store(
      storeId: storeId,
      name: storeName,
      activationDate: DateTime.now().toUtc(),
    );
    final ref = _firestore.collection('stores').doc(storeId);
    final existing = await ref.get();
    final payload = _withServerTimes(
      {
        ...store.toMap(),
        'isActive': true,
        'currency': 'NPR',
        'planTier': 'free',
      },
      isCreate: !existing.exists,
    );
    await ref.set(payload, SetOptions(merge: true));

    // Ensure default camera scope exists for the store.
    final scopeRef = _cameraScopeRef(storeId);
    final scopeDoc = await scopeRef.get();
    if (!scopeDoc.exists) {
      await saveCameraScope(
        storeId,
        CameraScopePolicy.freeDefault(updatedBy: 'system'),
      );
    }
  }

  @override
  Future<void> registerDevice(
    String storeId,
    String deviceId,
    Map<String, dynamic> deviceMetadata,
  ) async {
    final device = Device(
      deviceId: deviceId,
      model: deviceMetadata['model'] as String? ?? 'Unknown',
      osVersion: deviceMetadata['osVersion'] as String? ?? 'Unknown',
      lastActive: DateTime.now().toUtc(),
    );
    final ref = _firestore
        .collection('stores')
        .doc(storeId)
        .collection('devices')
        .doc(deviceId);
    final existing = await ref.get();
    final payload = _withServerTimes(
      {
        ...device.toMap(),
        if (deviceMetadata['platform'] != null)
          'platform': deviceMetadata['platform'],
        if (deviceMetadata['appVersion'] != null)
          'appVersion': deviceMetadata['appVersion'],
      },
      isCreate: !existing.exists,
    );
    await ref.set(payload, SetOptions(merge: true));
  }

  @override
  Future<Product?> getProduct(String id, {String? storeId}) async {
    if (storeId != null && storeId.isNotEmpty) {
      final storeDoc = await _productsCol(storeId).doc(id).get();
      if (storeDoc.exists && storeDoc.data() != null) {
        return Product.fromMap(storeDoc.data()!, storeDoc.id);
      }
    }
    final global = await _firestore.collection('products').doc(id).get();
    if (!global.exists || global.data() == null) return null;
    return Product.fromMap(global.data()!, global.id);
  }

  @override
  Future<void> saveProduct(Product product, {String? storeId}) async {
    final sid = product.storeId ?? storeId;
    final toSave = product.storeId == null && sid != null
        ? product.copyWith(storeId: sid)
        : product;
    final ref = _productsCol(sid).doc(toSave.id);
    final existing = await ref.get();
    final payload = _withServerTimes(
      {
        ...toSave.toMap(),
        'isActive': true,
        // Keep imageUrl key present for Storage uploads later.
        'imageUrl': toSave.imagePath != null &&
                (toSave.imagePath!.startsWith('http://') ||
                    toSave.imagePath!.startsWith('https://'))
            ? toSave.imagePath
            : null,
      },
      isCreate: !existing.exists,
    );
    // Drop null imageUrl so we don't wipe existing cloud URLs on merge.
    if (payload['imageUrl'] == null) {
      payload.remove('imageUrl');
    }
    await ref.set(payload, SetOptions(merge: true));
  }

  @override
  Stream<List<Product>> streamCatalog({String? storeId}) {
    return _productsCol(storeId).snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.data()['isActive'] != false)
          .map((doc) => Product.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Map<String, dynamic> _normalizeJsonTimestamps(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    for (final key in ['updatedAt', 'createdAt', 'activationDate', 'lastActive']) {
      final v = data[key];
      if (v is Timestamp) {
        data[key] = v.toDate().toUtc().toIso8601String();
      }
    }
    return data;
  }

  @override
  Future<CameraScopePolicy> getCameraScope(String storeId) async {
    final doc = await _cameraScopeRef(storeId).get();
    if (!doc.exists || doc.data() == null) {
      final free = CameraScopePolicy.freeDefault(updatedBy: 'system');
      await saveCameraScope(storeId, free);
      return free;
    }
    return CameraScopePolicy.fromJson(
      _normalizeJsonTimestamps(doc.data()!),
    );
  }

  @override
  Future<void> saveCameraScope(String storeId, CameraScopePolicy policy) async {
    final data = policy.toJson();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _cameraScopeRef(storeId).set(data, SetOptions(merge: true));
  }

  /// Optional: persist a completed checkout for analytics / history.
  Future<void> saveSale({
    required String storeId,
    required String saleId,
    required double totalPrice,
    required bool isPaid,
    required List<Map<String, dynamic>> items,
    String? deviceId,
    String? customerPhone,
  }) async {
    final ref = _firestore
        .collection('stores')
        .doc(storeId)
        .collection('sales')
        .doc(saleId);
    await ref.set({
      'saleId': saleId,
      'storeId': storeId,
      if (deviceId != null) 'deviceId': deviceId,
      'totalPrice': totalPrice,
      'isPaid': isPaid,
      if (customerPhone != null) 'customerPhone': customerPhone,
      'items': items,
      'status': 'completed',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
