import '../models/product.dart';
import 'firestore_service.dart';
import 'service_locator.dart';

class CatalogTemplateService {
  static Future<void> cloneTemplate({
    required String storeId,
    String? businessId,
    required String storeType,
  }) async {
    final products = _getTemplates(storeType, storeId);
    if (products.isEmpty) return;

    final firestore = locator<FirestoreService>();
    
    // In a real app, this might be a batch write to Firestore.
    // For now, we save them sequentially or concurrently.
    await Future.wait(
      products.map((p) async {
        final existing = await firestore.getProduct(p.id, storeId: storeId, businessId: businessId);
        if (existing == null) {
          await firestore.saveProduct(
            p,
            storeId: storeId,
            businessId: businessId,
            syncToBusiness: true,
          );
        }
      }),
    );
  }

  static List<Product> _getTemplates(String storeType, String storeId) {
    switch (storeType) {
      case 'Grocery / Kirana':
        return [
          _p(storeId, 'Rice (Jeera Masino)', 'barcode_rice', 2000, 1800),
          _p(storeId, 'Dal (Lentils)', 'barcode_dal', 150, 130),
          _p(storeId, 'Cooking Oil (Sunflower)', 'barcode_oil', 300, 270),
          _p(storeId, 'Salt (Iodized)', 'barcode_salt', 25, 20),
          _p(storeId, 'Sugar', 'barcode_sugar', 100, 90),
          _p(storeId, 'Tea Leaves', 'barcode_tea', 250, 200),
        ];
      case 'Pharmacy':
        return [
          _p(storeId, 'Paracetamol 500mg', 'barcode_para', 20, 10),
          _p(storeId, 'Ibuprofen 400mg', 'barcode_ibu', 30, 15),
          _p(storeId, 'Cough Syrup', 'barcode_cough', 120, 80),
          _p(storeId, 'Band-Aid', 'barcode_bandaid', 5, 2),
          _p(storeId, 'Antiseptic Cream', 'barcode_anti', 60, 40),
        ];
      case 'Hair Salon':
        return [
          _p(storeId, 'Men Haircut', 'sku_haircut_m', 200, 0),
          _p(storeId, 'Women Haircut', 'sku_haircut_w', 500, 0),
          _p(storeId, 'Hair Color', 'sku_color', 1500, 500),
          _p(storeId, 'Shave / Beard Trim', 'sku_shave', 150, 0),
          _p(storeId, 'Hair Spa', 'sku_spa', 2000, 500),
        ];
      case 'Momo Shop':
        return [
          _p(storeId, 'Buff Momo (Steam)', 'sku_buff_stm', 150, 100),
          _p(storeId, 'Chicken Momo (Steam)', 'sku_chk_stm', 180, 120),
          _p(storeId, 'Veg Momo (Steam)', 'sku_veg_stm', 120, 80),
          _p(storeId, 'Coke (250ml)', 'sku_coke', 60, 45),
          _p(storeId, 'Chowmein (Chicken)', 'sku_chow_chk', 150, 100),
        ];
      case 'Clothing Apparel':
        return [
          _p(storeId, 'Men T-Shirt', 'sku_tshirt_m', 800, 400),
          _p(storeId, 'Women Top', 'sku_top_w', 1200, 600),
          _p(storeId, 'Jeans (Unisex)', 'sku_jeans', 2500, 1200),
          _p(storeId, 'Winter Jacket', 'sku_jacket', 4500, 2500),
          _p(storeId, 'Socks (Pair)', 'sku_socks', 150, 50),
        ];
      default:
        return [];
    }
  }

  static Product _p(String storeId, String name, String barcode,
      double sellingPrice, double costPrice) {
    return Product(
      id: barcode, // For simplicity, ID is same as barcode
      name: name,
      barcode: barcode,
      sellingPrice: sellingPrice,
      costPrice: costPrice,
      markup: sellingPrice > 0 && costPrice > 0
          ? ((sellingPrice - costPrice) / costPrice) * 100
          : 0,
      storeId: storeId,
    );
  }
}
