import 'bounding_box.dart';

/// Recognized text block from OCR.
class TextBlockHit {
  const TextBlockHit({
    required this.text,
    this.boundingBox,
    this.lines = const [],
  });

  final String text;
  final BoundingBox? boundingBox;
  final List<String> lines;

  Map<String, dynamic> toJson() => {
        'text': text,
        if (boundingBox != null) 'boundingBox': boundingBox!.toJson(),
        if (lines.isNotEmpty) 'lines': lines,
      };

  factory TextBlockHit.fromJson(Map<String, dynamic> json) => TextBlockHit(
        text: json['text'] as String? ?? '',
        boundingBox: json['boundingBox'] != null
            ? BoundingBox.fromJson(
                Map<String, dynamic>.from(json['boundingBox'] as Map),
              )
            : null,
        lines: (json['lines'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );

  @override
  String toString() =>
      'TextBlockHit(${text.length > 40 ? '${text.substring(0, 40)}…' : text})';
}
