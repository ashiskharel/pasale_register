import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mlkit_camera/mlkit_camera.dart';

import '../models/device.dart';
import '../models/product.dart';
import '../models/store.dart';
import 'firestore_service.dart';

class RealFirestoreService implements FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    // Legacy / shared fallback
    return _firestore.collection('products');
  }

  @override
  Future<void> activateStore(String storeId, String storeName) async {
    final store = Store(
      storeId: storeId,
      name: storeName,
      activationDate: DateTime.now(),
    );
    await _firestore.collection('stores').doc(storeId).set(store.toMap());
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
      lastActive: DateTime.now(),
    );
    await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('devices')
        .doc(deviceId)
        .set(device.toMap());
  }

  @override
  Future<Product?> getProduct(String id, {String? storeId}) async {
    // Prefer per-store catalog (store-specific price + photo).
    if (storeId != null && storeId.isNotEmpty) {
      final storeDoc = await _productsCol(storeId).doc(id).get();
      if (storeDoc.exists && storeDoc.data() != null) {
        return Product.fromMap(storeDoc.data()!, storeDoc.id);
      }
    }
    // Fallback to global products collection (seed / legacy).
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
    await _productsCol(sid).doc(toSave.id).set(toSave.toMap());
  }

  @override
  Stream<List<Product>> streamCatalog({String? storeId}) {
    return _productsCol(storeId).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Product.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<CameraScopePolicy> getCameraScope(String storeId) async {
    final doc = await _cameraScopeRef(storeId).get();
    if (!doc.exists || doc.data() == null) {
      final free = CameraScopePolicy.freeDefault(updatedBy: 'system');
      await saveCameraScope(storeId, free);
      return free;
    }
    return CameraScopePolicy.fromJson(doc.data()!);
  }

  @override
  Future<void> saveCameraScope(String storeId, CameraScopePolicy policy) async {
    await _cameraScopeRef(storeId).set(policy.toJson(), SetOptions(merge: true));
  }
}
