import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasale_register/constants/keys.dart';
import 'package:pasale_register/main.dart';
import 'package:pasale_register/services/cart_service.dart';
import 'package:pasale_register/services/fakes/fake_firestore_service.dart';
import 'package:pasale_register/services/firestore_service.dart';
import 'package:pasale_register/services/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'storeId': 's1',
      'deviceId': 'd1',
      'isActivated': true,
      'storeName': 'Test Store',
    });
    setupLocator(useFakes: true);
  });

  testWidgets('unknown barcode opens register dialog and adds to cart',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Go to checkout
    await tester.tap(find.byKey(AppKeys.navToCheckout));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(AppKeys.productSearchInput),
      'UNKNOWN999',
    );
    await tester.tap(find.byKey(AppKeys.addProductButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.registerUnknownProductDialog), findsOneWidget);

    await tester.enterText(
      find.byKey(AppKeys.registerProductNameInput),
      'New Snack',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(AppKeys.registerProductPriceInput),
      '50',
    );
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.registerProductSaveButton));
    await tester.pump(); // start async save
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    final cart = locator<CartService>();
    expect(cart.items.length, 1);
    expect(cart.items.first.product.name, 'New Snack');
    expect(cart.items.first.product.barcode, 'UNKNOWN999');

    final fs = locator<FirestoreService>() as FakeFirestoreService;
    final saved = await fs.getProduct('UNKNOWN999', storeId: 's1');
    expect(saved, isNotNull);
    expect(saved!.sellingPrice, 50);
    expect(saved.storeId, 's1');
  });
}
