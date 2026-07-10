import 'package:flutter_test/flutter_test.dart';
import 'package:pasale_register/models/product.dart';
import 'package:pasale_register/models/cart_item.dart';
import 'package:pasale_register/utils/bill_formatter.dart';

void main() {
  group('Bill Formatting and Receipt Generation Tests', () {
    test('Formats a single item receipt correctly', () {
      final product = Product(
        id: '123',
        name: 'Milk',
        barcode: '123',
        sellingPrice: 50.0,
        costPrice: 40.0,
        markup: 25.0,
      );
      final cart = [CartItem(product: product, quantity: 2)];
      final totalPrice = 100.0;

      final receipt = BillFormatter.generateReceipt(
        cart: cart,
        totalPrice: totalPrice,
        isPaid: true,
        checkedOut: true,
      );

      final expected = '--- Pasale Receipt ---\n'
          'Milk x2 - Rs. 100.00\n'
          'Total: Rs. 100.00\n'
          'Payment: Paid\n'
          'Status: Completed\n';

      expect(receipt, expected);
    });

    test('Formats a receipt with custom store name header correctly', () {
      final product = Product(
        id: '123',
        name: 'Milk',
        barcode: '123',
        sellingPrice: 50.0,
        costPrice: 40.0,
        markup: 25.0,
      );
      final cart = [CartItem(product: product, quantity: 2)];
      final totalPrice = 100.0;

      final receipt = BillFormatter.generateReceipt(
        cart: cart,
        totalPrice: totalPrice,
        isPaid: true,
        checkedOut: true,
        storeName: 'My Awesome Store',
      );

      final expected = '--- My Awesome Store Receipt ---\n'
          'Milk x2 - Rs. 100.00\n'
          'Total: Rs. 100.00\n'
          'Payment: Paid\n'
          'Status: Completed\n';

      expect(receipt, expected);
    });

    test('Formats a multi-item receipt with varying payment and checkout status', () {
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
        sellingPrice: 10.50,
        costPrice: 8.0,
        markup: 31.25,
      );
      final cart = [
        CartItem(product: product1, quantity: 1),
        CartItem(product: product2, quantity: 3),
      ];
      final totalPrice = 50.0 + (10.50 * 3); // 81.50

      final receipt = BillFormatter.generateReceipt(
        cart: cart,
        totalPrice: totalPrice,
        isPaid: false, // Credit
        checkedOut: false, // Pending
      );

      final expected = '--- Pasale Receipt ---\n'
          'Milk x1 - Rs. 50.00\n'
          'Egg x3 - Rs. 31.50\n'
          'Total: Rs. 81.50\n'
          'Payment: Credit\n'
          'Status: Pending\n';

      expect(receipt, expected);
    });

    test('Handles precision decimal products in formatting', () {
      final product1 = Product(
        id: 'p1',
        name: 'Biscuit',
        barcode: 'p1',
        sellingPrice: 12.19,
        costPrice: 10.55,
        markup: 15.5,
      );
      final product2 = Product(
        id: 'p2',
        name: 'Tea',
        barcode: 'p2',
        sellingPrice: 5.50,
        costPrice: 4.0,
        markup: 37.5,
      );
      final cart = [
        CartItem(product: product1, quantity: 1),
        CartItem(product: product2, quantity: 2),
      ];
      final totalPrice = 12.19 + (5.50 * 2); // 23.19

      final receipt = BillFormatter.generateReceipt(
        cart: cart,
        totalPrice: totalPrice,
        isPaid: true,
        checkedOut: true,
      );

      final expected = '--- Pasale Receipt ---\n'
          'Biscuit x1 - Rs. 12.19\n'
          'Tea x2 - Rs. 11.00\n'
          'Total: Rs. 23.19\n'
          'Payment: Paid\n'
          'Status: Completed\n';

      expect(receipt, expected);
    });

    test('Validates Nepal phone numbers correctly', () {
      expect(BillFormatter.isValidNepaliPhoneNumber('9841234567'), isTrue);
      expect(BillFormatter.isValidNepaliPhoneNumber('9741234567'), isTrue);
      expect(BillFormatter.isValidNepaliPhoneNumber('9801234567'), isTrue);
      expect(BillFormatter.isValidNepaliPhoneNumber('9851234567'), isTrue);
      expect(BillFormatter.isValidNepaliPhoneNumber('9761234567'), isTrue);

      expect(BillFormatter.isValidNepaliPhoneNumber('9641234567'), isFalse); // Doesn't start with 97 or 98
      expect(BillFormatter.isValidNepaliPhoneNumber('984123456'), isFalse);  // Less than 10 digits
      expect(BillFormatter.isValidNepaliPhoneNumber('98412345678'), isFalse); // More than 10 digits
      expect(BillFormatter.isValidNepaliPhoneNumber('984123456a'), isFalse); // Contains non-digit
      expect(BillFormatter.isValidNepaliPhoneNumber(''), isFalse);
    });
  });
}
