import 'package:flutter_test/flutter_test.dart';
import 'package:pasale_register/utils/price_ocr_parser.dart';

void main() {
  final parser = PriceOcrParser(); // strict: currency required

  test('parses Rs. price with high confidence', () {
    final r = parser.parse(['Wai Wai Noodles', 'Rs. 25', 'EXP 12/26']);
    expect(r.price, 25);
    expect(r.hasCurrencyMarker, isTrue);
    expect(r.isReliableForPos, isTrue);
    expect(r.notes, contains('EXP'));
  });

  test('parses NPR and decimals', () {
    final r = parser.parse(['NPR 49.50']);
    expect(r.price, 49.5);
    expect(r.isReliableForPos, isTrue);
  });

  test('parses trailing currency', () {
    final r = parser.parse(['120 Rs']);
    expect(r.price, 120);
    expect(r.isReliableForPos, isTrue);
  });

  test('parses MRP label', () {
    final r = parser.parse(['MRP: Rs 85']);
    expect(r.price, 85);
    expect(r.isReliableForPos, isTrue);
  });

  test('ignores plain numbers without currency (no false popup)', () {
    final r = parser.parse(['Snack Pack', '85', '12', '3']);
    expect(r.hasPrice, isFalse);
    expect(r.isReliableForPos, isFalse);
  });

  test('ignores barcode-like digit noise', () {
    final r = parser.parse(['8901030865561', 'batch 42']);
    expect(r.isReliableForPos, isFalse);
  });

  test('plain numbers only when explicitly allowed', () {
    final loose = PriceOcrParser(allowPlainNumbers: true);
    final r = loose.parse(['Snack Pack', '85']);
    expect(r.price, 85);
    expect(r.hasCurrencyMarker, isFalse);
    expect(r.isReliableForPos, isFalse); // still not POS-reliable
  });

  test('empty input', () {
    final r = parser.parse([]);
    expect(r.hasPrice, isFalse);
  });
}
