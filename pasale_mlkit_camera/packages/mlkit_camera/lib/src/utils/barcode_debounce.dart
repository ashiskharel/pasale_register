/// Suppresses repeated emissions of the same barcode within [window].
///
/// Mirrors the Pasale Register checkout scanner behavior (same code ≈ 2s).
class BarcodeDebounce {
  BarcodeDebounce({this.window = const Duration(seconds: 2)});

  final Duration window;

  String? _lastValue;
  DateTime? _lastAt;

  /// Returns `true` if [value] should be emitted (not a recent duplicate).
  bool shouldEmit(String value, {DateTime? now}) {
    final t = now ?? DateTime.now();
    if (_lastValue == value && _lastAt != null) {
      if (t.difference(_lastAt!) < window) {
        return false;
      }
    }
    _lastValue = value;
    _lastAt = t;
    return true;
  }

  void reset() {
    _lastValue = null;
    _lastAt = null;
  }
}
