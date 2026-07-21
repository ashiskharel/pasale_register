import 'package:mlkit_camera/mlkit_camera.dart';

import '../models/product.dart';
import '../models/store_customer.dart';
import '../models/store_deposit.dart';
import '../models/store_invoice.dart';
import '../models/vendor.dart';
import '../models/vendor_invoice.dart';
import '../models/inventory_log.dart';

/// Result of ensuring user profile + default business after login.
class MembershipProfile {
  const MembershipProfile({
    required this.uid,
    required this.businessId,
    this.defaultStoreId,
    this.storeIds = const [],
  });

  final String uid;
  final String businessId;
  final String? defaultStoreId;
  final List<String> storeIds;
}

abstract class FirestoreService {
  /// Creates/updates `users/{uid}` and default `businesses/{businessId}`.
  Future<MembershipProfile> ensureMembershipProfile({
    required String uid,
    String? phone,
    String? displayName,
    String? email,
    String? authProvider,
  });

  /// Activate a substore; sets ownership + membership for [ownerUid].
  Future<void> activateStore(
    String storeId,
    String storeName, {
    required String ownerUid,
    String? businessId,
    String? ownerPhone,
  });

  Future<void> registerDevice(
    String storeId,
    String deviceId,
    Map<String, dynamic> deviceMetadata,
  );

  /// Stores the user is a member of (for switcher / restore).
  Future<List<Map<String, dynamic>>> listMemberStores({
    required String uid,
  });

  /// Generate or retrieve a passcode for the store to invite others
  Future<String> getOrGeneratePasscode(String storeId);

  /// Join a store using a passcode
  Future<void> joinStore({
    required String storeId,
    required String passcode,
    required String uid,
    String? phone,
    String? displayName,
  });

  /// Fix legacy stores missing ownerUid/memberUids (restores catalog/scanner access).
  Future<void> healStoreMembership({
    required String storeId,
    required String ownerUid,
    String? businessId,
    String? ownerPhone,
    String? storeName,
  });

  /// Create another branch under the same business (phase 2).
  Future<void> createBranchStore({
    required String storeId,
    required String storeName,
    required String ownerUid,
    required String businessId,
    String? ownerPhone,
  });

  /// Lookup by barcode. Prefer [storeId] catalog (per-store pricing).
  /// When [businessId] is set, also searches shared business catalog.
  Future<Product?> getProduct(
    String id, {
    String? storeId,
    String? businessId,
  });

  /// Save product under its [Product.storeId] when set, else optional [storeId].
  /// When [syncToBusiness] and [businessId] set, also writes master catalog.
  Future<void> saveProduct(
    Product product, {
    String? storeId,
    String? businessId,
    bool syncToBusiness = true,
  });

  /// Stream catalog for a store (or shared/global if [storeId] is null).
  /// Merges business master catalog with store products when [businessId] set.
  Stream<List<Product>> streamCatalog({
    String? storeId,
    String? businessId,
  });

  /// Superadmin camera scope for a store (`stores/{id}/settings/cameraScope`).
  Future<CameraScopePolicy> getCameraScope(String storeId);

  /// Persist camera scope (superadmin).
  Future<void> saveCameraScope(String storeId, CameraScopePolicy policy);

  /// Persist a completed invoice under `stores/{storeId}/invoices/{id}`.
  Future<void> saveInvoice(StoreInvoice invoice, {required String storeId});

  /// Live invoice history for a store (newest first when possible).
  Stream<List<StoreInvoice>> streamInvoices({required String storeId});

  /// One-shot fetch (used for offline-first merge / dashboard).
  Future<List<StoreInvoice>> fetchInvoices({required String storeId});

  /// Persist a customer deposit under `stores/{storeId}/deposits/{id}`.
  Future<void> saveDeposit(StoreDeposit deposit, {required String storeId});

  /// Live deposit history for a store.
  Stream<List<StoreDeposit>> streamDeposits({required String storeId});

  /// One-shot fetch for deposits.
  Future<List<StoreDeposit>> fetchDeposits({required String storeId});

  /// Upsert customer profile + balance under `stores/{storeId}/customers/{phone}`.
  Future<void> upsertCustomer(
    StoreCustomer customer, {
    required String storeId,
  });

  Stream<List<StoreCustomer>> streamCustomers({required String storeId});

  Future<List<StoreCustomer>> fetchCustomers({required String storeId});

  /// Persist a vendor profile under `stores/{storeId}/vendors/{id}`.
  Future<void> saveVendor(Vendor vendor, {required String storeId});

  Stream<List<Vendor>> streamVendors({required String storeId});

  Future<List<Vendor>> fetchVendors({required String storeId});

  /// Persist an inventory log under `stores/{storeId}/inventory_logs/{id}`.
  Future<void> saveInventoryLog(InventoryLog log, {required String storeId});

  Stream<List<InventoryLog>> streamInventoryLogs({required String storeId});

  Future<List<InventoryLog>> fetchInventoryLogs({required String storeId});

  /// Streams stores that a specific vendor services (where they are linked).
  Stream<List<Map<String, dynamic>>> streamStoresForVendor({required String vendorPhone});

  /// Persist a vendor invoice under `stores/{storeId}/vendor_invoices/{id}`.
  Future<void> saveVendorInvoice(VendorInvoice invoice, {required String storeId});

  /// Streams invoices sent by vendors to a specific store.
  Stream<List<VendorInvoice>> streamVendorInvoices({required String storeId, String? vendorUid});
}
