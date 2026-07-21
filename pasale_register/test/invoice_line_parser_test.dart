import 'package:flutter_test/flutter_test.dart';
import 'package:pasale_register/utils/invoice_line_parser.dart';

void main() {
  final parser = InvoiceLineParser(defaultMarkupPercent: 20);

  test('parses name and trailing price with decimals', () {
    final lines = parser.parseLines(['Wai Wai Noodles  25.00', 'Total 100']);
    expect(lines.length, 1);
    expect(lines.first.name, contains('Wai Wai'));
    expect(lines.first.costPrice, 25);
    expect(lines.first.sellingPrice, 30);
  });

  test('parses whole-rupee trailing price (no decimals)', () {
    final lines = parser.parseLines(['Sugar 1kg  120']);
    expect(lines.length, 1);
    expect(lines.first.costPrice, 120);
    expect(lines.first.sellingPrice, 144);
  });

  test('parses currency amount', () {
    final lines = parser.parseLines(['Cooking Oil 1L Rs. 280']);
    expect(lines.length, 1);
    expect(lines.first.costPrice, 280);
  });

  test('pairs name line + price line', () {
    final lines = parser.parseLines(['Wai Wai Noodles', 'Rs. 25', 'Total']);
    expect(lines.length, 1);
    expect(lines.first.name, 'Wai Wai Noodles');
    expect(lines.first.costPrice, 25);
  });

  test('skips totals', () {
    final lines = parser.parseLines(['Grand Total 5000', 'Thank you']);
    expect(lines, isEmpty);
  });
}
