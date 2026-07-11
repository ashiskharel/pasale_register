/// Runtime vision modes supported by [MlkitCameraController].
///
/// Product access is gated by [CameraScopePolicy] / [CameraCapability], not by
/// this enum alone. Free tier default is [barcodeQr].
enum CameraVisionMode {
  /// 1D barcodes and QR codes — free default scanner.
  barcodeQr,

  /// On-device text recognition (OCR).
  text,

  /// Object detection (premium; SKU training later).
  objectDetection,

  /// Multi-item batch checkout (premium; segmentation model later).
  ///
  /// v0.1 uses a multi-detector stub; swap in trained segmentation without
  /// changing host contracts once models are ready.
  batchCheckout,
}
