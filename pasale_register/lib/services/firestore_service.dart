import 'package:mlkit_camera/mlkit_camera.dart';

import '../models/product.dart';

abstract class FirestoreService {
  Future<void> activateStore(String storeId, String storeName);
  Future<void> registerDevice(
    String storeId,
    String deviceId,
    Map<String, dynamic> deviceMetadata,
  );
  Future<Product?> getProduct(String id);
  Future<void> saveProduct(Product product);
  Stream<List<Product>> streamCatalog();

  /// Superadmin camera scope for a store (`stores/{id}/settings/cameraScope`).
  Future<CameraScopePolicy> getCameraScope(String storeId);

  /// Persist camera scope (superadmin).
  Future<void> saveCameraScope(String storeId, CameraScopePolicy policy);
}
