/// Parsed price-tag text from live OCR (no still photo required for reading).
class OcrLabelParse {
  const OcrLabelParse({
    this.price,
    this.notes,
    this.rawSnippet,
    this.hasCurrencyMarker = false,
    this.confidence = 0,
  });

  final double? price;
  final String? notes;
  final String? rawSnippet;

  /// True when price was next to Rs / NPR / रु (not a bare random digit).
  final bool hasCurrencyMarker;

  /// 0–1 quality score (currency + decimals score higher).
  final double confidence;

  bool get hasPrice => price != null && price! > 0;

  /// Safe to open the register dialog for POS price-tag flow.
  bool get isReliableForPos =>
      hasPrice && hasCurrencyMarker && confidence >= 0.75;

  @override
  String toString() =>
      'OcrLabelParse(price: $price, currency: $hasCurrencyMarker, '
      'conf: $confidence, notes: $notes)';
}

/// Extracts selling price and expiry-like notes from OCR lines/blocks.
///
/// **Strict by default for price tags:** only amounts next to currency
/// markers (Rs, NPR, रु, …) count. Bare numbers are ignored so random
/// OCR noise does not open the product dialog.
class PriceOcrParser {
  PriceOcrParser({
    this.minPrice = 1,
    this.maxPrice = 100000,
    /// If true, also accept plain numbers (legacy / tests). Prefer false for POS.
    this.allowPlainNumbers = false,
  });

  final double minPrice;
  final double maxPrice;
  final bool allowPlainNumbers;

  static final _currencyPatterns = <RegExp>[
    // Rs. 25 / Rs 25 / Rs:25 / NPR 49.50
    RegExp(
      r'(?:Rs\.?|RS\.?|NRs?\.?|NPR|रु\.?|रू\.?)\s*[:\-]?\s*(\d{1,6}(?:[.,]\d{1,2})?)',
      caseSensitive: false,
    ),
    // 25 Rs / 49.50 NPR
    RegExp(
      r'(\d{1,6}(?:[.,]\d{1,2})?)\s*(?:Rs\.?|RS\.?|NRs?\.?|NPR|रु\.?|रू\.?)',
      caseSensitive: false,
    ),
    // Price: 25 / MRP 25 / MRP Rs 25
    RegExp(
      r'(?:PRICE|MRP|SP|RATE)\s*[:\-]?\s*(?:Rs\.?|NPR|रु\.?)?\s*(\d{1,6}(?:[.,]\d{1,2})?)',
      caseSensitive: false,
    ),
  ];

  static final _plainNumber =
      RegExp(r'(?<![\d.])(\d{1,6}(?:[.,]\d{1,2})?)(?![\d.])');

  static final _expiryHints = RegExp(
    r'(EXP|EXPIRY|EXPIRES|BEST\s*BEFORE|BBE|USE\s*BY|MFG|MFD|PKD)',
    caseSensitive: false,
  );

  static final _dateLike = RegExp(
    r'\b\d{1,2}[/\-.\s]\d{1,2}[/\-.\s]\d{2,4}\b|\b\d{4}[/\-.\s]\d{1,2}[/\-.\s]\d{1,2}\b',
  );

  /// Parse from free-form OCR strings (blocks or lines).
  OcrLabelParse parse(Iterable<String> texts) {
    final lines = texts
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return const OcrLabelParse();
    }

    final joined = lines.join('\n');
    final notes = _extractNotes(lines);
    final snippet =
        joined.length > 120 ? '${joined.substring(0, 120)}…' : joined;

    final currency = _extractCurrencyPrices(joined);
    if (currency.isNotEmpty) {
      currency.sort((a, b) => a.price.compareTo(b.price));
      final best = currency.last;
      return OcrLabelParse(
        price: best.price,
        notes: notes,
        rawSnippet: snippet,
        hasCurrencyMarker: true,
        confidence: best.confidence,
      );
    }

    if (!allowPlainNumbers) {
      // No Rs/NPR — do not invent a price from random digits.
      return OcrLabelParse(
        notes: notes,
        rawSnippet: snippet,
        hasCurrencyMarker: false,
        confidence: 0,
      );
    }

    final plain = _extractPlainPrices(lines);
    if (plain == null) {
      return OcrLabelParse(notes: notes, rawSnippet: snippet);
    }
    return OcrLabelParse(
      price: plain,
      notes: notes,
      rawSnippet: snippet,
      hasCurrencyMarker: false,
      confidence: 0.4,
    );
  }

  List<({double price, double confidence})> _extractCurrencyPrices(
    String joined,
  ) {
    final hits = <({double price, double confidence})>[];
    for (final re in _currencyPatterns) {
      for (final m in re.allMatches(joined)) {
        final n = _toDouble(m.group(1));
        if (n == null || !_inRange(n)) continue;
        // Prefer typical shelf prices; decimals look more like prices.
        var conf = 0.85;
        if (n != n.roundToDouble()) conf = 0.95;
        if (n >= 5 && n <= 5000) conf += 0.05;
        if (n > 20000) conf -= 0.2; // often weight/barcode fragments
        hits.add((price: n, confidence: conf.clamp(0.0, 1.0)));
      }
    }
    return hits;
  }

  double? _extractPlainPrices(List<String> lines) {
    final plain = <double>[];
    for (final line in lines) {
      if (_expiryHints.hasMatch(line) || _dateLike.hasMatch(line)) continue;
      if (RegExp(r'^\d{4}$').hasMatch(line.trim())) continue;
      // Long digit runs look like barcodes, not prices
      if (RegExp(r'\d{8,}').hasMatch(line)) continue;
      for (final m in _plainNumber.allMatches(line)) {
        final n = _toDouble(m.group(1));
        if (n != null && _inRange(n) && n >= 5 && n < 10000) plain.add(n);
      }
    }
    if (plain.isEmpty) return null;
    plain.sort();
    return plain.last;
  }

  String? _extractNotes(List<String> lines) {
    final noteLines = <String>[];
    for (final line in lines) {
      if (_expiryHints.hasMatch(line) || _dateLike.hasMatch(line)) {
        noteLines.add(line.trim());
      }
    }
    if (noteLines.isEmpty) return null;
    final joined = noteLines.join(' · ');
    return joined.length > 200 ? '${joined.substring(0, 200)}…' : joined;
  }

  double? _toDouble(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  bool _inRange(double n) => n >= minPrice && n <= maxPrice;
}
