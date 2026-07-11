# Integrating `mlkit_camera` with a POS (e.g. Pasale Register)

## VisionResult JSON schema (`schemaVersion: 1`)

```json
{
  "schemaVersion": 1,
  "timestamp": "2026-07-10T12:00:00.000Z",
  "mode": "barcode",
  "barcodes": [
    {
      "rawValue": "8901234567890",
      "format": "BarcodeFormat.ean13",
      "displayValue": "8901234567890",
      "boundingBox": { "left": 10, "top": 20, "width": 100, "height": 40 }
    }
  ],
  "textBlocks": [
    {
      "text": "Rs. 120.00",
      "lines": ["Rs. 120.00"],
      "boundingBox": { "left": 0, "top": 0, "width": 80, "height": 20 }
    }
  ],
  "objects": [
    {
      "trackingId": 3,
      "boundingBox": { "left": 5, "top": 5, "width": 50, "height": 50 },
      "labels": [{ "text": "Food", "confidence": 0.91, "index": 1 }]
    }
  ]
}
```

Export batches from the example app wrap many results:

```json
{
  "schemaVersion": 1,
  "exportedAt": "...",
  "mode": "multi",
  "results": [ /* VisionResult objects */ ]
}
```

## Integration styles

### A. Embed package (recommended for Pasale UX)

- Add `mlkit_camera` dependency.
- Host `MlkitCameraView` in checkout (split-screen with cart).
- Map `results` barcodes → existing catalog lookup / registration dialog.
- Keep fakes in unit tests; only real controller on device.

### B. Third-party process (intent / share)

- Install example or a branded fork as a separate app.
- User scans → **Share JSON** / clipboard → POS imports.
- Optional deep link (host implements):

  `pasale://scan?payload=<url-encoded-json>`

### C. Still image → vision service

- Call `controller.captureStill()` for tray / invoice photos.
- POST image to a separate vision API (custom segmentation, later roadmap).
- Keep continuous store video on-prem; package default is on-device only.

## Mapping to Pasale services (implemented)

| Pasale abstraction | mlkit_camera |
|--------------------|--------------|
| `MlkitScannerService` | Wraps shared `MlkitCameraController` |
| `ScannerService.scan()` | First barcode/QR on `results` stream |
| `ScannerService.buildScannerWidget()` | `MlkitCameraView` |
| `ScannerService.stopScanning()` | `controller.stop()` |
| `ScannerService.applyCameraPolicy()` | `controller.updatePolicy()` |
| `CameraService.captureInvoicePhoto()` | `controller.captureStill()` |
| Superadmin **Cam Scope** tab | Firestore `stores/{id}/settings/cameraScope` |

### Device smoke checklist

1. Set `kUseFakeServices = false` in `pasale_register/lib/main.dart` (needs Firebase configured).
2. Or keep fakes for UI flow tests without camera plugins.
3. `flutter run` on a phone/emulator with camera.
4. Activate store → Checkout → Scan Barcode → barcode/QR → Done Scanning.
5. Cam Scope → Free/Premium toggles → Save → confirm policy JSON.
