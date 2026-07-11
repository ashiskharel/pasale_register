import 'package:flutter/material.dart';
import 'package:mlkit_camera/mlkit_camera.dart';

abstract class ScannerService {
  Future<String?> scan();
  Future<void> triggerFeedback();
  Widget buildScannerWidget();

  /// Stops continuous camera processing (Done Scanning / OK).
  Future<void> stopScanning() async {}

  /// Apply superadmin / Firestore camera scope (no-op for fakes by default).
  Future<void> applyCameraPolicy(CameraScopePolicy policy) async {}

  /// Current scope (free barcode/QR by default when unsupported).
  CameraScopePolicy get cameraPolicy => CameraScopePolicy.freeDefault();
}
