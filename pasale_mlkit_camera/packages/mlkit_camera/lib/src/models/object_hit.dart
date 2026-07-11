import 'bounding_box.dart';

/// A detected object instance (coarse category, not store SKU).
class ObjectHit {
  const ObjectHit({
    required this.boundingBox,
    this.trackingId,
    this.labels = const [],
  });

  final BoundingBox boundingBox;
  final int? trackingId;
  final List<ObjectLabelHit> labels;

  Map<String, dynamic> toJson() => {
        'boundingBox': boundingBox.toJson(),
        if (trackingId != null) 'trackingId': trackingId,
        if (labels.isNotEmpty)
          'labels': labels.map((l) => l.toJson()).toList(),
      };

  factory ObjectHit.fromJson(Map<String, dynamic> json) => ObjectHit(
        boundingBox: BoundingBox.fromJson(
          Map<String, dynamic>.from(json['boundingBox'] as Map),
        ),
        trackingId: json['trackingId'] as int?,
        labels: (json['labels'] as List?)
                ?.map(
                  (e) => ObjectLabelHit.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList() ??
            const [],
      );

  @override
  String toString() =>
      'ObjectHit(trackingId: $trackingId, labels: ${labels.map((l) => l.text).join(',')})';
}

/// Label assigned to a detected object.
class ObjectLabelHit {
  const ObjectLabelHit({
    required this.text,
    required this.confidence,
    this.index,
  });

  final String text;
  final double confidence;
  final int? index;

  Map<String, dynamic> toJson() => {
        'text': text,
        'confidence': confidence,
        if (index != null) 'index': index,
      };

  factory ObjectLabelHit.fromJson(Map<String, dynamic> json) => ObjectLabelHit(
        text: json['text'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        index: json['index'] as int?,
      );
}
