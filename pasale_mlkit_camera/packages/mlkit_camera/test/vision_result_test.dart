import 'package:flutter_test/flutter_test.dart';
import 'package:mlkit_camera/mlkit_camera.dart';

void main() {
  group('VisionResult JSON', () {
    test('round-trips schemaVersion 1', () {
      final original = VisionResult(
        timestamp: DateTime.utc(2026, 7, 10, 12, 0, 0),
        mode: CameraVisionMode.batchCheckout,
        barcodes: const [
          BarcodeHit(
            rawValue: '8901234567890',
            format: 'ean13',
            boundingBox: BoundingBox(left: 1, top: 2, width: 3, height: 4),
          ),
        ],
        textBlocks: const [
          TextBlockHit(text: 'Rs. 120', lines: ['Rs. 120']),
        ],
        objects: const [
          ObjectHit(
            boundingBox: BoundingBox(left: 10, top: 20, width: 30, height: 40),
            trackingId: 7,
            labels: [
              ObjectLabelHit(text: 'Food', confidence: 0.9, index: 1),
            ],
          ),
        ],
      );

      final json = original.toJson();
      expect(json['schemaVersion'], VisionResult.schemaVersion);
      expect(json['mode'], 'batchCheckout');

      final restored = VisionResult.fromJson(json);
      expect(restored.mode, CameraVisionMode.batchCheckout);
      expect(restored.barcodes.single.rawValue, '8901234567890');
      expect(restored.textBlocks.single.text, 'Rs. 120');
      expect(restored.objects.single.trackingId, 7);
      expect(restored.objects.single.labels.single.text, 'Food');
      expect(restored.barcodes.single.boundingBox!.left, 1);
    });

    test('legacy mode names map correctly', () {
      final fromBarcode = VisionResult.fromJson({
        'timestamp': '2026-01-01T00:00:00.000Z',
        'mode': 'barcode',
        'barcodes': [],
        'textBlocks': [],
        'objects': [],
      });
      expect(fromBarcode.mode, CameraVisionMode.barcodeQr);

      final fromMulti = VisionResult.fromJson({
        'timestamp': '2026-01-01T00:00:00.000Z',
        'mode': 'multi',
        'barcodes': [],
        'textBlocks': [],
        'objects': [],
      });
      expect(fromMulti.mode, CameraVisionMode.batchCheckout);
    });

    test('merge keeps latest non-empty fields', () {
      final a = VisionResult(
        timestamp: DateTime.utc(2026, 1, 1),
        mode: CameraVisionMode.batchCheckout,
        barcodes: const [BarcodeHit(rawValue: 'A')],
      );
      final b = VisionResult(
        timestamp: DateTime.utc(2026, 1, 2),
        mode: CameraVisionMode.batchCheckout,
        textBlocks: const [TextBlockHit(text: 'hello')],
      );
      final m = a.merge(b);
      expect(m.barcodes.single.rawValue, 'A');
      expect(m.textBlocks.single.text, 'hello');
      expect(m.timestamp, DateTime.utc(2026, 1, 2));
    });

    test('isEmpty / isNotEmpty', () {
      final empty = VisionResult(
        timestamp: DateTime.utc(2026, 1, 1),
        mode: CameraVisionMode.barcodeQr,
      );
      expect(empty.isEmpty, isTrue);
      expect(
        empty
            .copyWith(barcodes: const [BarcodeHit(rawValue: '1')])
            .isNotEmpty,
        isTrue,
      );
    });
  });
}
