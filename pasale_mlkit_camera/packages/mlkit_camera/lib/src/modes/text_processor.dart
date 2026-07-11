import 'dart:ui' show Rect;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/bounding_box.dart';
import '../models/text_block_hit.dart';

/// Wraps ML Kit [TextRecognizer] (Latin script by default).
class TextProcessor {
  TextProcessor({
    TextRecognizer? recognizer,
  })  : _recognizer = recognizer ??
            TextRecognizer(script: TextRecognitionScript.latin),
        _ownsRecognizer = recognizer == null;

  final TextRecognizer _recognizer;
  final bool _ownsRecognizer;

  Future<List<TextBlockHit>> process(InputImage image) async {
    final result = await _recognizer.processImage(image);
    return result.blocks.map((block) {
      return TextBlockHit(
        text: block.text,
        boundingBox: _box(block.boundingBox),
        lines: block.lines.map((l) => l.text).toList(),
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
    if (_ownsRecognizer) {
      await _recognizer.close();
    }
  }
}
