# mlkit_camera

On-device **camera vision** for Flutter using **Google ML Kit**.

### Freemium camera scope

| Mode | Default | Notes |
|------|---------|--------|
| `barcodeQr` | **Free** | Product barcodes **and** QR codes (debounce) |
| `text` | Superadmin / premium preset | OCR for labels / invoices |
| `objectDetection` | **Premium** | Coarse labels now; train/self-label later |
| `batchCheckout` | **Premium** | Batch checkout; segmentation model later |

Superadmin can change store scope via `CameraScopePolicy` without an app release.
See [docs/CAMERA_SCOPE.md](../../docs/CAMERA_SCOPE.md).

Designed as a **POS-agnostic** package: any host app can embed the widget or consume exported JSON.

## License clarity

| Layer | License |
|-------|---------|
| This Dart/Flutter package + example | **Apache-2.0** |
| Google ML Kit native SDKs | **Proprietary** (free to use under Google's terms) |

See [NOTICE](NOTICE). Publishing this package as open source does **not** open-source ML Kit.

## Install

```yaml
dependencies:
  mlkit_camera: ^0.1.0
```

Android: declare `CAMERA` permission.  
iOS: set `NSCameraUsageDescription`.

## Quick start

```dart
final controller = MlkitCameraController(
  policy: CameraScopePolicy.freeDefault(), // barcode + QR
);
await controller.initialize();
await controller.start(); // defaults to barcodeQr

// In build():
MlkitCameraView(controller: controller)

// Superadmin changes scope later:
// await controller.updatePolicy(newPolicy);

// When cashier is done:
await controller.stop();

// Cleanup:
await controller.close();
controller.dispose();
```

Listen to results:

```dart
controller.results.listen((VisionResult r) {
  for (final b in r.barcodes) {
    print(b.rawValue);
  }
});
```

## Limitations (v0.1)

- **Object labels ≠ SKUs.** Base ML Kit categories are coarse. Store-specific matching needs a custom model or external vision service.
- **OCR** uses Latin script first; Devanagari/Nepali accuracy is not guaranteed.
- Primary target: **Android / iOS**. Desktop/web are not supported for ML Kit.

## Example app

```bash
cd example
flutter pub get
flutter run
```

## Integration

See [../../docs/INTEGRATION.md](../../docs/INTEGRATION.md) for POS embed / intent / vision-service options and the JSON schema.

## Privacy

Processing is **on-device by default**. See [../../docs/PRIVACY.md](../../docs/PRIVACY.md).
