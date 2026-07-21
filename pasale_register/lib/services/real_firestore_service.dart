import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mlkit_camera/mlkit_camera.dart';

import '../models/device.dart';
import '../models/product.dart';
import '../models/store.dart';
import '../models/store_customer.dart';
import '../models/store_deposit.dart';
import '../models/store_invoice.dart';
import '../models/vendor.dart';
import '../models/vendor_invoice.dart';
import '../models/inventory_log.dart';
import 'firestore_seed.dart';
import 'firestore_service.dart';

/// Production Firestore access. Paths and fields match [docs/FIRESTORE_SCHEMA.md].
class RealFirestoreService implements FirestoreService {
  RealFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  Future<void>? _seedFuture;

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

  Future<void> _ensureSeeded() {
    return _seedFuture ??= seedGlobalProductsIfEmpty(_firestore);
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

  String _businessIdForUid(String uid) => 'biz_$uid';

  /// Local demo uids (`demo_phone_*` / `fb_demo_*`) had no Firebase Auth session.
  /// After rebinding to anonymous Auth we may reclaim those stores.
  bool _isSyntheticDemoUid(String? uid) {
    if (uid == null || uid.isEmpty) return true;
    return uid.startsWith('demo_phone_') || uid.startsWith('fb_demo_');
  }

  @override
  Future<MembershipProfile> ensureMembershipProfile({
    required String uid,
    String? phone,
    String? displayName,
    String? email,
    String? authProvider,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final userSnap = await userRef.get();
    final userData = userSnap.data() ?? {};

    var businessIds = List<String>.from(
      (userData['businessIds'] as List?)?.map((e) => '$e') ?? const [],
    );
    String businessId;
    if (businessIds.isEmpty) {
      businessId = _businessIdForUid(uid);
      businessIds = [businessId];
      final bizRef = _firestore.collection('businesses').doc(businessId);
      await bizRef.set(
        _withServerTimes(
          {
            'businessId': businessId,
            'ownerUid': uid,
            if (phone != null && phone.isNotEmpty) 'primaryPhone': phone,
            'name': (displayName != null && displayName.isNotEmpty)
                ? displayName
                : (phone ?? 'My business'),
            'storeIds': <String>[],
          },
          isCreate: true,
        ),
        SetOptions(merge: true),
      );
      // Owner member doc
      await bizRef.collection('members').doc(uid).set(
        {
          'uid': uid,
          'role': 'owner',
          'storeIds': <String>['*'],
          if (phone != null) 'phone': phone,
          if (displayName != null) 'displayName': displayName,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } else {
      businessId = businessIds.first;
    }

    await userRef.set(
      _withServerTimes(
        {
          'uid': uid,
          if (phone != null && phone.isNotEmpty) 'primaryPhone': phone,
          if (displayName != null && displayName.isNotEmpty)
            'displayName': displayName,
          if (email != null && email.isNotEmpty) 'email': email,
          if (authProvider != null) 'authProvider': authProvider,
          'businessIds': businessIds,
        },
        isCreate: !userSnap.exists,
      ),
      SetOptions(merge: true),
    );

    final bizSnap =
        await _firestore.collection('businesses').doc(businessId).get();
    final storeIds = List<String>.from(
      (bizSnap.data()?['storeIds'] as List?)?.map((e) => '$e') ?? const [],
    );
    final defaultStoreId = userData['defaultStoreId'] as String? ??
        (storeIds.isNotEmpty ? storeIds.first : null);

    return MembershipProfile(
      uid: uid,
      businessId: businessId,
      defaultStoreId: defaultStoreId,
      storeIds: storeIds,
    );
  }

  @override
  Future<void> activateStore(
    String storeId,
    String storeName, {
    required String ownerUid,
    String? businessId,
    String? ownerPhone,
  }) async {
    await _ensureSeeded();

    var bid = businessId;
    if (bid == null || bid.isEmpty) {
      final profile = await ensureMembershipProfile(
        uid: ownerUid,
        phone: ownerPhone,
        displayName: storeName,
      );
      bid = profile.businessId;
    }

    final store = Store(
      storeId: storeId,
      name: storeName,
      activationDate: DateTime.now().toUtc(),
    );
    final ref = _firestore.collection('stores').doc(storeId);
    // Probe existence. Older rules denied get on missing docs → permission-denied.
    var storeExists = false;
    Map<String, dynamic>? existingData;
    try {
      final existing = await ref.get();
      storeExists = existing.exists;
      existingData = existing.data();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Treat as missing / not readable; create or claim will enforce ownership.
        storeExists = false;
        existingData = null;
      } else {
        rethrow;
      }
    }
    if (storeExists) {
      final existingOwner = existingData?['ownerUid'] as String?;
      if (existingOwner != null &&
          existingOwner.isNotEmpty &&
          existingOwner != ownerUid &&
          !_isSyntheticDemoUid(existingOwner)) {
        throw StateError(
          'Store ID "$storeId" is already owned by another account.',
        );
      }
    }

    final reclaimDemo = storeExists &&
        _isSyntheticDemoUid(existingData?['ownerUid'] as String?);
    final payload = _withServerTimes(
      {
        ...store.toMap(),
        'isActive': true,
        'currency': 'NPR',
        'planTier': 'free',
        'businessId': bid,
        'ownerUid': ownerUid,
        // Always write a concrete list so create rules see `uid in memberUids`
        // (FieldValue.arrayUnion alone is not a list under security rules).
        'memberUids': [ownerUid],
        'catalogMode': 'shared',
        if (ownerPhone != null && ownerPhone.isNotEmpty)
          'ownerPhone': ownerPhone,
      },
      isCreate: !storeExists,
    );
    // Preserve co-members on update unless reclaiming a synthetic demo owner.
    if (storeExists && !reclaimDemo) {
      payload['memberUids'] = FieldValue.arrayUnion([ownerUid]);
    }
    await ref.set(payload, SetOptions(merge: true));

    final bizRef = _firestore.collection('businesses').doc(bid);
    await bizRef.set(
      _withServerTimes(
        {
          'businessId': bid,
          'ownerUid': ownerUid,
          'storeIds': FieldValue.arrayUnion([storeId]),
          if (ownerPhone != null && ownerPhone.isNotEmpty)
            'primaryPhone': ownerPhone,
        },
        isCreate: false,
      ),
      SetOptions(merge: true),
    );
    await bizRef.collection('members').doc(ownerUid).set(
      {
        'uid': ownerUid,
        'role': 'owner',
        'storeIds': FieldValue.arrayUnion([storeId, '*']),
        if (ownerPhone != null) 'phone': ownerPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await _firestore.collection('users').doc(ownerUid).set(
          _withServerTimes(
            {
              'uid': ownerUid,
              'businessIds': FieldValue.arrayUnion([bid]),
              'defaultStoreId': storeId,
              if (ownerPhone != null && ownerPhone.isNotEmpty)
                'primaryPhone': ownerPhone,
            },
            isCreate: false,
          ),
          SetOptions(merge: true),
        );

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
  Future<List<Map<String, dynamic>>> listMemberStores({
    required String uid,
  }) async {
    // Prefer membership via ownerUid / memberUids (denormalized).
    final byOwner = await _firestore
        .collection('stores')
        .where('ownerUid', isEqualTo: uid)
        .get();
    final byMember = await _firestore
        .collection('stores')
        .where('memberUids', arrayContains: uid)
        .get();
    final map = <String, Map<String, dynamic>>{};
    for (final d in [...byOwner.docs, ...byMember.docs]) {
      map[d.id] = {...d.data(), 'storeId': d.id};
    }
    return map.values.toList();
  }

  @override
  Future<String> getOrGeneratePasscode(String storeId) async {
    final ref = _firestore.collection('stores').doc(storeId);
    final doc = await ref.get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('passcode')) {
        return data['passcode'] as String;
      }
    }
    // Generate a new 6-digit passcode securely
    final random = Random.secure();
    final code = (100000 + random.nextInt(900000)).toString();
    await ref.set({'passcode': code}, SetOptions(merge: true));
    return code;
  }

  @override
  Future<void> joinStore({
    required String storeId,
    required String passcode,
    required String uid,
    String? phone,
    String? displayName,
  }) async {
    final ref = _firestore.collection('stores').doc(storeId);

    // Ensure membership profile exists
    final profile = await ensureMembershipProfile(
      uid: uid,
      phone: phone,
      displayName: displayName,
    );

    // Add to members list securely (the rules allow update if passcode matches)
    try {
      await ref.update({
        'memberUids': FieldValue.arrayUnion([uid]),
        'passcode': passcode,
      });
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw Exception('Invalid passcode or store not found');
      }
      rethrow;
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

  CollectionReference<Map<String, dynamic>> _businessCatalogCol(
    String businessId,
  ) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('catalog');
  }

  @override
  Future<void> healStoreMembership({
    required String storeId,
    required String ownerUid,
    String? businessId,
    String? ownerPhone,
    String? storeName,
  }) async {
    final profile = await ensureMembershipProfile(
      uid: ownerUid,
      phone: ownerPhone,
      displayName: storeName,
    );
    final bid = (businessId != null && businessId.isNotEmpty)
        ? businessId
        : profile.businessId;

    final ref = _firestore.collection('stores').doc(storeId);
    var storeExists = false;
    Map<String, dynamic> data = {};
    try {
      final existing = await ref.get();
      storeExists = existing.exists;
      data = existing.data() ?? {};
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      // Missing or unreadable under old rules — attempt claim write below.
    }
    final existingOwner = data['ownerUid'] as String?;
    if (storeExists &&
        existingOwner != null &&
        existingOwner.isNotEmpty &&
        existingOwner != ownerUid &&
        !_isSyntheticDemoUid(existingOwner)) {
      // Already owned by a real account — cannot claim.
      return;
    }

    final name = (storeName != null && storeName.isNotEmpty)
        ? storeName
        : (data['name'] as String? ?? storeId);

    await ref.set(
      _withServerTimes(
        {
          'storeId': storeId,
          'name': name,
          'businessId': bid,
          'ownerUid': ownerUid,
          'memberUids': [ownerUid],
          'catalogMode': data['catalogMode'] ?? 'shared',
          'isActive': true,
          if (ownerPhone != null && ownerPhone.isNotEmpty)
            'ownerPhone': ownerPhone,
          if (!storeExists)
            'activationDate': DateTime.now().toUtc().toIso8601String(),
        },
        isCreate: !storeExists,
      ),
      SetOptions(merge: true),
    );

    await _firestore.collection('businesses').doc(bid).set(
      {
        'businessId': bid,
        'ownerUid': ownerUid,
        'storeIds': FieldValue.arrayUnion([storeId]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await _firestore.collection('users').doc(ownerUid).set(
      {
        'defaultStoreId': storeId,
        'businessIds': FieldValue.arrayUnion([bid]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> createBranchStore({
    required String storeId,
    required String storeName,
    required String ownerUid,
    required String businessId,
    String? ownerPhone,
  }) async {
    await activateStore(
      storeId,
      storeName,
      ownerUid: ownerUid,
      businessId: businessId,
      ownerPhone: ownerPhone,
    );

    // Copy master business catalog into the new branch as starting products.
    try {
      final master = await _businessCatalogCol(businessId).get();
      for (final doc in master.docs) {
        if (doc.data()['isActive'] == false) continue;
        final p = Product.fromMap(doc.data(), doc.id);
        await saveProduct(
          p.copyWith(storeId: storeId),
          storeId: storeId,
          businessId: businessId,
          syncToBusiness: false,
        );
      }
    } catch (e) {
      debugPrint('createBranchStore catalog seed: $e');
    }
  }

  @override
  Future<Product?> getProduct(
    String id, {
    String? storeId,
    String? businessId,
  }) async {
    await _ensureSeeded();
    if (storeId != null && storeId.isNotEmpty) {
      final storeDoc = await _productsCol(storeId).doc(id).get();
      if (storeDoc.exists && storeDoc.data() != null) {
        return Product.fromMap(storeDoc.data()!, storeDoc.id);
      }
    }
    if (businessId != null && businessId.isNotEmpty) {
      final bizDoc = await _businessCatalogCol(businessId).doc(id).get();
      if (bizDoc.exists && bizDoc.data() != null) {
        final p = Product.fromMap(bizDoc.data()!, bizDoc.id);
        return storeId != null ? p.copyWith(storeId: storeId) : p;
      }
    }
    final global = await _firestore.collection('products').doc(id).get();
    if (!global.exists || global.data() == null) return null;
    return Product.fromMap(global.data()!, global.id);
  }

  @override
  Future<void> saveProduct(
    Product product, {
    String? storeId,
    String? businessId,
    bool syncToBusiness = true,
  }) async {
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
        'imageUrl': toSave.imagePath != null &&
                (toSave.imagePath!.startsWith('http://') ||
                    toSave.imagePath!.startsWith('https://'))
            ? toSave.imagePath
            : null,
      },
      isCreate: !existing.exists,
    );
    if (payload['imageUrl'] == null) {
      payload.remove('imageUrl');
    }

    // Await to ensure we catch permission errors, offline will still resolve quickly
    await ref.set(payload, SetOptions(merge: true));

    // Shared master catalog for multi-branch sync.
    if (syncToBusiness && businessId != null && businessId.isNotEmpty) {
      final masterRef = _businessCatalogCol(businessId).doc(toSave.id);
      final masterExisting = await masterRef.get();
      final masterPayload = _withServerTimes(
        {
          ...toSave.toMap(),
          'storeId': null,
          'businessId': businessId,
          'isActive': true,
        },
        isCreate: !masterExisting.exists,
      );
      masterPayload.remove('storeId');
      await masterRef.set(masterPayload, SetOptions(merge: true));
    }
  }

  @override
  Stream<List<Product>> streamCatalog({
    String? storeId,
    String? businessId,
  }) {
    _ensureSeeded();

    if (storeId == null || storeId.isEmpty) {
      return _productsCol(null).snapshots().map((snapshot) {
        return snapshot.docs
            .where((doc) => doc.data()['isActive'] != false)
            .map((doc) => Product.fromMap(doc.data(), doc.id))
            .toList();
      });
    }

    final globalCache = <String, Product>{};
    final masterCache = <String, Product>{};
    bool _isCached = false;

    // Store products stream; each emission re-merges business master + global seed.
    return _productsCol(storeId).snapshots().asyncMap((storeSnap) async {
      await _ensureSeeded();
      
      if (!_isCached) {
        // 1) Global seed
        try {
          final globalSnap = await _firestore.collection('products').get();
          for (final doc in globalSnap.docs) {
            if (doc.data()['isActive'] == false) continue;
            globalCache[doc.id] = Product.fromMap(doc.data(), doc.id);
          }
        } catch (_) {}

        // 2) Business master catalog (shared across branches)
        if (businessId != null && businessId.isNotEmpty) {
          try {
            final masterSnap = await _businessCatalogCol(businessId).get();
            for (final doc in masterSnap.docs) {
              if (doc.data()['isActive'] == false) continue;
              final p = Product.fromMap(doc.data(), doc.id);
              masterCache[doc.id] = p.copyWith(storeId: storeId);
            }
          } catch (_) {}
        }
        _isCached = true;
      }

      final byId = <String, Product>{};
      byId.addAll(globalCache);
      byId.addAll(masterCache);

      // 3) Store-level products (price overrides win)
      for (final doc in storeSnap.docs) {
        if (doc.data()['isActive'] == false) continue;
        byId[doc.id] = Product.fromMap(doc.data(), doc.id);
      }

      final list = byId.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Map<String, dynamic> _normalizeJsonTimestamps(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    for (final key in [
      'updatedAt',
      'createdAt',
      'activationDate',
      'lastActive',
    ]) {
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
    var policy = CameraScopePolicy.fromJson(
      _normalizeJsonTimestamps(doc.data()!),
    );
    // Migrate barcode-only free scopes created before price-tag OCR.
    if (!policy.allows(CameraCapability.textOcr)) {
      policy = policy.withCapability(
        CameraCapability.textOcr,
        enabled: true,
        updatedBy: 'system-migrate-ocr',
      );
      try {
        await saveCameraScope(storeId, policy);
      } catch (_) {
        // Apply upgraded policy even if persist fails.
      }
    }
    return policy;
  }

  @override
  Future<void> saveCameraScope(String storeId, CameraScopePolicy policy) async {
    final data = policy.toJson();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _cameraScopeRef(storeId).set(data, SetOptions(merge: true));
  }

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
    // Fire and forget for offline support
    ref.set({
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

  CollectionReference<Map<String, dynamic>> _invoicesCol(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('invoices');

  CollectionReference<Map<String, dynamic>> _depositsCol(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('deposits');

  CollectionReference<Map<String, dynamic>> _customersCol(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('customers');

  @override
  Future<void> saveInvoice(
    StoreInvoice invoice, {
    required String storeId,
  }) async {
    final id = invoice.id.isNotEmpty
        ? invoice.id
        : 'INV_${DateTime.now().millisecondsSinceEpoch}';

    final invRef = _invoicesCol(storeId).doc(id);
    final existingInvSnap = await invRef.get();
    double oldCreditContribution = 0;
    bool isNewTransaction = !existingInvSnap.exists;
    if (!isNewTransaction) {
      final oldData = existingInvSnap.data()!;
      oldData['id'] = existingInvSnap.id;
      final oldInvoice = StoreInvoice.fromMap(oldData);
      if (oldInvoice.isCredit && !oldInvoice.isVoided) {
        oldCreditContribution = oldInvoice.total;
      }
    }

    final data = invoice.toMap();
    data['id'] = id;
    data['storeId'] = storeId;
    data['createdAt'] = invoice.createdAt.toUtc().toIso8601String();
    data['updatedAt'] = FieldValue.serverTimestamp();
    // Also keep a Timestamp field for range queries.
    data['createdAtTs'] = Timestamp.fromDate(invoice.createdAt.toUtc());

    // Fire and forget for offline support
    invRef.set(data, SetOptions(merge: true));

    // Mirror into sales/ for older schema consumers.
    try {
      await saveSale(
        storeId: storeId,
        saleId: id,
        totalPrice: invoice.total,
        isPaid: invoice.isCash,
        items: (invoice.lineSummary ?? []).map((l) => {'line': l}).toList(),
        customerPhone: invoice.customerPhone,
      );
    } catch (_) {}

    final phone = invoice.customerPhone?.trim();
    if (phone != null && phone.isNotEmpty) {
      final ref = _customersCol(storeId).doc(phone);
      final existing = await ref.get();
      final prev = existing.data();
      final prevCredit = (prev?['creditBalance'] as num?)?.toDouble() ?? 0;
      final prevCount = prev?['transactionCount'] as int? ?? 0;
      final name = (invoice.customerName?.trim().isNotEmpty == true)
          ? invoice.customerName!.trim()
          : (prev?['name'] as String? ?? phone);
      double newCreditContribution =
          (invoice.isCredit && !invoice.isVoided) ? invoice.total : 0;
      double delta = newCreditContribution - oldCreditContribution;

      // Fire and forget for offline support
      ref.set(
        {
          'phone': phone,
          'name': name,
          if (invoice.customerEmail != null &&
              invoice.customerEmail!.trim().isNotEmpty)
            'email': invoice.customerEmail!.trim(),
          'creditBalance': FieldValue.increment(delta),
          'lastActivityAt': invoice.createdAt.toUtc().toIso8601String(),
          'lastActivityAtTs': Timestamp.fromDate(invoice.createdAt.toUtc()),
          'transactionCount': FieldValue.increment(isNewTransaction ? 1 : 0),
          'updatedAt': FieldValue.serverTimestamp(),
          if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  StoreInvoice _invoiceFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = Map<String, dynamic>.from(doc.data());
    data['isPendingSync'] = doc.metadata.hasPendingWrites;
    final ts = data['createdAtTs'];
    if (ts is Timestamp) {
      data['createdAt'] = ts.toDate().toUtc().toIso8601String();
    }
    data['id'] = data['id'] ?? doc.id;
    return StoreInvoice.fromMap(data);
  }

  @override
  Stream<List<StoreInvoice>> streamInvoices({required String storeId}) {
    return _invoicesCol(storeId)
        .orderBy('createdAtTs', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) => snap.docs.map(_invoiceFromDoc).toList());
  }

  @override
  Future<List<StoreInvoice>> fetchInvoices({required String storeId}) async {
    try {
      final snap = await _invoicesCol(storeId)
          .orderBy('createdAtTs', descending: true)
          .get();
      return snap.docs.map(_invoiceFromDoc).toList();
    } catch (_) {
      // Fallback without composite index / missing field.
      final snap = await _invoicesCol(storeId).get();
      final list = snap.docs.map(_invoiceFromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
  }

  @override
  Future<void> saveDeposit(
    StoreDeposit deposit, {
    required String storeId,
  }) async {
    final id = deposit.id.isNotEmpty
        ? deposit.id
        : 'DEP_${DateTime.now().millisecondsSinceEpoch}';

    final depRef = _depositsCol(storeId).doc(id);
    final existingDepSnap = await depRef.get();
    double oldCreditContribution = 0;
    bool isNewTransaction = !existingDepSnap.exists;
    if (!isNewTransaction) {
      final oldData = existingDepSnap.data()!;
      oldData['id'] = existingDepSnap.id;
      final oldDeposit = StoreDeposit.fromMap(oldData);
      if (!oldDeposit.isVoided) {
        oldCreditContribution = oldDeposit.amount;
      }
    }

    final data = deposit.toMap();
    data['id'] = id;
    data['storeId'] = storeId;
    data['createdAt'] = deposit.createdAt.toUtc().toIso8601String();
    data['updatedAt'] = FieldValue.serverTimestamp();
    // Also keep a Timestamp field for range queries.
    data['createdAtTs'] = Timestamp.fromDate(deposit.createdAt.toUtc());

    // Fire and forget for offline support
    depRef.set(data, SetOptions(merge: true));

    final phone = deposit.customerPhone.trim();
    if (phone.isNotEmpty) {
      final ref = _customersCol(storeId).doc(phone);
      final existing = await ref.get();
      final prev = existing.data();
      final prevCredit = (prev?['creditBalance'] as num?)?.toDouble() ?? 0;
      final prevCount = prev?['transactionCount'] as int? ?? 0;
      final name = (deposit.customerName?.trim().isNotEmpty == true)
          ? deposit.customerName!.trim()
          : (prev?['name'] as String? ?? phone);
      double newCreditContribution = deposit.isVoided ? 0 : deposit.amount;
      double delta = newCreditContribution - oldCreditContribution;

      // Fire and forget for offline support
      ref.set(
        {
          'phone': phone,
          'name': name,
          'creditBalance': FieldValue.increment(-delta),
          'lastActivityAt': deposit.createdAt.toUtc().toIso8601String(),
          'lastActivityAtTs': Timestamp.fromDate(deposit.createdAt.toUtc()),
          'transactionCount': FieldValue.increment(isNewTransaction ? 1 : 0),
          'updatedAt': FieldValue.serverTimestamp(),
          if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  StoreDeposit _depositFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = Map<String, dynamic>.from(doc.data());
    data['isPendingSync'] = doc.metadata.hasPendingWrites;
    final ts = data['createdAtTs'];
    if (ts is Timestamp) {
      data['createdAt'] = ts.toDate().toUtc().toIso8601String();
    }
    data['id'] = data['id'] ?? doc.id;
    return StoreDeposit.fromMap(data);
  }

  @override
  Stream<List<StoreDeposit>> streamDeposits({required String storeId}) {
    return _depositsCol(storeId)
        .orderBy('createdAtTs', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) => snap.docs.map(_depositFromDoc).toList());
  }

  @override
  Future<List<StoreDeposit>> fetchDeposits({required String storeId}) async {
    try {
      final snap = await _depositsCol(storeId)
          .orderBy('createdAtTs', descending: true)
          .get();
      return snap.docs.map(_depositFromDoc).toList();
    } catch (_) {
      final snap = await _depositsCol(storeId).get();
      final list = snap.docs.map(_depositFromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
  }

  @override
  Future<void> upsertCustomer(
    StoreCustomer customer, {
    required String storeId,
  }) async {
    await _customersCol(storeId).doc(customer.phone).set(
      {
        ...customer.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Stream<List<StoreCustomer>> streamCustomers({required String storeId}) {
    return _customersCol(storeId).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => StoreCustomer.fromMap({...d.data(), 'phone': d.id}))
          .toList()
        ..sort((a, b) {
          final aa = a.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bb = b.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bb.compareTo(aa);
        });
      return list;
    });
  }

  @override
  Future<List<StoreCustomer>> fetchCustomers({required String storeId}) async {
    final snap = await _customersCol(storeId).get();
    final list = snap.docs
        .map((d) => StoreCustomer.fromMap({...d.data(), 'phone': d.id}))
        .toList()
      ..sort((a, b) {
        final aa = a.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bb = b.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bb.compareTo(aa);
      });
    return list;
  }

  CollectionReference<Map<String, dynamic>> _vendorsCol(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('vendors');

  @override
  Future<void> saveVendor(Vendor vendor, {required String storeId}) async {
    final id = vendor.id.isNotEmpty
        ? vendor.id
        : 'VEND_${DateTime.now().millisecondsSinceEpoch}';
    final ref = _vendorsCol(storeId).doc(id);
    final data = vendor.toMap();
    data['id'] = id;
    data['storeId'] = storeId;
    data['updatedAt'] = FieldValue.serverTimestamp();
    await ref.set(data, SetOptions(merge: true));
  }

  @override
  Stream<List<Vendor>> streamVendors({required String storeId}) {
    return _vendorsCol(storeId).snapshots().map((snap) {
      return snap.docs
          .map((doc) => Vendor.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<List<Vendor>> fetchVendors({required String storeId}) async {
    final snap = await _vendorsCol(storeId).get();
    return snap.docs.map((doc) => Vendor.fromMap(doc.data(), doc.id)).toList();
  }

  CollectionReference<Map<String, dynamic>> _inventoryLogsCol(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('inventory_logs');

  @override
  Future<void> saveInventoryLog(InventoryLog log,
      {required String storeId}) async {
    final id = log.id.isNotEmpty
        ? log.id
        : 'INVLOG_${DateTime.now().millisecondsSinceEpoch}';
    final ref = _inventoryLogsCol(storeId).doc(id);
    final data = log.toMap();
    data['id'] = id;
    data['storeId'] = storeId;
    await ref.set(data, SetOptions(merge: true));
  }

  @override
  Stream<List<InventoryLog>> streamInventoryLogs({required String storeId}) {
    return _inventoryLogsCol(storeId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => InventoryLog.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Future<List<InventoryLog>> fetchInventoryLogs(
      {required String storeId}) async {
    final snap = await _inventoryLogsCol(storeId)
        .orderBy('timestamp', descending: true)
        .get();
    return snap.docs
        .map((doc) => InventoryLog.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Stream<List<Map<String, dynamic>>> streamStoresForVendor(
      {required String vendorPhone}) {
    // Collection group query to find all 'vendors' subcollections where salespersonPhones contains the vendorPhone
    return _firestore
        .collectionGroup('vendors')
        .where('salespersonPhones', arrayContains: vendorPhone)
        .snapshots()
        .asyncMap((snap) async {
      final storeIds = snap.docs
          .map((d) => d.data()['storeId'] as String?)
          .whereType<String>()
          .toSet();
      final stores = <Map<String, dynamic>>[];
      for (final storeId in storeIds) {
        final storeDoc =
            await _firestore.collection('stores').doc(storeId).get();
        if (storeDoc.exists && storeDoc.data() != null) {
          stores.add({...storeDoc.data()!, 'storeId': storeDoc.id});
        }
      }
      return stores;
    });
  }

  CollectionReference<Map<String, dynamic>> _vendorInvoicesCol(
          String storeId) =>
      _firestore
          .collection('stores')
          .doc(storeId)
          .collection('vendor_invoices');

  @override
  Future<void> saveVendorInvoice(VendorInvoice invoice,
      {required String storeId}) async {
    final id = invoice.id.isNotEmpty
        ? invoice.id
        : 'V_INV_${DateTime.now().millisecondsSinceEpoch}';
    final ref = _vendorInvoicesCol(storeId).doc(id);
    final data = invoice.toMap();
    data['id'] = id;
    data['storeId'] = storeId;
    data['updatedAt'] = FieldValue.serverTimestamp();
    await ref.set(data, SetOptions(merge: true));
  }

  @override
  Stream<List<VendorInvoice>> streamVendorInvoices(
      {required String storeId, String? vendorUid}) {
    var query =
        _vendorInvoicesCol(storeId).orderBy('issuedAt', descending: true);
    if (vendorUid != null && vendorUid.isNotEmpty) {
      query = query.where('vendorUid', isEqualTo: vendorUid);
    }
    return query.snapshots().map((snap) {
      return snap.docs
          .map((doc) => VendorInvoice.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}
