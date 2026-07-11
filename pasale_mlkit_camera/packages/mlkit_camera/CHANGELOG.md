## 0.1.0

* Initial public API: `MlkitCameraController`, `MlkitCameraView`.
* **Free default:** barcode **and** QR scanning (`CameraVisionMode.barcodeQr`).
* **Freemium scope:** `CameraScopePolicy` + `CameraCapability` for superadmin control.
* Premium-gated: object detection, batch checkout (segmentation path later).
* Modes: `barcodeQr`, `text`, `objectDetection`, `batchCheckout`.
* Explicit retail barcode + QR formats in `BarcodeProcessor`.
* Versioned `VisionResult` JSON (`schemaVersion: 1`).
* Barcode debounce, frame throttle, detection overlay, still capture.
* Example app: free tier default + Superadmin scope screen.
