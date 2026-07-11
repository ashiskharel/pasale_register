import 'package:flutter/material.dart';

import '../models/bounding_box.dart';
import '../models/vision_result.dart';

/// Draws last [VisionResult] boxes over the camera preview.
class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({
    super.key,
    required this.result,
    required this.imageSize,
    this.barcodeColor = Colors.lightGreenAccent,
    this.textColor = Colors.cyanAccent,
    this.objectColor = Colors.orangeAccent,
  });

  final VisionResult? result;
  final Size imageSize;
  final Color barcodeColor;
  final Color textColor;
  final Color objectColor;

  @override
  Widget build(BuildContext context) {
    if (result == null || result!.isEmpty || imageSize.isEmpty) {
      return const SizedBox.expand();
    }
    return CustomPaint(
      size: Size.infinite,
      painter: _OverlayPainter(
        result: result!,
        imageSize: imageSize,
        barcodeColor: barcodeColor,
        textColor: textColor,
        objectColor: objectColor,
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.result,
    required this.imageSize,
    required this.barcodeColor,
    required this.textColor,
    required this.objectColor,
  });

  final VisionResult result;
  final Size imageSize;
  final Color barcodeColor;
  final Color textColor;
  final Color objectColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    void drawBox(BoundingBox? box, Color color, String? label) {
      if (box == null) return;
      final rect = Rect.fromLTWH(
        box.left * scaleX,
        box.top * scaleY,
        box.width * scaleX,
        box.height * scaleY,
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color;
      canvas.drawRect(rect, paint);
      if (label != null && label.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              backgroundColor: Colors.black54,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: size.width);
        tp.paint(canvas, Offset(rect.left, rect.top - 14));
      }
    }

    for (final b in result.barcodes) {
      drawBox(b.boundingBox, barcodeColor, b.rawValue);
    }
    for (final t in result.textBlocks) {
      final preview =
          t.text.length > 24 ? '${t.text.substring(0, 24)}…' : t.text;
      drawBox(t.boundingBox, textColor, preview);
    }
    for (final o in result.objects) {
      final label = o.labels.isNotEmpty
          ? o.labels.first.text
          : (o.trackingId != null ? '#${o.trackingId}' : 'object');
      drawBox(o.boundingBox, objectColor, label);
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return oldDelegate.result != result || oldDelegate.imageSize != imageSize;
  }
}
