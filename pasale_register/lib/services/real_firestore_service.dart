import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/store.dart';
import '../models/device.dart';
import 'firestore_service.dart';

class RealFirestoreService implements FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
}
