import 'package:mlkit_camera/mlkit_camera.dart';

import '../models/product.dart';

abstract class FirestoreService {
  Future<void> activateStore(String storeId, String storeName);
  Future<void> registerDevice(
    String storeId,
    String deviceId,
    Map<String, dynamic> deviceMetadata,
  );

  /// Lookup by barcode. Prefer [storeId] catalog (per-store pricing).
  Future<Product?> getProduct(String id, {String? storeId});

  /// Save product under its [Product.storeId] when set, else optional [storeId].
  Future<void> saveProduct(Product product, {String? storeId});

  /// Stream catalog for a store (or shared/global if [storeId] is null).
  Stream<List<Product>> streamCatalog({String? storeId});

  /// Superadmin camera scope for a store (`stores/{id}/settings/cameraScope`).
  Future<CameraScopePolicy> getCameraScope(String storeId);

  /// Persist camera scope (superadmin).
  Future<void> saveCameraScope(String storeId, CameraScopePolicy policy);
}
