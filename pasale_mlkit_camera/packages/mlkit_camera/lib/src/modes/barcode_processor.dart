import 'dart:ui' show Rect;

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../models/barcode_hit.dart';
import '../models/bounding_box.dart';
import '../utils/barcode_debounce.dart';

/// Formats used for retail checkout: product barcodes + QR.
///
/// Explicit list so the free-tier scanner is clearly barcode **and** QR,
/// not an accidental subset.
const List<BarcodeFormat> kRetailBarcodeAndQrFormats = [
  BarcodeFormat.qrCode,
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upca,
  BarcodeFormat.upce,
  BarcodeFormat.code128,
  BarcodeFormat.code39,
  BarcodeFormat.code93,
  BarcodeFormat.codabar,
  BarcodeFormat.itf,
  BarcodeFormat.pdf417,
  BarcodeFormat.aztec,
  BarcodeFormat.dataMatrix,
];

/// Wraps ML Kit [BarcodeScanner] with debounce (barcodes + QR).
class BarcodeProcessor {
  BarcodeProcessor({
    BarcodeScanner? scanner,
    BarcodeDebounce? debounce,
    List<BarcodeFormat> formats = kRetailBarcodeAndQrFormats,
  })  : _scanner = scanner ?? BarcodeScanner(formats: formats),
        _debounce = debounce ?? BarcodeDebounce(),
        _ownsScanner = scanner == null;

  final BarcodeScanner _scanner;
  final BarcodeDebounce _debounce;
  final bool _ownsScanner;

  Future<List<BarcodeHit>> process(InputImage image) async {
    final barcodes = await _scanner.processImage(image);
    final hits = <BarcodeHit>[];
    for (final b in barcodes) {
      final raw = b.rawValue;
      if (raw == null || raw.isEmpty) continue;
      if (!_debounce.shouldEmit(raw)) continue;
      hits.add(
        BarcodeHit(
          rawValue: raw,
          displayValue: b.displayValue,
          format: b.format.name,
          boundingBox: _box(b.boundingBox),
        ),
      );
    }
    return hits;
  }

  BoundingBox? _box(Rect? r) {
    if (r == null) return null;
    return BoundingBox(
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
    );
  }

  void resetDebounce() => _debounce.reset();

  Future<void> close() async {
    if (_ownsScanner) {
      await _scanner.close();
    }
  }
}
