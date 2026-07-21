import 'package:flutter/widgets.dart';

abstract class CameraService {
  /// Capture a still for vendor invoice.
  Future<String?> captureInvoicePhoto();

  /// Capture a product photo for store catalog (same underlying camera).
  Future<String?> captureProductPhoto();

  /// Stop ML scan stream and keep camera open for a live still preview.
  Future<void> prepareProductPhotoSession() async {}

  /// Live camera widget for framing a product photo, or null if unavailable.
  Widget? buildProductPhotoPreview() => null;

  /// Stream of recognized product names during camera session.
  Stream<String> get productNameStream => const Stream.empty();
}
