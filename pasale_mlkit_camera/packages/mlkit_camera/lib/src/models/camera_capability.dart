/// Product-level camera capabilities that superadmin can enable/disable.
///
/// Maps to [CameraVisionMode]s the controller may run. Free tier ships with
/// [barcodeQr] only; object detection and batch segmentation are premium
/// (upgrade path for free users once models are trained / self-labeled).
enum CameraCapability {
  /// 1D product barcodes + QR codes. Default free scope.
  barcodeQr,

  /// On-device OCR (invoice / label assist). Optional; superadmin can enable.
  textOcr,

  /// Object detection (coarse now; store SKUs after training). Premium.
  objectDetection,

  /// Batch checkout via multi-item / segmentation pipeline. Premium.
  batchSegmentation,
}

/// Subscription / plan tier for freemium gating and upgrade UI.
enum PlanTier {
  free,
  premium,
}

extension CameraCapabilityX on CameraCapability {
  /// Capabilities that require a premium plan by default (upsell targets).
  bool get isPremiumDefault =>
      this == CameraCapability.objectDetection ||
      this == CameraCapability.batchSegmentation;

  String get displayName => switch (this) {
        CameraCapability.barcodeQr => 'Barcode & QR',
        CameraCapability.textOcr => 'Text (OCR)',
        CameraCapability.objectDetection => 'Object detection',
        CameraCapability.batchSegmentation => 'Batch checkout (segmentation)',
      };

  String get description => switch (this) {
        CameraCapability.barcodeQr =>
          'Scan product barcodes and QR codes at checkout (included free).',
        CameraCapability.textOcr =>
          'Read printed text on labels and invoices.',
        CameraCapability.objectDetection =>
          'Detect items without barcodes (after training / self-labeling).',
        CameraCapability.batchSegmentation =>
          'Multi-item tray/batch checkout via segmentation (premium).',
      };
}
