import 'dart:ui' show Rect;

import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../models/bounding_box.dart';
import '../models/object_hit.dart';

/// Wraps ML Kit base [ObjectDetector] (stream mode, multiple objects).
///
/// Labels are coarse categories — not store SKUs. Custom TFLite models are
/// a planned v1.1+ extension.
class ObjectProcessor {
  ObjectProcessor({
    ObjectDetector? detector,
  })  : _detector = detector ??
            ObjectDetector(
              options: ObjectDetectorOptions(
                mode: DetectionMode.stream,
                classifyObjects: true,
                multipleObjects: true,
              ),
            ),
        _ownsDetector = detector == null;

  final ObjectDetector _detector;
  final bool _ownsDetector;

  Future<List<ObjectHit>> process(InputImage image) async {
    final objects = await _detector.processImage(image);
    return objects.map((o) {
      return ObjectHit(
        boundingBox: _box(o.boundingBox) ??
            const BoundingBox(left: 0, top: 0, width: 0, height: 0),
        trackingId: o.trackingId,
        labels: o.labels
            .map(
              (l) => ObjectLabelHit(
                text: l.text,
                confidence: l.confidence,
                index: l.index,
              ),
            )
            .toList(),
      );
    }).toList();
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

  Future<void> close() async {
    if (_ownsDetector) {
      await _detector.close();
    }
  }
}
