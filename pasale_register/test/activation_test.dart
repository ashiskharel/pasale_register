import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pasale_register/models/store.dart';
import 'package:pasale_register/models/device.dart';
import 'package:pasale_register/services/service_locator.dart';
import 'package:pasale_register/constants/keys.dart';
import 'package:pasale_register/main.dart';

void main() {
  setUp(() {
    setupLocator(useFakes: true);
  });

  group('Store and Device Models Tests', () {
    test('Store serialization & deserialization', () {
      final now = DateTime.now();
      final store = Store(
        storeId: 'store_123',
        name: 'Super Pasale',
        activationDate: now,
      );

      final map = store.toMap();
      expect(map['storeId'], 'store_123');
      expect(map['name'], 'Super Pasale');
      expect(map['activationDate'], now.toIso8601String());

      final deserialized = Store.fromMap(map, 'store_123');
      expect(deserialized.storeId, 'store_123');
      expect(deserialized.name, 'Super Pasale');
      expect(deserialized.activationDate.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });

    test('Device serialization & deserialization', () {
      final now = DateTime.now();
      final device = Device(
        deviceId: 'device_abc',
        model: 'Pixel 6',
        osVersion: 'Android 13',
        lastActive: now,
      );

      final map = device.toMap();
      expect(map['deviceId'], 'device_abc');
      expect(map['model'], 'Pixel 6');
      expect(map['osVersion'], 'Android 13');
      expect(map['lastActive'], now.toIso8601String());

      final deserialized = Device.fromMap(map, 'device_abc');
      expect(deserialized.deviceId, 'device_abc');
      expect(deserialized.model, 'Pixel 6');
      expect(deserialized.osVersion, 'Android 13');
      expect(deserialized.lastActive.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });
  });

  group('SharedPreferences and Activation Screen UI & Navigation Tests', () {
    testWidgets('Unactivated startup displays Activation screen and blocks other screens', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.storeIdInput), findsOneWidget);
      expect(find.byKey(AppKeys.storeNameInput), findsOneWidget);
      expect(find.byKey(AppKeys.activateStoreButton), findsOneWidget);

      expect(find.byKey(AppKeys.navToCatalog), findsOneWidget);
      expect(find.byKey(AppKeys.navToCheckout), findsOneWidget);
      expect(find.byKey(AppKeys.navToInvoiceIngestor), findsOneWidget);

      // Verify clicking Catalog does NOT navigate away (blocked since not activated)
      await tester.tap(find.byKey(AppKeys.navToCatalog));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.storeIdInput), findsOneWidget);
    });

    testWidgets('Activated startup bypasses Activation screen and shows Catalog screen', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'storeId': 'store_ok',
        'deviceId': 'device_ok',
        'isActivated': true,
      });

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.storeIdInput), findsNothing);
      expect(find.byKey(AppKeys.productSearchInput), findsOneWidget);
    });

    testWidgets('Activation flow successful - saves to SharedPreferences and redirects to Catalog', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.storeIdInput), 'mystore123');
      await tester.enterText(find.byKey(AppKeys.storeNameInput), 'My Awesome Store');
      await tester.enterText(find.byKey(AppKeys.deviceIdInput), 'mydevice123');
      
      await tester.tap(find.byKey(AppKeys.activateStoreButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('storeId'), 'mystore123');
      expect(prefs.getBool('isActivated'), true);
      expect(prefs.getString('deviceId'), 'mydevice123');

      expect(find.byKey(AppKeys.productSearchInput), findsOneWidget);
      expect(find.byKey(AppKeys.storeIdInput), findsNothing);
    });
  });
}
