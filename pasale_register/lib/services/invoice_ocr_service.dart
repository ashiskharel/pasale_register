import 'package:flutter/foundation.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mlkit_camera/mlkit_camera.dart';

import '../utils/invoice_line_parser.dart';

/// On-device invoice OCR (Google ML Kit TextRecognizer — runs on the phone).
class InvoiceOcrService {
  InvoiceOcrService({
    TextRecognizer? recognizer,
    InvoiceLineParser? parser,
  })  : _recognizer = recognizer ??
            TextRecognizer(script: TextRecognitionScript.latin),
        _parser = parser ?? InvoiceLineParser(),
        _ownsRecognizer = recognizer == null;

  final TextRecognizer _recognizer;
  InvoiceLineParser _parser;
  set parser(InvoiceLineParser p) => _parser = p;
  final bool _ownsRecognizer;

  /// OCR still image → structured lines + raw text for fallback UI.
  Future<InvoiceParseResult> parseInvoiceImage(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(input);

    final blocks = <TextBlockHit>[];
    final allLines = <String>[];

    for (final block in recognized.blocks) {
      final lines = block.lines.map((l) => l.text.trim()).toList();
      blocks.add(TextBlockHit(text: block.text, lines: lines));
      allLines.addAll(lines.where((l) => l.isNotEmpty));
      // Also flatten elements if lines are sparse (OCR sometimes lumps poorly)
      for (final line in block.lines) {
        for (final el in line.elements) {
          final t = el.text.trim();
          if (t.isNotEmpty && !allLines.contains(t)) {
            // keep elements only as debug aid in raw text later
          }
        }
      }
    }

    // If ML Kit returned almost nothing via lines, use full text split
    if (allLines.isEmpty && recognized.text.trim().isNotEmpty) {
      allLines.addAll(
        recognized.text
            .split(RegExp(r'[\n\r]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }

    debugPrint(
      'InvoiceOcrService: on-device OCR '
      'blocks=${recognized.blocks.length} lines=${allLines.length} '
      'chars=${recognized.text.length}',
    );
    if (allLines.isNotEmpty) {
      debugPrint(
        'InvoiceOcrService: sample → ${allLines.take(8).join(' || ')}',
      );
    }

    final result = _parser.parseResultFromLines(allLines);
    // Attach full recognized blob if parser raw is thin
    if (result.rawText.isEmpty && recognized.text.trim().isNotEmpty) {
      return InvoiceParseResult(
        lines: result.lines,
        rawText: recognized.text.trim(),
        rawLineCount: allLines.length,
      );
    }
    return result;
  }

  Future<void> dispose() async {
    if (_ownsRecognizer) {
      await _recognizer.close();
    }
  }
}
