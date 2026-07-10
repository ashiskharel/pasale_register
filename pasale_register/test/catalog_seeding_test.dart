import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasale_register/models/product.dart';
import 'package:pasale_register/services/firestore_service.dart';
import 'package:pasale_register/services/service_locator.dart';
import 'package:pasale_register/services/fakes/fake_firestore_service.dart';

// Helper to validate EAN-13 barcodes
bool isValidEan13(String barcode) {
  if (barcode.length != 13) return false;
  if (int.tryParse(barcode) == null) return false;

  int oddSum = 0;
  int evenSum = 0;
  for (int i = 0; i < 12; i++) {
    int digit = int.parse(barcode[i]);
    if (i % 2 == 0) {
      oddSum += digit; // 0-based indices 0, 2, 4... correspond to odd positions 1, 3, 5...
    } else {
      evenSum += digit; // 0-based indices 1, 3, 5... correspond to even positions 2, 4, 6...
    }
  }
  int totalSum = oddSum + 3 * evenSum;
  int checksum = (10 - (totalSum % 10)) % 10;
  return barcode[12] == checksum.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String mockJsonContent = '''
  [
    {
      "id": "9772785855724",
      "name": "Bhatbhateni Premium Basmati Rice 5kg",
      "barcode": "9772785855724",
      "sellingPrice": 1150.0,
      "costPrice": 1000.0,
      "markup": 15.0
    },
    {
      "id": "9771209683622",
      "name": "Daraz Brand Premium Green Tea",
      "barcode": "9771209683622",
      "sellingPrice": 575.0,
      "costPrice": 500.0,
      "markup": 15.0
    }
  ]
  ''';

  setUp(() {
    // Set up mock asset handler for rootBundle
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        final String assetKey = utf8.decode(message!.buffer.asUint8List().sublist(message.offsetInBytes));
        // Note: key string might be prefixed by a length byte or be part of structured message,
        // so checking if it contains the asset path is safer.
        if (assetKey.contains('assets/seeded_products.json')) {
          return ByteData.view(Uint8List.fromList(utf8.encode(mockJsonContent)).buffer);
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      null,
    );
  });

  test('FakeFirestoreService loads seeded products and enforces invariants', () async {
    final firestore = FakeFirestoreService();

    // Verify loading
    final productsStream = firestore.streamCatalog();
    final products = await productsStream.first;

    expect(products, isNotEmpty);
    expect(products.length, 2);

    for (final product in products) {
      // 1. Nepal country code prefix 977
      expect(product.barcode.startsWith('977'), isTrue,
          reason: 'Barcode ${product.barcode} must start with Nepal prefix 977');

      // 2. Valid EAN-13 checksum
      expect(isValidEan13(product.barcode), isTrue,
          reason: 'Barcode ${product.barcode} must be a valid EAN-13 barcode');

      // 3. Pricing invariant: costPrice = sellingPrice / (1 + markup/100)
      final calculatedCostPrice = product.sellingPrice / (1.0 + product.markup / 100.0);
      expect((product.costPrice - calculatedCostPrice).abs() < 0.01, isTrue,
          reason: 'Pricing invariant check failed: cost=${product.costPrice}, calculated=$calculatedCostPrice');

      // Check reverse invariant
      final expectedSellingPrice = product.costPrice * (1.0 + product.markup / 100.0);
      expect((product.sellingPrice - expectedSellingPrice).abs() < 0.01, isTrue,
          reason: 'Reverse pricing invariant check failed');
    }

    // Verify lookup by barcode
    final rice = await firestore.getProduct('9772785855724');
    expect(rice, isNotNull);
    expect(rice!.name, 'Bhatbhateni Premium Basmati Rice 5kg');

    final tea = await firestore.getProduct('9771209683622');
    expect(tea, isNotNull);
    expect(tea!.name, 'Daraz Brand Premium Green Tea');
  });
}
