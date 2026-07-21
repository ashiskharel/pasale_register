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

  /// Detailed credit invoice SMS'd to the customer after credit sale.
  static String generateDetailedCreditInvoice({
    required List<CartItem> cart,
    required double totalPrice,
    required String storeName,
    required String customerPhone,
    DateTime? at,
  }) {
    final when = at ?? DateTime.now();
    final buffer = StringBuffer();
    buffer.writeln('=== $storeName — CREDIT INVOICE ===');
    buffer.writeln(
      'Date: ${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')} '
      '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}',
    );
    buffer.writeln('Customer: $customerPhone');
    buffer.writeln('Payment: CREDIT (amount due)');
    buffer.writeln('--- Items ---');
    for (var item in cart) {
      final line = item.product.sellingPrice * item.quantity;
      buffer.writeln(
        '${item.product.name} (${item.product.barcode})',
      );
      buffer.writeln(
        '  ${item.quantity} x Rs. ${item.product.sellingPrice.toStringAsFixed(2)} = Rs. ${line.toStringAsFixed(2)}',
      );
    }
    buffer.writeln('----------------');
    buffer.writeln('TOTAL DUE: Rs. ${totalPrice.toStringAsFixed(2)}');
    buffer.writeln('Please settle with $storeName. Thank you!');
    return buffer.toString();
  }

  /// Manual invoice (no line items) for offline / verbal sales.
  static String generateManualInvoice({
    required String storeName,
    required DateTime date,
    required double totalPrice,
    required String customerPhone,
    required bool isPaid,
    String? notes,
  }) {
    final buffer = StringBuffer();
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    buffer.writeln(
      '=== $storeName — ${isPaid ? 'PAID' : 'CREDIT'} INVOICE ===',
    );
    buffer.writeln('Date: $y-$m-$d');
    buffer.writeln('Customer: $customerPhone');
    buffer.writeln('Type: Manual invoice');
    buffer.writeln('Payment: ${isPaid ? 'PAID' : 'CREDIT (amount due)'}');
    if (notes != null && notes.trim().isNotEmpty) {
      buffer.writeln('Notes: ${notes.trim()}');
    }
    buffer.writeln('----------------');
    buffer.writeln(
      isPaid
          ? 'TOTAL PAID: Rs. ${totalPrice.toStringAsFixed(2)}'
          : 'TOTAL DUE: Rs. ${totalPrice.toStringAsFixed(2)}',
    );
    buffer.writeln(
      isPaid
          ? 'Thank you for shopping at $storeName!'
          : 'Please settle with $storeName. Thank you!',
    );
    return buffer.toString();
  }
}
