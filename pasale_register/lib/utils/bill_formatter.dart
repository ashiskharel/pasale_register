import '../models/cart_item.dart';

class BillFormatter {
  static String generateReceipt({
    required List<CartItem> cart,
    required double totalPrice,
    required bool isPaid,
    required bool checkedOut,
    String storeName = 'Pasale',
  }) {
    final buffer = StringBuffer();
    buffer.writeln('--- $storeName Receipt ---');
    for (var item in cart) {
      buffer.writeln('${item.product.name} x${item.quantity} - Rs. ${(item.product.sellingPrice * item.quantity).toStringAsFixed(2)}');
    }
    buffer.writeln('Total: Rs. ${totalPrice.toStringAsFixed(2)}');
    buffer.writeln('Payment: ${isPaid ? "Paid" : "Credit"}');
    buffer.writeln('Status: ${checkedOut ? "Completed" : "Pending"}');
    return buffer.toString();
  }

  static bool isValidNepaliPhoneNumber(String phone) {
    return RegExp(r'^9[78]\d{8}$').hasMatch(phone);
  }
}
