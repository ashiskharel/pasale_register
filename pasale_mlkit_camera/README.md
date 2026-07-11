# pasale_mlkit_camera

Monorepo for an open-source **Flutter camera vision** stack built on Google ML Kit.

```
pasale_mlkit_camera/
  packages/mlkit_camera/   # publishable package (pub.dev)
  example/                 # third-party demo camera app
  docs/                    # integration + privacy
```

## Quick start

```bash
cd packages/mlkit_camera
flutter pub get
flutter test

cd ../../example
flutter pub get
flutter run
```

## Why a separate package?

Pasale Register's POS app keeps cart, Firebase, and business logic. This repo is the **reusable camera front-end** any POS can adopt, then open-source independently under Apache-2.0 (ML Kit itself remains proprietary — see `packages/mlkit_camera/NOTICE`).

## Status

**0.1.0** — barcode + OCR + object detection + multi mode, example app, JSON export.
