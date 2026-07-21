# Firebase + Firestore setup (Pasale Register)

Full field reference: **[docs/FIRESTORE_SCHEMA.md](docs/FIRESTORE_SCHEMA.md)**  
**Phone OTP + Facebook Auth:** **[docs/AUTH_SETUP.md](docs/AUTH_SETUP.md)**

---

## Status of this machine

- Firebase CLI is installed (`firebase --version`)
- You may be logged in (`firebase login:list`)
- `firebase projects:list` sometimes fails (API/network); create/select project in the **Console** instead

---

## 1. Create project in Console

1. Open [Firebase Console](https://console.firebase.google.com/)
2. **Add project** → name e.g. `pasale-register`
3. Disable Google Analytics if you want (optional)
4. **Build → Firestore Database → Create database**
   - Start in **production mode** (we deploy rules next) or test mode for 30 days
   - Pick a region (e.g. `asia-south1`)
5. **Build → Storage → Get started** (optional, for product photos later)
6. **Project settings → Your apps → Add app → Android**
   - Package name: **`com.example.pasale_register`**
   - Download `google-services.json` (FlutterFire can also generate this)

---

## 2. Link Flutter app (FlutterFire)

```powershell
cd "C:\Users\aerok\Pasale Register-grok\pasale_register"

$env:Path = "$env:APPDATA\npm;$env:LOCALAPPDATA\Pub\Cache\bin;$env:Path"
firebase login   # if needed
firebase use YOUR_PROJECT_ID

dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_PROJECT_ID --platforms=android
```

This writes real:

- `lib/firebase_options.dart`
- `android/app/google-services.json`

Our bootstrap treats options as configured when `projectId` / `apiKey` are not placeholders.

Then:

```powershell
flutter clean
flutter pub get
# Dev Firebase project (default):
flutter run
# Production Firebase project (separate DB):
flutter run --dart-define=ENV=Prod
```

Banner should show: **Firebase · real camera**.  
`ENV` selects `firebase_options_dev.dart` vs `firebase_options_prod.dart` (`Prod` / `prod` / `PROD` all map to production).

---

## 3. Deploy rules + indexes

```powershell
cd "C:\Users\aerok\Pasale Register-grok\pasale_register"
firebase use YOUR_PROJECT_ID
.\scripts\deploy_firestore.ps1
# or:
# firebase deploy --only firestore:rules,firestore:indexes,storage
```

Files:

| File | Role |
|------|------|
| `firestore.rules` | Field checks for stores, products, devices, cameraScope, sales |
| `firestore.indexes.json` | Composite indexes for products/sales |
| `storage.rules` | Product/invoice image paths |
| `firebase.json` | Wire-up for deploy + emulators |

---

## 4. Collections & fields (summary)

```
stores/{storeId}
  storeId, name, activationDate, isActive, planTier, currency, createdAt, updatedAt
  devices/{deviceId}
    deviceId, model, osVersion, lastActive, platform?, appVersion?, createdAt, updatedAt
  products/{barcode}
    id, name, barcode, sellingPrice, costPrice, markup, storeId,
    imagePath?, imageUrl?, isActive, unit?, notes?, createdAt, updatedAt
  settings/cameraScope
    tier, enabled[], updatedBy?, updatedAt, notes?
  sales/{saleId}   (legacy mirror of checkouts)
    saleId, storeId, totalPrice, isPaid, items[], customerPhone?, deviceId?, status, createdAt
  invoices/{invoiceId}   # POS history (Dashboard, View Invoices, Customers)
    id, storeId, total, payment (cash|credit), source (cart|manual),
    customerPhone?, customerName?, customerEmail?, lineSummary[], notes?,
    createdAt (ISO string), createdAtTs (Timestamp), isPaid
  customers/{phone}      # rolled up from invoices
    phone, name, email?, creditBalance, lastActivityAt, transactionCount

products/{barcode}   # global seed fallback (same product fields)
```

### Invoices & customers (so records show while testing)

After checkout / manual invoice, the app writes to:

- `stores/{yourStoreId}/invoices/{id}`
- `stores/{yourStoreId}/customers/{phone}`

**You need:**

1. Firebase project linked (`flutterfire configure`) so the app banner says **Firebase · real camera**
2. Firestore created in that project
3. Rules deployed (includes `invoices` + `customers`):
   ```powershell
   cd "C:\Users\aerok\Pasale Register-grok\pasale_register"
   firebase use YOUR_PROJECT_ID
   firebase deploy --only firestore:rules
   ```
4. App activated with a **Store ID** (store setup screen) — that ID is the Firestore `stores/{storeId}` document
5. Run the app **without** `USE_FAKES=true` or `REAL_CAMERA_ONLY=true`

**If records only show on device but not Console:** still on fakes/local cache (check banner).  
**If Console empty after production mode:** check Firestore → `stores` → your store id → `invoices`.  
**If writes fail:** open Logcat for permission / index errors; deploy rules above. Optional index:

```
Collection: stores/{storeId}/invoices
Field: createdAtTs  Descending
```

(App falls back to unordered fetch if the index is missing.)


See **docs/FIRESTORE_SCHEMA.md** for full tables + examples.

---

## 5. Seed sample data (Console)

### Option A — Manual documents

Create store `demo-store-01` using fields in `docs/sample_store_tree.json`.

### Option B — Import JSON (Emulator or tools)

- Global seeds: `docs/sample_seed_products.json` → collection `products`
- Store tree sample: `docs/sample_store_tree.json`

### Option C — App path

1. Activate a store in the app (writes `stores/{id}` + device + default cameraScope)
2. Scan unknown barcode → register with price + photo (writes `stores/{id}/products/{code}`)
3. Cam Scope → save (writes `settings/cameraScope`)

---

## 6. Emulator (optional, offline)

```powershell
firebase emulators:start --only firestore
```

UI: http://localhost:4000  

Point the app at emulators later with:

```dart
FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
```

(Not enabled by default on device — use physical Firebase project for phone tests.)

---

## 7. Verify from the app

| Action | Expect in Console |
|--------|-------------------|
| Activate store | `stores/{id}` with name + dates |
| Same session | `stores/{id}/devices/{deviceId}` |
| Save product / unknown scan | `stores/{id}/products/{barcode}` |
| Cam Scope save | `stores/{id}/settings/cameraScope` |
| Catalog list | Snapshot of store products |

---

## 8. Production hardening (later)

- Replace open rules with **Firebase Auth** + store membership
- Upload product photos to Storage → set `imageUrl`
- Persist checkout to `sales/{saleId}`
- Restrict superadmin Cam Scope by custom claims
