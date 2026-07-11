# Firebase + real camera setup

## What the app does today

| Mode | When | Camera | Catalog / scope |
|------|------|--------|------------------|
| **Production** | Firebase configured (`isConfigured = true`) | Real ML Kit | Real Firestore |
| **Real camera (default fallback)** | No Firebase yet | Real ML Kit | Fake local seed data |
| **Fakes** | `--dart-define=USE_FAKES=true` | Fake | Fake |

On phone, with **no** Firebase project yet, `flutter run` already uses **real barcode/QR camera** and a local catalog.

---

## One-time Firebase project (full production)

### 1. Install tools

```powershell
npm install -g firebase-tools
dart pub global activate flutterfire_cli
# ensure Pub bin is on PATH:
# %LOCALAPPDATA%\Pub\Cache\bin
```

### 2. Login and create/select project

```powershell
firebase login
firebase projects:list
```

In [Firebase Console](https://console.firebase.google.com/):

1. Create project (e.g. `pasale-register`)
2. Enable **Cloud Firestore** (test mode for dev is fine)
3. Add Android app with package name: **`com.example.pasale_register`**

### 3. Configure Flutter

From this folder (`pasale_register`):

```powershell
cd "C:\Users\aerok\Pasale Register-grok\pasale_register"
flutterfire configure --project=YOUR_PROJECT_ID --platforms=android,ios
```

This overwrites:

- `lib/firebase_options.dart` (sets real keys; set `isConfigured` if using our stub style — FlutterFire’s file is used as-is and we treat it as configured when you set the flag or replace the file)
- `android/app/google-services.json`
- optionally `ios/Runner/GoogleService-Info.plist`

After FlutterFire generates `firebase_options.dart`, either:

- Use the generated file **as-is**, and update `lib/bootstrap.dart` to always try init when options exist, **or**
- In our stub, set `DefaultFirebaseOptions.isConfigured = true` and paste real values.

**Easiest path after `flutterfire configure`:** replace our stub entirely with the generated file, then set in `bootstrap.dart`:

```dart
// Always try Firebase when not USE_FAKES / REAL_CAMERA_ONLY
```

Our bootstrap already tries `DefaultFirebaseOptions.isConfigured`.  
If FlutterFire overwrites the file **without** `isConfigured`, add:

```dart
static const bool isConfigured = true;
```

to the generated class (or we detect valid non-placeholder projectId).

### 4. Firestore rules (dev)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true; // DEV ONLY
    }
  }
}
```

Collections used:

- `stores/{storeId}`
- `stores/{storeId}/devices/{deviceId}`
- `stores/{storeId}/settings/cameraScope`
- `products/{productId}`

### 5. Run on phone

```powershell
cd "C:\Users\aerok\Pasale Register-grok\pasale_register"
flutter run
```

Banner should say **Firebase · real camera**.

---

## Real camera only (no Firebase yet)

Already the default fallback:

```powershell
flutter run
# or force:
flutter run --dart-define=REAL_CAMERA_ONLY=true
```

---

## Tests (fakes)

```powershell
flutter test --dart-define=USE_FAKES=true
# or tests that call setupLocator(backend: ServiceBackend.fakes)
```

Unit tests still call `setupLocator(useFakes: true)` via the legacy helper / explicit fakes.
