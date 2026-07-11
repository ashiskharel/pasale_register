import 'package:flutter_test/flutter_test.dart';
import 'package:mlkit_camera/mlkit_camera.dart';

void main() {
  group('BarcodeDebounce', () {
    test('allows first value', () {
      final d = BarcodeDebounce(window: const Duration(seconds: 2));
      expect(d.shouldEmit('123', now: DateTime(2026, 1, 1, 12, 0, 0)), isTrue);
    });

    test('suppresses same value within window', () {
      final d = BarcodeDebounce(window: const Duration(seconds: 2));
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      expect(d.shouldEmit('123', now: t0), isTrue);
      expect(
        d.shouldEmit('123', now: t0.add(const Duration(seconds: 1))),
        isFalse,
      );
    });

    test('allows same value after window', () {
      final d = BarcodeDebounce(window: const Duration(seconds: 2));
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      expect(d.shouldEmit('123', now: t0), isTrue);
      expect(
        d.shouldEmit('123', now: t0.add(const Duration(seconds: 2))),
        isTrue,
      );
    });

    test('allows different value immediately', () {
      final d = BarcodeDebounce(window: const Duration(seconds: 2));
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      expect(d.shouldEmit('123', now: t0), isTrue);
      expect(d.shouldEmit('456', now: t0), isTrue);
    });

    test('reset clears state', () {
      final d = BarcodeDebounce(window: const Duration(seconds: 2));
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      expect(d.shouldEmit('123', now: t0), isTrue);
      d.reset();
      expect(d.shouldEmit('123', now: t0), isTrue);
    });
  });

  group('FrameThrottle', () {
    test('allows first then blocks until interval', () {
      final t = FrameThrottle(minInterval: const Duration(milliseconds: 200));
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      expect(t.allow(now: t0), isTrue);
      expect(t.allow(now: t0.add(const Duration(milliseconds: 50))), isFalse);
      expect(
        t.allow(now: t0.add(const Duration(milliseconds: 200))),
        isTrue,
      );
    });
  });
}
