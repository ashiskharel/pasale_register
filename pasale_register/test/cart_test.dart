import 'package:flutter_test/flutter_test.dart';
import 'package:pasale_register/models/product.dart';
import 'package:pasale_register/services/cart_service.dart';

void main() {
  group('CartService Unit Tests', () {
    late CartService cartService;

    setUp(() {
      cartService = CartService();
    });

    test('Initial cart is empty with Rs. 0.00 total', () {
      expect(cartService.items, isEmpty);
      expect(cartService.totalPrice, 0.0);
    });

    test('Adding a product to cart adds it with quantity 1', () {
      final product = Product(
        id: '123',
        name: 'Milk',
        barcode: '123',
        sellingPrice: 50.0,
        costPrice: 40.0,
        markup: 25.0,
      );

      cartService.addProduct(product);

      expect(cartService.items.length, 1);
      expect(cartService.items[0].product.barcode, '123');
      expect(cartService.items[0].quantity, 1);
      expect(cartService.totalPrice, 50.0);
    });

    test('Adding the same product multiple times increments its quantity, not items list length', () {
      final product = Product(
        id: '123',
        name: 'Milk',
        barcode: '123',
        sellingPrice: 50.0,
        costPrice: 40.0,
        markup: 25.0,
      );

      cartService.addProduct(product);
      cartService.addProduct(product);

      expect(cartService.items.length, 1);
      expect(cartService.items[0].quantity, 2);
      expect(cartService.totalPrice, 100.0);
    });

    test('Adding different products computes subtotal and lists distinct items correctly', () {
      final product1 = Product(
        id: '123',
        name: 'Milk',
        barcode: '123',
        sellingPrice: 50.0,
        costPrice: 40.0,
        markup: 25.0,
      );
      final product2 = Product(
        id: '456',
        name: 'Egg',
        barcode: '456',
        sellingPrice: 10.0,
        costPrice: 8.0,
        markup: 25.0,
      );

      cartService.addProduct(product1);
      cartService.addProduct(product2);

      expect(cartService.items.length, 2);
      expect(cartService.items[0].product.barcode, '123');
      expect(cartService.items[1].product.barcode, '456');
      expect(cartService.totalPrice, 60.0);
    });

    test('Clearing cart removes all items and resets total', () {
      final product = Product(
        id: '123',
        name: 'Milk',
        barcode: '123',
        sellingPrice: 50.0,
        costPrice: 40.0,
        markup: 25.0,
      );

      cartService.addProduct(product);
      expect(cartService.items, isNotEmpty);

      cartService.clear();
      expect(cartService.items, isEmpty);
      expect(cartService.totalPrice, 0.0);
    });

    test('Adding product with Rs. 0.00 selling price computes total correctly', () {
      final product = Product(
        id: 'free',
        name: 'Free Promo',
        barcode: 'free',
        sellingPrice: 0.0,
        costPrice: 0.0,
        markup: 0.0,
      );

      cartService.addProduct(product);
      expect(cartService.items.length, 1);
      expect(cartService.totalPrice, 0.0);
    });

    test('Precision decimal computation is exact', () {
      final product1 = Product(
        id: 'p1',
        name: 'Item 1',
        barcode: 'p1',
        sellingPrice: 12.19,
        costPrice: 10.55,
        markup: 15.5,
      );
      final product2 = Product(
        id: 'p2',
        name: 'Item 2',
        barcode: 'p2',
        sellingPrice: 5.50,
        costPrice: 4.0,
        markup: 37.5,
      );

      cartService.addProduct(product1);
      cartService.addProduct(product2);
      cartService.addProduct(product2); // Quantity = 2

      // (12.19 * 1) + (5.50 * 2) = 12.19 + 11.00 = 23.19
      expect((cartService.totalPrice - 23.19).abs() < 0.0001, isTrue);
    });
  });
}
