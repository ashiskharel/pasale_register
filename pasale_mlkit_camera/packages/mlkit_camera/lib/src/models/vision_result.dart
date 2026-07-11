import 'barcode_hit.dart';
import 'camera_vision_mode.dart';
import 'object_hit.dart';
import 'text_block_hit.dart';

/// Versioned envelope for one processed camera frame (or combined multi-frame).
///
/// JSON `schemaVersion` is stable for integrators (POS apps, deep links).
class VisionResult {
  static const int schemaVersion = 1;

  const VisionResult({
    required this.timestamp,
    required this.mode,
    this.barcodes = const [],
    this.textBlocks = const [],
    this.objects = const [],
  });

  final DateTime timestamp;
  final CameraVisionMode mode;
  final List<BarcodeHit> barcodes;
  final List<TextBlockHit> textBlocks;
  final List<ObjectHit> objects;

  bool get isEmpty =>
      barcodes.isEmpty && textBlocks.isEmpty && objects.isEmpty;

  bool get isNotEmpty => !isEmpty;

  VisionResult copyWith({
    DateTime? timestamp,
    CameraVisionMode? mode,
    List<BarcodeHit>? barcodes,
    List<TextBlockHit>? textBlocks,
    List<ObjectHit>? objects,
  }) {
    return VisionResult(
      timestamp: timestamp ?? this.timestamp,
      mode: mode ?? this.mode,
      barcodes: barcodes ?? this.barcodes,
      textBlocks: textBlocks ?? this.textBlocks,
      objects: objects ?? this.objects,
    );
  }

  /// Merge non-empty fields (used by multi-mode frame rotation).
  VisionResult merge(VisionResult other) {
    return VisionResult(
      timestamp: other.timestamp.isAfter(timestamp) ? other.timestamp : timestamp,
      mode: CameraVisionMode.batchCheckout,
      barcodes: other.barcodes.isNotEmpty ? other.barcodes : barcodes,
      textBlocks: other.textBlocks.isNotEmpty ? other.textBlocks : textBlocks,
      objects: other.objects.isNotEmpty ? other.objects : objects,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'mode': mode.name,
        'barcodes': barcodes.map((b) => b.toJson()).toList(),
        'textBlocks': textBlocks.map((t) => t.toJson()).toList(),
        'objects': objects.map((o) => o.toJson()).toList(),
      };

  factory VisionResult.fromJson(Map<String, dynamic> json) {
    final modeName = json['mode'] as String? ?? 'barcodeQr';
    // Accept legacy names from earlier drafts.
    final normalized = switch (modeName) {
      'barcode' || 'multi' => modeName == 'multi' ? 'batchCheckout' : 'barcodeQr',
      _ => modeName,
    };
    final mode = CameraVisionMode.values.firstWhere(
      (m) => m.name == normalized,
      orElse: () => CameraVisionMode.barcodeQr,
    );
    return VisionResult(
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now().toUtc(),
      mode: mode,
      barcodes: (json['barcodes'] as List?)
              ?.map(
                (e) => BarcodeHit.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          const [],
      textBlocks: (json['textBlocks'] as List?)
              ?.map(
                (e) =>
                    TextBlockHit.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          const [],
      objects: (json['objects'] as List?)
              ?.map(
                (e) => ObjectHit.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          const [],
    );
  }

  @override
  String toString() =>
      'VisionResult(mode: $mode, barcodes: ${barcodes.length}, '
      'text: ${textBlocks.length}, objects: ${objects.length})';
}
