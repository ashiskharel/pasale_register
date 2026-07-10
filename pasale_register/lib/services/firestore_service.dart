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
}
