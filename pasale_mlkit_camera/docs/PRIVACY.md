# Privacy

## Default behavior

- **All ML Kit processing runs on-device** (barcode, OCR, object detection).
- This package does **not** upload camera frames or video to any server.
- The example app exports results only when the user copies or shares JSON.

## Data classes

| Data | Handling |
|------|----------|
| Live camera frames | Processed in memory; not stored by the package |
| Still captures (`captureStill`) | Saved to a local temp path returned to the host |
| Detection results | Emitted on a Dart stream; host decides persistence |
| Continuous CCTV / store video | **Out of scope** — keep on-prem if you add it later |

## Host app responsibilities

- Request camera permission with a clear purpose string.
- If you forward images or JSON to a cloud vision service, disclose that in your app privacy policy.
- Prefer cropped product/tray images over full customer faces when leaving the device.

## Google ML Kit

Google ML Kit may download model files on first use (unbundled variants / Play Services). Review Google's ML Kit terms and privacy documentation for model download behavior on your target platforms.
