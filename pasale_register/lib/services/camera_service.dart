abstract class CameraService {
  /// Capture a still for vendor invoice.
  Future<String?> captureInvoicePhoto();

  /// Capture a product photo for store catalog (same underlying camera).
  Future<String?> captureProductPhoto();
}
