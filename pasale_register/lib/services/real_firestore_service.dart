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
  Future<Product?> getProduct(String id) async {
    final doc = await _firestore.collection('products').doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Product.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<void> saveProduct(Product product) async {
    await _firestore.collection('products').doc(product.id).set(product.toMap());
  }

  @override
  Stream<List<Product>> streamCatalog() {
    return _firestore.collection('products').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Product.fromMap(doc.data(), doc.id)).toList();
    });
  }

  @override
  Future<CameraScopePolicy> getCameraScope(String storeId) async {
    final doc = await _cameraScopeRef(storeId).get();
    if (!doc.exists || doc.data() == null) {
      // Seed free default so superadmin can edit later.
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
