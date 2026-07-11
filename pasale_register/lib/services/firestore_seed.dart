import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';

/// Seeds the global `products` collection from [assets/seeded_products.json]
/// when empty (bootstrap for a new Firebase project).
Future<void> seedGlobalProductsIfEmpty(FirebaseFirestore firestore) async {
  try {
    final existing = await firestore.collection('products').limit(1).get();
    if (existing.docs.isNotEmpty) {
      debugPrint('seedGlobalProducts: already has data');
      return;
    }

    final jsonString =
        await rootBundle.loadString('assets/seeded_products.json');
    final List<dynamic> data = json.decode(jsonString) as List<dynamic>;

    var batch = firestore.batch();
    var ops = 0;
    var total = 0;

    Future<void> flush() async {
      if (ops == 0) return;
      await batch.commit();
      batch = firestore.batch();
      ops = 0;
    }

    for (final item in data) {
      final map = Map<String, dynamic>.from(item as Map);
      final id = map['id'] as String? ?? map['barcode'] as String?;
      if (id == null || id.isEmpty) continue;
      final product = Product.fromMap(map, id);
      batch.set(
        firestore.collection('products').doc(id),
        {
          ...product.toMap(),
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      ops++;
      total++;
      if (ops >= 400) await flush();
    }
    await flush();
    debugPrint('seedGlobalProducts: wrote $total products');
  } catch (e, st) {
    debugPrint('seedGlobalProducts failed: $e\n$st');
  }
}
