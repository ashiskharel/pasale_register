import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasale_register/models/product.dart';
import 'package:pasale_register/services/cart_service.dart';
import 'package:pasale_register/services/service_locator.dart';
import 'package:pasale_register/services/firestore_service.dart';
import 'package:pasale_register/services/fakes/fake_firestore_service.dart';
import 'package:pasale_register/screens/checkout_screen.dart';
import 'package:pasale_register/constants/keys.dart';

void main() {
  group('Quantity Business Logic Unit Tests', () {
    late CartService cartService;
    late Product product;

    setUp(() {
      cartService = CartService();
      product = Product(
        id: '123',
        name: 'Milk',
        barcode: '123',
        sellingPrice: 50.0,
        costPrice: 40.0,
        markup: 25.0,
      );
    });

    test('Initial quantity is 1', () {
      cartService.addProduct(product);
      expect(cartService.items[0].quantity, 1);
    });

    test('Incrementing quantity works up to 999', () {
      cartService.addProduct(product);
      final success = cartService.incrementQuantity('123');
      expect(success, isTrue);
      expect(cartService.items[0].quantity, 2);
    });

    test('Incrementing quantity beyond 999 is blocked', () {
      cartService.addProduct(product);
      // Directly set quantity to 999 for test purposes
      cartService.items[0].quantity = 999;

      final success = cartService.incrementQuantity('123');
      expect(success, isFalse);
      expect(cartService.items[0].quantity, 999);
    });

    test('Decrementing quantity decrements normal quantity', () {
      cartService.addProduct(product);
      cartService.incrementQuantity('123'); // qty = 2
      cartService.decrementQuantity('123'); // qty = 1

      expect(cartService.items[0].quantity, 1);
    });

    test('Decrementing quantity from 1 removes item from cart', () {
      cartService.addProduct(product); // qty = 1
      cartService.decrementQuantity('123');

      expect(cartService.items, isEmpty);
    });
  });

  group('Quantity Widget Controls Tests', () {
    setUp(() {
      setupLocator(useFakes: true);
    });

    testWidgets('Increment and decrement button interaction in CheckoutScreen UI', (WidgetTester tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(
        id: '123',
        name: 'Milk',
        barcode: '123',
        sellingPrice: 50.0,
        costPrice: 40.0,
        markup: 25.0,
      ));

      // Build CheckoutScreen widget inside a MaterialApp
      await tester.pumpWidget(const MaterialApp(
        home: CheckoutScreen(),
      ));
      await tester.pumpAndSettle();

      // Enter manual barcode and click add
      await tester.enterText(find.byKey(AppKeys.productSearchInput), '123');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      // Verify item listed and subtotal Rs 50.0
      expect(find.text('Milk'), findsOneWidget);
      expect(find.textContaining('Cart Total: Rs. 50.00'), findsOneWidget);

      // Tap increment button
      await tester.tap(find.byKey(const ValueKey('increment_qty_123')));
      await tester.pumpAndSettle();

      // Verify subtotal Rs 100.0
      expect(find.textContaining('Cart Total: Rs. 100.00'), findsOneWidget);

      // Tap decrement button
      await tester.tap(find.byKey(const ValueKey('decrement_qty_123')));
      await tester.pumpAndSettle();

      // Verify subtotal Rs 50.0
      expect(find.textContaining('Cart Total: Rs. 50.00'), findsOneWidget);

      // Tap decrement button again (quantity becomes 0)
      await tester.tap(find.byKey(const ValueKey('decrement_qty_123')));
      await tester.pumpAndSettle();

      // Verify item is removed and total is 0.0
      expect(find.text('Milk'), findsNothing);
      expect(find.textContaining('Cart Total: Rs. 0.00'), findsOneWidget);
    });

    testWidgets('Max quantity error is shown in UI when incrementing beyond 999', (WidgetTester tester) async {
      print("TEST START: Max quantity error test");
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      print("Firestore fetched");
      await firestore.saveProduct(Product(
        id: '123',
        name: 'Milk',
        barcode: '123',
        sellingPrice: 50.0,
        costPrice: 40.0,
        markup: 25.0,
      ));
      print("Product saved in fake firestore");

      await tester.pumpWidget(const MaterialApp(
        home: CheckoutScreen(),
      ));
      print("pumpWidget done");
      await tester.pumpAndSettle();
      print("pumpAndSettle after pumpWidget done");

      await tester.enterText(find.byKey(AppKeys.productSearchInput), '123');
      print("enterText done");
      await tester.tap(find.byKey(AppKeys.addProductButton));
      print("tap addProductButton done");
      await tester.pumpAndSettle();
      print("pumpAndSettle after addProductButton done");

      final cartService = locator<CartService>();
      print("CartService fetched. length: ${cartService.items.length}");
      expect(cartService.items, isNotEmpty);

      // Directly set quantity in global CartService to avoid tapping 1000 times!
      cartService.items[0].quantity = 999;
      cartService.notifyListeners();
      print("quantity set to 999");
      await tester.pump();
      print("pump after setting quantity done");

      // Tap increment once more to trigger max quantity error
      final incBtn = find.byKey(const ValueKey('increment_qty_123'));
      print("increment button found: $incBtn");
      await tester.tap(incBtn);
      print("tap increment button done");
      await tester.pump();
      print("pump after tapping increment done");

      // Verify error status shown in UI
      expect(find.textContaining('Error: Max quantity reached'), findsOneWidget);
      print("TEST END: success");
    });
  });
}
