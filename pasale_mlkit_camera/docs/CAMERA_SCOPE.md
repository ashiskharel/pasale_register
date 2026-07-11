# Camera scope, freemium, and superadmin

## Product intent

| Audience | Camera behavior |
|----------|-----------------|
| **Free users (now)** | **Barcode + QR scanner** at checkout |
| **Premium (later)** | Object detection (trained / self-labeled) + **batch checkout via segmentation** |
| **Superadmin** | Change store camera scope anytime (no app release) |

Object detection and batch segmentation stay **in the codebase** but are **gated** so free installs are not forced into unfinished premium pipelines.

## Capability model

| Capability | Free default | Premium default | Notes |
|------------|:------------:|:---------------:|-------|
| `barcodeQr` | ✓ | ✓ | EAN/UPC/Code128 + QR, etc. |
| `textOcr` | — | ✓ | Optional invoice assist |
| `objectDetection` | — | ✓ | Coarse labels now; SKUs after training |
| `batchSegmentation` | — | ✓ | Batch checkout path; model swap later |

## Superadmin control

`CameraScopePolicy` is pure JSON-friendly config:

```json
{
  "tier": "free",
  "enabled": ["barcodeQr"],
  "updatedBy": "superadmin@example.com",
  "updatedAt": "2026-07-11T08:00:00.000Z",
  "notes": "Free tier default — barcode & QR"
}
```

- Persist under something like `/stores/{storeId}/settings/cameraScope` in Firestore later.
- App loads policy at startup and calls `controller.updatePolicy(policy)`.
- Superadmin UI toggles capabilities; policy can unlock object detection on a free store for pilots without flipping the whole plan.

## Runtime API

```dart
// Free cashier device
final controller = MlkitCameraController(
  policy: CameraScopePolicy.freeDefault(),
);
await controller.start(); // barcodeQr

// Superadmin changes scope (live)
await controller.updatePolicy(
  policy.withCapability(
    CameraCapability.objectDetection,
    enabled: true,
    updatedBy: 'superadmin',
  ),
);
```

Blocked modes set `controller.error` with a clear upgrade / superadmin message.

## Roadmap hooks

1. **Now:** barcode + QR formats explicit in `BarcodeProcessor`.
2. **Train / self-label:** custom object or segmentation model.
3. **Premium:** enable `objectDetection` + `batchSegmentation` for paying stores.
4. **Swap engine:** implement real segmentation inside `batchCheckout` without changing host JSON `schemaVersion` if possible (bump only when fields change).
