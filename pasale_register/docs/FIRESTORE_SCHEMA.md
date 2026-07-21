# Pasale Register — Firestore schema (all fields)

Package: `com.example.pasale_register`  
Database: **Cloud Firestore** (default)

```
users/{uid}                         # Firebase Auth user profile
businesses/{businessId}             # owner company (phone/FB owner)
  members/{uid}
  catalog/{productId}               # shared master catalog (phase 3)
stores/{storeId}                    # substore / branch POS
  devices/{deviceId}
  products/{barcode}
  settings/cameraScope
  sales/{saleId}
  invoices/{invoiceId}
  customers/{phone}

products/{barcode}                  # global seed / legacy fallback
```

### Membership model (phases 1–3)

- **Owner key in rules = Firebase Auth `uid`** (not phone alone).
- Phone is profile/recovery; Facebook uses same `uid` when accounts are linked.
- On login: `ensureMembershipProfile` creates `users/{uid}` + default `businesses/biz_{uid}`.
- On store activate / **Add branch**: store gets `ownerUid`, `memberUids: [uid]`, `businessId`.
- **Heal**: on home open, `healStoreMembership` claims legacy stores missing membership (fixes catalog/scanner after rules rollout).
- **Catalog sync**: `businesses/{id}/catalog/{sku}` is master; `stores/{id}/products` holds branch prices (store wins on merge).
- **Store switcher** in Store Owner app bar lists member stores and can create branches.

---

## 0. `users/{uid}` / `businesses/{businessId}`

| Path | Key fields |
|------|------------|
| `users/{uid}` | `uid`, `primaryPhone?`, `displayName?`, `email?`, `businessIds[]`, `defaultStoreId?` |
| `businesses/{id}` | `businessId`, `ownerUid`, `primaryPhone?`, `name`, `storeIds[]` |
| `businesses/{id}/members/{uid}` | `role` (`owner`\|`manager`\|`cashier`), `storeIds[]` (`*` = all) |

---

## 1. `stores/{storeId}`

Written by: **Activation** (`activateStore`)

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `storeId` | string | ✓ | Same as document id |
| `name` | string | ✓ | Shop display name |
| `activationDate` | string (ISO-8601) or Timestamp | ✓ | First activation time |
| `createdAt` | Timestamp | ✓ (server) | Write-time |
| `updatedAt` | Timestamp | ✓ (server) | Last update |
| `isActive` | bool | | Default `true` |
| `planTier` | string | | `free` \| `premium` (optional mirror of camera scope) |
| `currency` | string | | Default `NPR` |
| `businessId` | string | ✓ (new) | Parent business / multi-store group |
| `ownerUid` | string | ✓ (new) | Firebase Auth uid of owner |
| `memberUids` | list\<string\> | ✓ (new) | Uids allowed to access this store |
| `catalogMode` | string | | `shared` (default) \| `local` |
| `ownerPhone` | string | | E.164 when activated via phone login |
| `phone` | string | | Store contact (optional) |
| `address` | string | | Optional |

**Example**

```json
{
  "storeId": "shop-kathmandu-01",
  "name": "Pasale Mini Mart",
  "activationDate": "2026-07-11T10:00:00.000Z",
  "isActive": true,
  "planTier": "free",
  "currency": "NPR"
}
```

---

## 2. `stores/{storeId}/devices/{deviceId}`

Written by: **Activation** (`registerDevice`)

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `deviceId` | string | ✓ | Same as document id |
| `model` | string | ✓ | e.g. `Pixel 7` |
| `osVersion` | string | ✓ | e.g. `Android 14` |
| `lastActive` | string (ISO-8601) or Timestamp | ✓ | Heartbeat |
| `createdAt` | Timestamp | | First register |
| `updatedAt` | Timestamp | | Last seen |
| `platform` | string | | `android` \| `ios` |
| `appVersion` | string | | Optional |

**Example**

```json
{
  "deviceId": "dev-abc123",
  "model": "Samsung Galaxy A14",
  "osVersion": "Android 13",
  "lastActive": "2026-07-11T12:30:00.000Z",
  "platform": "android"
}
```

---

## 3. `stores/{storeId}/products/{barcode}`

Written by: **Catalog**, **Checkout register-unknown**, **Invoice ingestor**  
Doc id = **barcode** (or product id).

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `id` | string | ✓ | Usually = barcode |
| `name` | string | ✓ | Display name |
| `barcode` | string | ✓ | Scanned code / QR payload |
| `sellingPrice` | number | ✓ | **This store’s** price (NPR) |
| `costPrice` | number | ✓ | Cost (≥ 0) |
| `markup` | number | ✓ | Percent markup |
| `storeId` | string | ✓ | Owning store |
| `imagePath` | string | | Local device path (offline) |
| `imageUrl` | string | | Firebase Storage URL (cloud) |
| `createdAt` | Timestamp | | First save |
| `updatedAt` | Timestamp | | Last edit |
| `isActive` | bool | | Soft-delete flag |
| `unit` | string | | e.g. `pcs`, `kg` |
| `notes` | string | | Optional |

**Example**

```json
{
  "id": "8901234567890",
  "name": "Wai Wai Noodles",
  "barcode": "8901234567890",
  "sellingPrice": 25,
  "costPrice": 20,
  "markup": 25,
  "storeId": "shop-kathmandu-01",
  "imagePath": "/data/.../product_photos/shop-kathmandu-01/8901234567890.jpg",
  "imageUrl": null,
  "isActive": true,
  "unit": "pcs"
}
```

---

## 4. `products/{barcode}` (global seed / legacy)

Same fields as store products, but **no store-specific price**.  
App **reads** store catalog first, then falls back here.

Used for marketplace seed data (`assets/seeded_products.json` import).

---

## 5. `stores/{storeId}/settings/cameraScope`

Written by: **Cam Scope** superadmin UI

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `tier` | string | ✓ | `free` \| `premium` |
| `enabled` | array\<string\> | ✓ | Capability names |
| `updatedBy` | string | | Admin id/email |
| `updatedAt` | string (ISO) or Timestamp | | Last change |
| `notes` | string | | Audit note |

**Allowed `enabled` values**

| Value | Meaning |
|-------|---------|
| `barcodeQr` | Barcode + QR (free default) |
| `textOcr` | OCR |
| `objectDetection` | Object detection (premium) |
| `batchSegmentation` | Batch checkout / segmentation (premium) |

**Example (free)**

```json
{
  "tier": "free",
  "enabled": ["barcodeQr"],
  "updatedBy": "superadmin@demo",
  "updatedAt": "2026-07-11T12:00:00.000Z",
  "notes": "Free tier default — barcode & QR"
}
```

**Example (premium)**

```json
{
  "tier": "premium",
  "enabled": [
    "barcodeQr",
    "textOcr",
    "objectDetection",
    "batchSegmentation"
  ],
  "updatedBy": "superadmin@demo",
  "updatedAt": "2026-07-11T12:05:00.000Z",
  "notes": "Premium default — full camera scope"
}
```

---

## 6. `stores/{storeId}/sales/{saleId}` (checkout history)

Optional; schema ready for receipt persistence.

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `saleId` | string | ✓ | Document id |
| `storeId` | string | ✓ | Store |
| `deviceId` | string | | Device that sold |
| `totalPrice` | number | ✓ | Cart total |
| `isPaid` | bool | ✓ | Paid vs credit |
| `customerPhone` | string | | For SMS/WhatsApp share |
| `items` | array | ✓ | Line items |
| `createdAt` | Timestamp | ✓ | Sale time |
| `status` | string | | `completed` \| `void` |

**`items[]` element**

| Field | Type | Description |
|-------|------|-------------|
| `productId` | string | Barcode / id |
| `name` | string | Snapshot name |
| `barcode` | string | Code |
| `unitPrice` | number | Selling price at sale |
| `quantity` | number | Qty |
| `lineTotal` | number | unitPrice × quantity |
| `imageUrl` | string | Optional snapshot |

---

## 7. Firebase Storage (product photos)

| Path | Use |
|------|-----|
| `stores/{storeId}/products/{barcode}.jpg` | Catalog product photo |
| `stores/{storeId}/invoices/{uuid}.jpg` | Vendor invoice capture |

App currently stores **local** `imagePath`; upload to Storage → set `imageUrl` when cloud is enabled.

---

## App read/write map

| Screen / action | Path | Ops |
|-----------------|------|-----|
| Activate store | `stores/{id}` | set |
| Register device | `stores/{id}/devices/{id}` | set |
| Catalog list | `stores/{id}/products` | listen |
| Get product by scan | `stores/{id}/products/{code}` then `products/{code}` | get |
| Save product | `stores/{id}/products/{code}` | set |
| Cam scope load/save | `stores/{id}/settings/cameraScope` | get/set |
| Seed import | `products/*` | set |

Cart remains **on-device** until sale write is implemented.

---

## Console checklist

1. Create Firebase project  
2. Enable **Firestore** (production mode or test; use our rules)  
3. Enable **Storage** (optional, for photos)  
4. Android app: package `com.example.pasale_register`  
5. `flutterfire configure`  
6. Deploy rules: `firebase deploy --only firestore:rules,firestore:indexes`  
7. Optional: import `docs/sample_seed_products.json` into `products`  
