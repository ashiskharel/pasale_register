import 'bounding_box.dart';

/// A single barcode / QR detection.
class BarcodeHit {
  const BarcodeHit({
    required this.rawValue,
    this.format,
    this.boundingBox,
    this.displayValue,
  });

  /// Decoded payload (e.g. EAN digits or URL).
  final String rawValue;

  /// ML Kit format name when available (e.g. `BarcodeFormat.ean13`).
  final String? format;

  final BoundingBox? boundingBox;

  /// Human-friendly value when different from [rawValue].
  final String? displayValue;

  Map<String, dynamic> toJson() => {
        'rawValue': rawValue,
        if (format != null) 'format': format,
        if (displayValue != null) 'displayValue': displayValue,
        if (boundingBox != null) 'boundingBox': boundingBox!.toJson(),
      };

  factory BarcodeHit.fromJson(Map<String, dynamic> json) => BarcodeHit(
        rawValue: json['rawValue'] as String,
        format: json['format'] as String?,
        displayValue: json['displayValue'] as String?,
        boundingBox: json['boundingBox'] != null
            ? BoundingBox.fromJson(
                Map<String, dynamic>.from(json['boundingBox'] as Map),
              )
            : null,
      );

  @override
  String toString() => 'BarcodeHit($rawValue)';
}
