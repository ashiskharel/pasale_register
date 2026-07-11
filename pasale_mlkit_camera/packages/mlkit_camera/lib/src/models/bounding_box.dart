/// Axis-aligned box in image coordinates (pixels).
class BoundingBox {
  const BoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  Map<String, dynamic> toJson() => {
        'left': left,
        'top': top,
        'width': width,
        'height': height,
      };

  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
        left: (json['left'] as num).toDouble(),
        top: (json['top'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );

  @override
  String toString() =>
      'BoundingBox(left: $left, top: $top, width: $width, height: $height)';
}
