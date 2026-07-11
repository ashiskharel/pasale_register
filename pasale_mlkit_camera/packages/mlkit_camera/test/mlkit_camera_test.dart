import 'package:flutter_test/flutter_test.dart';
import 'package:mlkit_camera/mlkit_camera.dart';

void main() {
  test('public API exports resolve', () {
    expect(CameraVisionMode.barcodeQr.name, 'barcodeQr');
    expect(VisionResult.schemaVersion, 1);
    final debounce = BarcodeDebounce();
    expect(debounce.shouldEmit('x'), isTrue);
    expect(
      CameraScopePolicy.freeDefault().defaultMode,
      CameraVisionMode.barcodeQr,
    );
  });
}
