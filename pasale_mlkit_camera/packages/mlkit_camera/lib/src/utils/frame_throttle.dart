/// Limits how often heavy vision work runs on the camera stream.
class FrameThrottle {
  FrameThrottle({this.minInterval = const Duration(milliseconds: 200)});

  final Duration minInterval;
  DateTime? _last;

  bool allow({DateTime? now}) {
    final t = now ?? DateTime.now();
    if (_last != null && t.difference(_last!) < minInterval) {
      return false;
    }
    _last = t;
    return true;
  }

  void reset() => _last = null;
}
