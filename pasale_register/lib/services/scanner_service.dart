import 'package:flutter/material.dart';
import 'package:mlkit_camera/mlkit_camera.dart';

import '../utils/price_ocr_parser.dart';

abstract class ScannerService {
  Future<String?> scan();
  Future<void> triggerFeedback();
  Widget buildScannerWidget();

  /// Stops continuous camera processing (Done Scanning / OK).
  Future<void> stopScanning() async {}

  /// Apply superadmin / Firestore camera scope (no-op for fakes by default).
  Future<void> applyCameraPolicy(CameraScopePolicy policy) async {}

  /// Current scope (free barcode/QR + OCR by default when unsupported).
  CameraScopePolicy get cameraPolicy => CameraScopePolicy.freeDefault();

  /// Active vision mode for the live preview.
  CameraVisionMode get visionMode => CameraVisionMode.barcodeQr;

  /// Switch between barcode and price-tag (OCR) scanning.
  Future<void> setVisionMode(CameraVisionMode mode) async {}

  /// Next stable OCR price-tag parse (price-tag mode). Returns null if cancelled.
  Future<OcrLabelParse?> scanPriceLabel() async => null;
}
