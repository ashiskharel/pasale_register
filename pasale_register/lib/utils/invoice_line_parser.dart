import 'package:mlkit_camera/mlkit_camera.dart';

/// Editable draft line from an invoice OCR pass.
class InvoiceLineDraft {
  InvoiceLineDraft({
    required this.name,
    this.barcode = '',
    required this.costPrice,
    required this.sellingPrice,
    this.quantity = 1.0,
    this.markupPercent = 20,
    this.selected = true,
    this.rawLine = '',
  });

  String name;
  String barcode;
  double costPrice;
  double sellingPrice;
  double quantity;
  double markupPercent;
  bool selected;
  String rawLine;

  void recomputeSellFromMarkup() {
    sellingPrice = double.parse(
      (costPrice * (1 + markupPercent / 100)).toStringAsFixed(2),
    );
  }

  void recomputeMarkupFromPrices() {
    if (costPrice <= 0) {
      markupPercent = 0;
      return;
    }
    markupPercent = double.parse(
      (((sellingPrice - costPrice) / costPrice) * 100).toStringAsFixed(1),
    );
  }
}

/// Result of an OCR + parse pass (includes raw text for debugging / fallback UI).
class InvoiceParseResult {
  const InvoiceParseResult({
    required this.lines,
    required this.rawText,
    required this.rawLineCount,
    this.vendorName = '',
  });

  final List<InvoiceLineDraft> lines;
  final String rawText;
  final int rawLineCount;
  final String vendorName;

  bool get isEmpty => lines.isEmpty;
}

/// Heuristic OCR → invoice line items (name + cost; sell via default markup).
///
/// Tolerant of whole rupees (no decimals), optional Rs/NPR, and OCR spacing noise.
class InvoiceLineParser {
  InvoiceLineParser({this.defaultMarkupPercent = 20});

  final double defaultMarkupPercent;

  /// name … [qty x] [Rs.] 120 or 120.00  (decimal optional)
  static final _lineWithPrice = RegExp(
    r'^(.+?)\s+(?:(\d+(?:[.,]\d+)?)\s*[xX×\*]\s*)?'
    r'(?:Rs\.?|RS\.?|NRs?\.?|NPR|रु\.?|रू\.?)?\s*[:\-]?\s*'
    r'(\d{1,7}(?:[.,]\d{1,2})?)\s*$',
    caseSensitive: false,
  );

  static final _currencyAnywhere = RegExp(
    r'(?:Rs\.?|RS\.?|NRs?\.?|NPR|रु\.?|रू\.?)\s*[:\-]?\s*(\d{1,7}(?:[.,]\d{1,2})?)',
    caseSensitive: false,
  );

  /// Last number on the line (fallback when no currency).
  static final _trailingNumber = RegExp(
    r'^(.*\S)\s+(\d{1,7}(?:[.,]\d{1,2})?)\s*$',
  );

  static final _skipLine = RegExp(
    r'^(total|sub\s*total|grand\s*total|net\s*total|vat|tax|gst|discount|'
    r'invoice|bill\s*no|bill\s*#|date|tel|phone|pan|thank|page\s*\d|'
    r'cash|change|balance|received|qty|particulars|amount|sn\.?$|s\.?n\.?)',
    caseSensitive: false,
  );

  List<InvoiceLineDraft> parseBlocks(List<TextBlockHit> blocks) {
    return parseResultFromBlocks(blocks).lines;
  }

  InvoiceParseResult parseResultFromBlocks(List<TextBlockHit> blocks) {
    final lines = <String>[];
    for (final b in blocks) {
      if (b.lines.isNotEmpty) {
        lines.addAll(b.lines.map((l) => l.trim()).where((l) => l.isNotEmpty));
      } else if (b.text.trim().isNotEmpty) {
        lines.addAll(
          b.text
              .split(RegExp(r'[\n\r]+'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
      }
    }
    return parseResultFromLines(lines);
  }

  List<InvoiceLineDraft> parseLines(List<String> lines) =>
      parseResultFromLines(lines).lines;

  InvoiceParseResult parseResultFromLines(List<String> lines) {
    final cleaned = lines.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final out = <InvoiceLineDraft>[];
    String vendorName = '';

    for (var i = 0; i < cleaned.length; i++) {
      final line = cleaned[i];
      if (line.length < 2) continue;
      
      // Heuristic: First valid line that isn't skipped is likely the Vendor Name
      if (vendorName.isEmpty && !_skipLine.hasMatch(line) && line.length > 3 && RegExp(r'[a-zA-Z]').hasMatch(line)) {
        final lower = line.toLowerCase();
        final isJunkVendor = lower.contains('invoice') || 
                             lower.contains('cash') || 
                             lower.contains('memo') || 
                             lower.contains('receipt') || 
                             lower.contains('bill') || 
                             lower.contains('tax') || 
                             lower.contains('vat');
        if (!isJunkVendor) {
          vendorName = line;
        }
      }

      if (_skipLine.hasMatch(line)) continue;

      // Pair "Product name" on one line + "Rs. 50" on the next
      if (i + 1 < cleaned.length) {
        final next = cleaned[i + 1];
        final paired = _tryPairNameAndPriceLine(line, next);
        if (paired != null) {
          out.add(paired);
          i++; // consume price line
          continue;
        }
      }

      final draft = _tryParseLine(line);
      if (draft != null) out.add(draft);
    }

    return InvoiceParseResult(
      lines: out,
      rawText: cleaned.join('\n'),
      rawLineCount: cleaned.length,
      vendorName: vendorName,
    );
  }

  InvoiceLineDraft? _tryPairNameAndPriceLine(String nameLine, String priceLine) {
    if (_skipLine.hasMatch(nameLine) || _looksLikeJunkName(nameLine)) {
      return null;
    }
    // Name line shouldn't be mostly numbers
    if (RegExp(r'^\d').hasMatch(nameLine.trim())) return null;

    double? price;
    final cm = _currencyAnywhere.firstMatch(priceLine);
    if (cm != null) {
      price = _toDouble(cm.group(1));
    } else {
      final onlyNum = RegExp(r'^\s*(\d{1,7}(?:[.,]\d{1,2})?)\s*$')
          .firstMatch(priceLine);
      if (onlyNum != null) price = _toDouble(onlyNum.group(1));
    }
    if (price == null || price <= 0 || price > 1000000) return null;
    if (nameLine.trim().length < 2) return null;

    return _draft(name: nameLine.trim(), cost: price, raw: '$nameLine | $priceLine');
  }

  InvoiceLineDraft? _tryParseLine(String line) {
    final m = _lineWithPrice.firstMatch(line);
    if (m != null) {
      final name = (m.group(1) ?? '').trim();
      final qty = _toDouble(m.group(2)) ?? 1;
      final unit = _toDouble(m.group(3));
      if (name.isEmpty || unit == null || unit <= 0) return null;
      if (_looksLikeJunkName(name)) return null;
      final cost = unit; // unit cost; qty for future stock
      return _draft(name: name, cost: cost, raw: line, qty: qty);
    }

    final cm = _currencyAnywhere.firstMatch(line);
    if (cm != null) {
      final cost = _toDouble(cm.group(1));
      if (cost == null || cost <= 0) return null;
      var name = line.replaceFirst(cm.group(0)!, '').trim();
      name = name.replaceAll(RegExp(r'[\s\-–—:]+$'), '').trim();
      name = name.replaceAll(RegExp(r'^[\s\-–—:]+'), '').trim();
      if (name.length < 2 || _looksLikeJunkName(name)) {
        // currency-only line without name — skip (pair handler may use it)
        return null;
      }
      return _draft(name: name, cost: cost, raw: line);
    }

    // Fallback: trailing bare number (common on plain invoices / OCR)
    final tm = _trailingNumber.firstMatch(line);
    if (tm != null) {
      final name = (tm.group(1) ?? '').trim();
      final cost = _toDouble(tm.group(2));
      if (name.isEmpty || cost == null || cost <= 0) return null;
      if (_looksLikeJunkName(name)) return null;
      // Avoid treating years / long codes as prices when alone
      if (cost >= 1900 && cost <= 2100 && !name.contains(RegExp(r'[a-zA-Z]'))) {
        return null;
      }
      if (cost > 500000) return null;
      return _draft(name: name, cost: cost, raw: line);
    }

    return null;
  }

  InvoiceLineDraft _draft({
    required String name,
    required double cost,
    required String raw,
    double qty = 1.0,
  }) {
    final sell = double.parse(
      (cost * (1 + defaultMarkupPercent / 100)).toStringAsFixed(2),
    );
    return InvoiceLineDraft(
      name: name,
      costPrice: cost,
      sellingPrice: sell,
      quantity: qty,
      markupPercent: defaultMarkupPercent,
      rawLine: raw,
    );
  }

  bool _looksLikeJunkName(String name) {
    if (RegExp(r'^\d+$').hasMatch(name)) return true;
    if (name.length > 100) return true;
    return false;
  }

  double? _toDouble(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll(',', ''));
  }
}
