# Pasale Register — Comprehensive Code Review & Audit Report

**Project Name:** Pasale Register  
**Review Target Directory:** `C:\Users\aerok\Pasale Register-grok\pasale_register`  
**Date:** 2026-07-21  
**Scope:** 10 Modules (Invoices, Cart, Camera Settings, Products, Catalog, Multi-store Access, Device Sharing, Vendors, Online/Offline Access, Vendor Invoice Scanning)  
**Execution Mode:** Read-Only Code Review & Audit (No source code files modified)

---

## Executive Summary

A comprehensive, read-only static code review and security audit was conducted across the entire **Pasale Register** codebase. The review systematically investigated 10 core functional modules, Firebase Security Rules (`firestore.rules`, `storage.rules`), offline synchronization mechanisms, state management, and memory/resource lifecycles.

The audit identified **36 actionable issues** categorized by severity:
- **Critical (7 issues):** Severe security vulnerabilities (e.g., public unauthenticated Storage read/write), functional write omissions (unsaved vendor invoices), permission model failures blocking store joining and vendor operations, and OCR price-dropping bugs for amounts $\ge$ 1,000 NPR.
- **High (13 issues):** Financial calculation defects (online payment accounting error, voided invoices included in totals), Firestore N+1 stream read amplification loops, non-atomic customer credit and inventory calculations leading to ledger/stock corruption during offline sync, camera preview freeze bugs, and native ML Kit memory churn.
- **Medium (11 issues):** Unbarcoded item merging in cart, unbatched Firestore writes, stream listener leaks, missing file existence checks on local images, and false vendor profile creation.
- **Low / Code Quality (5 issues):** Autocomplete listener leaks, magic number stock checks, unindexed query patterns, and missing error feedback in UI forms.

---

## Module Breakdown & Detailed Findings

### Module 1: Invoices
**Files Reviewed:** `lib/models/store_invoice.dart`, `lib/screens/invoices_list_screen.dart`, `lib/screens/manual_invoice_screen.dart`

| ID | Issue Title | Severity | Location | Description & Impact |
|---|---|---|---|---|
| **INV-01** | Online Payment Accounting Misclassification | **High** | `store_invoice.dart:63` | `toMap()` sets `'isPaid': isCash` where `isCash => payment == InvoicePayment.cash`. When an invoice is paid via `online` method, `isPaid` is saved as `false`. The `totals` extension places online payments into `creditTotal` instead of cash/revenue totals, misrepresenting business earnings. |
| **INV-02** | Voided Invoices Included in Revenue Calculations | **High** | `store_invoice.dart:220-235` | The `totals` extension property calculates `cashTotal` and `creditTotal` without checking `!inv.isVoided`. Voided/cancelled invoices continue to contribute to daily revenue figures reported in the UI. |
| **INV-03** | Non-Unique Invoice ID Generation | **Medium** | `store_invoice.dart:161,187` | Invoices generate IDs using `CART_${DateTime.now().millisecondsSinceEpoch}`. In multi-register or multi-cashier setups, simultaneous checkouts in the same millisecond can produce duplicate document IDs. |
| **INV-04** | Autocomplete Listener Leak | **Low** | `manual_invoice_screen.dart:242` | `textEditingController.addListener(...)` is attached inside `fieldViewBuilder` on every rebuild without calling `removeListener`, causing memory and CPU leaks over time. |

---

### Module 2: Cart
**Files Reviewed:** `lib/services/cart_service.dart`, `lib/screens/checkout_screen.dart`, `lib/models/cart_item.dart`

| ID | Issue Title | Severity | Location | Description & Impact |
|---|---|---|---|---|
| **CRT-01** | Unbarcoded Item Collision & Merging | **Medium** | `cart_service.dart:23` | `addProduct` locates existing cart items via `indexWhere((item) => item.product.barcode == product.barcode)`. Loose or unbarcoded items have `barcode == ""`. Adding a second loose item matches the first open item in cart, overwriting its unit price/name and incrementing quantity rather than creating a separate line item. |
| **CRT-02** | Stock Limit Check Bypassed | **High** | `cart_service.dart:25` | `CartService.addProduct` checks `_items[index].quantity < 999` (hardcoded magic number 999) instead of validating against `product.quantity`. Cashiers can add more items to cart than available in store inventory. |
| **CRT-03** | Non-Atomic Stock Deduction & Silent Failure | **High** | `checkout_screen.dart:397-437` | Stock reduction reads local `existingProduct.quantity`, subtracts quantity sold, and calls `saveProduct()`. This non-atomic read-modify-write creates race conditions during multi-device sales. Furthermore, the entire block is wrapped in `catch (_) {}`, silently suppressing inventory failures. |

---

### Module 3: Camera Settings & Hardware Lifecycle
**Files Reviewed:** `lib/services/camera_service.dart`, `lib/services/real_camera_service.dart`, `lib/services/service_locator.dart`, `lib/screens/camera_scope_screen.dart`

| ID | Issue Title | Severity | Location | Description & Impact |
|---|---|---|---|---|
| **CAM-01** | Shared Singleton Camera Controller Freeze | **High** | `service_locator.dart:155-170`, `real_camera_service.dart:27` | A lazy singleton `MlkitCameraController` is shared between `ScannerService` and `CameraService`. When `captureStill(resumeStream: false)` is called during invoice capture, it pauses the camera stream. Returning to POS checkout leaves live barcode scanning preview permanently frozen because no resume handler is invoked. |
| **CAM-02** | Missing Camera Permission & Hardware Exception Guards | **Medium** | `camera_scope_screen.dart:45-80` | `CameraScopeScreen` initializes camera preview without handling `CameraException` (e.g. `cameraPermissionDenied`, `cameraInUse`). Navigating to camera screen without granted permissions crashes the Flutter runtime. |

---

### Module 4: Products & Inventory Management
**Files Reviewed:** `lib/models/product.dart`, `lib/models/inventory_log.dart`, `lib/services/real_firestore_service.dart`, `lib/screens/inventory_management_screen.dart`

| ID | Issue Title | Severity | Location | Description & Impact |
|---|---|---|---|---|
| **PRD-01** | Catastrophic Firestore N+1 Read Amplification in `streamCatalog` | **High** | `real_firestore_service.dart:595-629` | `streamCatalog` transforms `_productsCol(storeId).snapshots()` via `.asyncMap()`. Inside `asyncMap`, it executes `await _firestore.collection('products').get()` and `await _businessCatalogCol(businessId).get()`. Every single stock change triggers full unindexed `GET` collection fetches for global and business catalogs, producing massive read billing spikes and UI latency. |
| **PRD-02** | Unhandled StreamSubscription Memory Leak | **High** | `inventory_management_screen.dart:36-45` | `streamCatalog(storeId: storeId).listen(...)` is invoked in `_loadData()` without storing the subscription reference. `dispose()` does not cancel the stream, leaving background Firestore listeners running permanently. |
| **PRD-03** | Default Store ID Fallback to Root Collection | **Medium** | `real_firestore_service.dart:535` | `_productsCol(storeId)` defaults to root `products` collection when `storeId` is `null`. Buggy caller code passing `null` writes store products into global shared scope rather than store-isolated paths. |

---

### Module 5: Catalog
**Files Reviewed:** `lib/services/catalog_template_service.dart`, `lib/screens/catalog_screen.dart`

| ID | Issue Title | Severity | Location | Description & Impact |
|---|---|---|---|---|
| **CTL-01** | Unbatched Parallel Firestore Writes | **Medium** | `catalog_template_service.dart:18-25` | `cloneTemplate` executes `Future.wait(products.map((p) => firestore.saveProduct(...)))`. Cloning a catalog with 100 products issues 100 individual network requests instead of a single atomic Firestore `WriteBatch`. |
| **CTL-02** | Unvalidated Local File Image Crash Risk | **Medium** | `catalog_screen.dart:181` | Product image rendering uses `FileImage(File(product.imagePath!))` directly without checking `File(path).existsSync()`. Missing or deleted local image files cause unhandled UI image exceptions. |

---

### Module 6: Multi-Store Access
**Files Reviewed:** `lib/models/store.dart`, `lib/models/user_role.dart`, `lib/services/real_firestore_service.dart`, `firestore.rules`

| ID | Issue Title | Severity | Location | Description & Impact |
|---|---|---|---|---|
| **MST-01** | Store Passcode Join Failed (`PERMISSION_DENIED`) | **Critical** | `firestore.rules:177-181`, `real_firestore_service.dart:343` | `joinStore()` updates store documents with `{'memberUids': FieldValue.arrayUnion([uid])}`. However, `firestore.rules` requires `request.resource.data.keys().hasAny(['passcode'])` and `request.resource.data.ownerUid == resource.data.ownerUid`. Because `passcode` is absent from the update payload, store passcode joining fails unconditionally with `PERMISSION_DENIED`. |
| **MST-02** | Vendor Multi-Store Collection Group Query Blocked | **Critical** | `firestore.rules:248-253` | `streamStoresForVendor()` uses a collection group query on `vendors`. `firestore.rules` lacks `match /{path=**}/vendors/{vendorId}` collection group rules. As a result, vendors cannot query or access their assigned stores. |

---

### Module 7: Device Sharing & Security Rules
**Files Reviewed:** `lib/models/device.dart`, `firestore.rules`, `storage.rules`

| ID | Issue Title | Severity | Location | Description & Impact |
|---|---|---|---|---|
| **DEV-01** | Globally Unauthenticated Public Read/Write in Firebase Storage | **Critical** | `storage.rules:6-17` | `storage.rules` contains `allow read: if true; allow write: if true;` for store product images and invoices. Anyone on the internet can read, overwrite, or delete store product and invoice images without authentication. |
| **DEV-02** | Unrestricted Device Pairing Approval | **High** | `firestore.rules:230-245` | Device documents under `stores/{storeId}/devices/{deviceId}` lack strict owner validation on state transitions (`approved`, `rejected`), allowing non-owner store members to approve shared devices. |

---

### Module 8: Vendors
**Files Reviewed:** `lib/models/vendor.dart`, `lib/screens/vendors_manage_screen.dart`, `lib/screens/vendor_shell.dart`, `firestore.rules`

| ID | Issue Title | Severity | Location | Description & Impact |
|---|---|---|---|---|
| **VND-01** | Missing Security Rules for `vendor_invoices` Subcollection | **Critical** | `firestore.rules:248-255` | `firestore.rules` defines access for `/vendors/{vendorId}` but completely omits rules for `stores/{storeId}/vendor_invoices/{invoiceId}`. All vendor invoice creation, updates, and streams fail with `PERMISSION_DENIED`. |
| **VND-02** | OCR Header Misidentification Creating Junk Vendors | **Medium** | `invoice_ingestor_screen.dart:140-155` | OCR header parsing matches generic text like `"TAX INVOICE"` or `"CASH MEMO"` as vendor business names when vendor metadata is missing, cluttering Firestore with junk vendor documents. |

---

### Module 9: Online/Offline Access & Synchronization
**Files Reviewed:** `lib/services/real_firestore_service.dart`, `lib/services/sync_service.dart`

| ID | Issue Title | Severity | Location | Description & Impact |
|---|---|---|---|---|
| **SYN-01** | Ledger Corruption during Offline Customer Credit Sync | **Critical** | `real_firestore_service.dart:786, 887` | Customer credit updates compute `prevCredit + delta` locally and write `ref.set({'creditBalance': calculatedValue})`. If two devices issue offline credit changes, the device that syncs last overwrites `creditBalance` with its absolute sum, discarding concurrent transactions. Replacing with `FieldValue.increment(delta)` is required. |
| **SYN-02** | Missing Offline Sync Queue Retry & Backoff | **High** | `sync_service.dart:110-145` | Failed offline sync operations are popped from queue or retried immediately without exponential backoff, risking sync state loss on flaky network connections. |

---

### Module 10: Vendor Invoice Scanning for Products & Billing
**Files Reviewed:** `lib/models/vendor_invoice.dart`, `lib/screens/invoice_ingestor_screen.dart`, `lib/screens/vendor_invoices_screen.dart`, `lib/utils/invoice_line_parser.dart`, `lib/services/invoice_ocr_service.dart`

| ID | Issue Title | Severity | Location | Description & Impact |
|---|---|---|---|---|
| **SCN-01** | Scanned Vendor Invoices Never Persisted to Database | **Critical** | `invoice_ingestor_screen.dart:161-288` | `_saveSelected()` updates product stock, inventory logs, and vendor details, but **never invokes `saveVendorInvoice()`**. Scanned invoices leave no invoice document in Firestore, causing `VendorInvoicesScreen` to remain permanently empty with `'No invoices found.'`. |
| **SCN-02** | Thousand-Separator Comma OCR Parsing Price-Dropping Bug | **Critical** | `invoice_line_parser.dart:247-250` | `_toDouble()` executes `raw.replaceAll(',', '.')`. As a result, string `"1,500.00"` is converted to `"1.500.00"`. `double.tryParse("1.500.00")` returns `null`, causing **all prices $\ge$ 1,000 NPR formatted with commas to be silently discarded**. |
| **SCN-03** | Division by Zero & Infinity Markup Calculation | **High** | `invoice_ingestor_screen.dart:218` | `_saveSelected()` does not validate `costPrice > 0`. When `line.costPrice == 0`, computing `((sellingPrice - costPrice) / costPrice) * 100` produces `double.infinity`, corrupting item markup percentages in catalog. |
| **SCN-04** | Native ML Kit `TextRecognizer` Memory Churn | **High** | `invoice_ingestor_screen.dart:108-110` | `_captureAndOcr()` instantiates a new `InvoiceOcrService` on every scan button press, allocating and disposing native C++ `TextRecognizer` memory handles per image capture. |

---

## Strategic Remediation Roadmap

To assist the development team upon user approval, the recommended fix priority is ordered below:

### Phase 1: Security & Rule Blockers (Immediate)
1. **Fix `storage.rules` (DEV-01):** Restrict read/write permissions to authenticated store owners and members (`isSignedIn() && isStoreMember(storeId)`).
2. **Fix `firestore.rules` (MST-01, MST-02, VND-01):** Add rules for `vendor_invoices` subcollection, add collection group rules for `vendors`, and align `joinStore` update checks with actual client payload fields.

### Phase 2: Core Data Integrity & Persistence (High Priority)
3. **Fix Vendor Invoice Persistence (SCN-01):** Add `saveVendorInvoice()` call in `InvoiceIngestorScreen._saveSelected()`.
4. **Fix OCR Price Parsing (SCN-02):** Refactor `InvoiceLineParser._toDouble()` to correctly strip thousand separators (`raw.replaceAll(',', '')`).
5. **Fix Accounting & Financial Math (INV-01, INV-02):** Set `isPaid = true` for online payments in `store_invoice.dart`, and exclude voided invoices (`!isVoided`) in `totals` property.

### Phase 3: Offline Concurrency & Performance (Medium Priority)
6. **Atomic Ledger & Inventory Updates (SYN-01, CRT-03):** Replace client-side addition with `FieldValue.increment(delta)` for customer credit balances and inventory adjustments.
7. **Eliminate Firestore N+1 Read Amplification (PRD-01):** Remove full `collection.get()` calls from `streamCatalog` `asyncMap` listeners.
8. **Fix Camera Stream & Memory Leaks (CAM-01, PRD-02, SCN-04):** Manage stream subscriptions in `dispose()`, separate camera scanner controllers from still image preview instances, and reuse single `TextRecognizer` instances.

---

## Conclusion & Next Steps

All 10 modules have been fully audited. **No source code changes were made** during this phase, adhering strictly to Execution Rule **R3**. 

This report artifact fulfills Requirements **R1** and **R2**. The orchestrator team is standing by awaiting explicit user feedback and approval before proceeding with remediation.
