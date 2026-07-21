# Pasale Register Code Review — Detailed Analysis Report

**Date:** 2026-07-21  
**Investigator:** Explorer Agent  
**Scope:** Invoices, Cart, Products, and Catalog Modules  

---

## Executive Summary

A comprehensive, read-only code review of four primary modules in the **Pasale Register** application was performed. The investigation revealed several critical logic bugs, concurrency risks, memory leaks, performance bottlenecks, and security isolation concerns. Key issues include:
1. **Online payment accounting errors** and **inclusion of voided invoices** in totals (`store_invoice.dart`).
2. **Item merging on empty barcodes** and **lack of stock validation** in Cart (`cart_service.dart`).
3. **Non-atomic inventory deduction** and **silent error suppression** during checkout (`checkout_screen.dart`).
4. **Catastrophic query multiplication (N+1 GET requests)** inside Firestore `streamCatalog` (`real_firestore_service.dart`).
5. **Uncancelled StreamSubscriptions** leading to memory leaks (`inventory_management_screen.dart`).
6. **Listener leaks** in customer search `Autocomplete` widgets (`manual_invoice_screen.dart`, `checkout_screen.dart`).

---

## 1. Invoices Module

### Targeted Files
- `lib/models/store_invoice.dart`
- `lib/services/invoice_history_service.dart`
- `lib/services/invoice_ocr_service.dart`
- `lib/screens/invoices_list_screen.dart`
- `lib/screens/manual_invoice_screen.dart`
- `lib/utils/bill_formatter.dart`

---

### Key Findings

#### A. Logic Bugs & Accounting Errors
1. **Online Payment Classified as Credit / Paid Flag Mismatch**
   - **File & Line:** `lib/models/store_invoice.dart:63-65, 85-91, 225-230`
   - **Issue:** In `toMap()`, `isPaid` is calculated as `payment == InvoicePayment.cash`. If `payment` is `online`, `isPaid` becomes `false` in Firestore payload.
   - **Impact:** Online digital transactions (e.g. eSewa, Khalti, QR transfers) are saved with `'isPaid': false`. Furthermore, in `StoreInvoiceListX.totals`:
     ```dart
     if (inv.isCash) {
       cash += inv.total;
     } else {
       credit += inv.total;
     }
     ```
     Because `inv.isCash` checks `payment == InvoicePayment.cash`, `online` payments return `false` for `isCash` and are summed into `creditTotal`! This misreports paid digital sales as unpaid credit debt.

2. **Voided Invoices Included in Total Calculations**
   - **File & Line:** `lib/models/store_invoice.dart:220-236`
   - **Issue:** `StoreInvoiceListX.totals` iterates through all invoices in the list without checking `!inv.isVoided`.
   - **Impact:** Voided/cancelled sales continue to be added to `cashTotal`, `creditTotal`, and `count`, artificially inflating revenue reports and invoice counts.

3. **Millisecond Timestamp ID Collisions**
   - **File & Line:** `lib/models/store_invoice.dart:161, 187`
   - **Issue:** Invoice IDs are generated using `CART_${DateTime.now().millisecondsSinceEpoch}` and `MAN_${DateTime.now().millisecondsSinceEpoch}`.
   - **Impact:** If multiple checkouts occur rapidly or during fast offline sync across devices, identical millisecond timestamps cause document ID collisions in Firestore (`SetOptions(merge: true)`), causing one sale to overwrite another.

#### B. Code Quality & Maintainability
1. **Autocomplete Controller Listener Leak**
   - **File & Line:** `lib/screens/manual_invoice_screen.dart:242-244` & `lib/screens/checkout_screen.dart:517-519`
   - **Issue:** Inside `fieldViewBuilder`, `textEditingController.addListener(() { _phoneController.text = textEditingController.text; })` attaches a new listener every time the field rebuilds without removing previous listeners.
   - **Impact:** Causes duplicate event listeners, memory leaks, and multiple text updates on every keystroke.

2. **Silent Failure on Invoice History Persistence Errors**
   - **File & Line:** `lib/screens/manual_invoice_screen.dart:147-153` & `lib/screens/checkout_screen.dart:397-437`
   - **Issue:** In `checkout_screen.dart`, calls to `InvoiceHistoryService.add()` are wrapped inside `try { ... } catch (_) {}`.
   - **Impact:** If an exception occurs (e.g., local storage full or Firestore write failure), the exception is swallowed silently. The app wipes the cart and notifies the user "Checkout saved", but the invoice is completely lost.

#### C. Performance & Offline Sync
1. **Missing Retry Loop for Offline Invoices**
   - **File & Line:** `lib/services/invoice_history_service.dart:135-162`
   - **Issue:** Invoices created while offline are tagged with `isPendingSync: true` and saved to `SharedPreferences`. However, if the network request fails, `InvoiceHistoryService` does not maintain a retry queue or background sync mechanism to retry uploading pending invoices when network connectivity is restored.

---

## 2. Cart Module

### Targeted Files
- `lib/models/cart_item.dart`
- `lib/services/cart_service.dart`
- `lib/screens/checkout_screen.dart`

---

### Key Findings

#### A. Logic Bugs & Edge Cases
1. **Barcode Collision for Loose / Open / Unbarcoded Items**
   - **File & Line:** `lib/services/cart_service.dart:23, 36, 50` & `lib/screens/checkout_screen.dart:131, 680, 690, 705`
   - **Issue:** `CartService` matches cart items using `item.product.barcode == product.barcode`.
   - **Impact:** For loose items, produce, open service items, or custom products where `barcode` is an empty string `""` or `null`, adding a second distinct item matches the first item and increments its quantity instead of adding a new item.

2. **Stock Limit Validation Bypassed in Cart**
   - **File & Line:** `lib/services/cart_service.dart:25, 38`
   - **Issue:** `CartService.addProduct` and `incrementQuantity` check `quantity < 999` (magic number), but do NOT check `product.quantity` (available stock).
   - **Impact:** Cashiers can add 999 units to the cart even if physical stock is only 1 or 0, enabling selling out-of-stock items and generating negative inventory quantities.

3. **Floating Point Rounding Errors in Subtotal**
   - **File & Line:** `lib/services/cart_service.dart:18`
   - **Issue:** `totalPrice` sums items via floating-point multiplication: `sum + (item.product.sellingPrice * item.quantity)`.
   - **Impact:** Standard IEEE 754 floating point arithmetic introduces rounding artifacts (e.g., `10.10 + 20.20 = 30.300000000000004`), causing formatting discrepancies in receipts and payment gateways.

#### B. Concurrency & Data Safety
1. **Non-Atomic Stock Deduction in Checkout**
   - **File & Line:** `lib/screens/checkout_screen.dart:410-418`
   - **Issue:** Stock deduction reads existing quantity `await firestore.getProduct(...)`, calculates `newQty = existingProduct.quantity - qtySold`, and writes `saveProduct(...)`.
   - **Impact:** This read-modify-write pattern is **non-atomic**. If two terminals checkout simultaneously or stock is updated concurrently on another device, one update overwrites the other (lost update race condition).

2. **Direct Mutation of Cart Items**
   - **File & Line:** `lib/models/cart_item.dart:5` & `lib/services/cart_service.dart:9`
   - **Issue:** `CartItem.quantity` is a mutable field (`int quantity`). Although `CartService.items` returns `List.unmodifiable(_items)`, external code can still mutate `cartService.items[0].quantity = 50` directly, bypassing `CartService` state management and `notifyListeners()`.

3. **Lack of Offline Persistence for Active Cart**
   - **File & Line:** `lib/services/cart_service.dart:6`
   - **Issue:** Cart items are stored entirely in an in-memory list `List<CartItem> _items`.
   - **Impact:** If the POS app crashes, gets closed by Android OS memory management, or restarts, all active cart state is lost.

---

## 3. Products & Inventory Module

### Targeted Files
- `lib/models/product.dart`
- `lib/models/inventory_log.dart`
- `lib/screens/inventory_management_screen.dart`
- `lib/services/firestore_service.dart`
- `lib/services/real_firestore_service.dart`
- `lib/services/fake_firestore_service.dart`

---

### Key Findings

#### A. Performance Bottlenecks & Architectural Risks
1. **Catastrophic N+1 Global GET Queries in `streamCatalog`**
   - **File & Line:** `lib/services/real_firestore_service.dart:595-629`
   - **Issue:** Inside `streamCatalog`:
     ```dart
     return _productsCol(storeId).snapshots().asyncMap((storeSnap) async {
       final globalSnap = await _firestore.collection('products').get();
       if (businessId != null) {
         final masterSnap = await _businessCatalogCol(businessId).get();
       }
       ...
     });
     ```
   - **Impact:** Every single time any store product is modified or stock changes, `asyncMap` executes **two un-indexed full-collection `get()` requests** across the entire global products collection and business catalog. This causes massive network bandwidth consumption, high Firestore read billing costs, and severe UI lag.

2. **StreamSubscription Memory Leak in Inventory Management Screen**
   - **File & Line:** `lib/screens/inventory_management_screen.dart:36-45`
   - **Issue:** `locator<FirestoreService>().streamCatalog(storeId: storeId).listen(...)` is invoked in `_loadData()`, but the subscription object is never assigned to a variable or cancelled in `dispose()`.
   - **Impact:** Every time the user opens the inventory screen, a new stream listener is spawned and remains active indefinitely in memory, leading to memory leaks and unnecessary background processing.

#### B. Access Control & Data Safety
1. **Missing `storeId` Isolation Risk**
   - **File & Line:** `lib/services/real_firestore_service.dart:33-41, 535-540`
   - **Issue:** `_productsCol(String? storeId)` falls back to root `_firestore.collection('products')` if `storeId` is null or empty.
   - **Impact:** If `saveProduct` is called with a product that has `storeId == null`, the product is written into the global public catalog, making private store products visible to all users across the entire system.

2. **Non-Atomic Customer Credit Balance Updates**
   - **File & Line:** `lib/services/real_firestore_service.dart:767-796, 870-896`
   - **Issue:** In `saveInvoice` and `saveDeposit`, customer credit balance is updated by reading `prevCredit = existing.data()?['creditBalance']`, computing `prevCredit + delta`, and setting document data.
   - **Impact:** Under concurrent credit purchases or payment deposits, lost update race conditions occur. The update should instead use Firestore atomic transactions or `FieldValue.increment(delta)`.

3. **Stale `markup` Field in `Product`**
   - **File & Line:** `lib/models/product.dart:7, 38-66`
   - **Issue:** `markup` is stored as a fixed `double` property on `Product`. Calling `copyWith(sellingPrice: ...)` does not update `markup` unless explicitly calculated and supplied.

4. **Infinite Loading State & Null Safety Assertion Failure**
   - **File & Line:** `lib/screens/inventory_management_screen.dart:30, 87`
   - **Issue:** If `storeId == null` in `_loadData()`, the method returns early without setting `_loading = false`. The screen remains stuck on a `CircularProgressIndicator`. Line 87 passes `_storeId!` with force-unwrap, which crashes if null.

---

## 4. Catalog Module

### Targeted Files
- `lib/services/catalog_template_service.dart`
- `lib/screens/catalog_screen.dart`

---

### Key Findings

#### A. Logic Bugs & Data Integrity
1. **Unbatched Parallel Writes in Template Cloning**
   - **File & Line:** `lib/services/catalog_template_service.dart:18-25`
   - **Issue:** `cloneTemplate` uses `Future.wait(products.map((p) => firestore.saveProduct(...)))` to perform parallel individual network saves.
   - **Impact:** Lacks transactionality (`WriteBatch`). If network connection fails midway, the store catalog is left partially seeded with missing items and no rollback mechanism.

2. **Service Cost Price Markup Edge Case**
   - **File & Line:** `lib/services/catalog_template_service.dart:84-86`
   - **Issue:** In `_p`, `markup` is computed as `sellingPrice > 0 && costPrice > 0 ? ((sellingPrice - costPrice) / costPrice) * 100 : 0`.
   - **Impact:** For service products (e.g. Haircuts in Salon template where `costPrice` is 0), `markup` defaults to `0` instead of 100% or `N/A`, producing incorrect profitability reports.

3. **Barcode-as-ID Collision Hazard**
   - **File & Line:** `lib/services/catalog_template_service.dart:79`
   - **Issue:** `id: barcode` sets product document ID directly to string literal barcodes (e.g. `'barcode_rice'`).
   - **Impact:** Re-running template seeding or adding products across stores with shared IDs risks overwriting existing product records.

#### B. UI & Rendering Safety
1. **Unhandled FileImage File System Exception**
   - **File & Line:** `lib/screens/catalog_screen.dart:180-184`
   - **Issue:** Renders product images using `FileImage(File(product.imagePath!))` without verifying whether the file exists on the local device filesystem (`f.existsSync()`).
   - **Impact:** If the image file was deleted, moved, or corrupted, Flutter throws an unhandled image provider exception resulting in broken UI elements.

---

## Summary Matrix of Critical Findings

| Module | Location | Severity | Category | Description |
|---|---|---|---|---|
| Invoices | `store_invoice.dart:63` | **High** | Logic Bug | `online` payment sets `isPaid: false` and adds to credit total |
| Invoices | `store_invoice.dart:220` | **High** | Accounting | Voided invoices included in `totals` revenue calculation |
| Invoices | `manual_invoice_screen.dart:242` | **Medium** | Memory Leak | `Autocomplete` text controller listener leak |
| Cart | `cart_service.dart:23` | **High** | Logic Bug | Empty barcode `""` matches all unbarcoded items together |
| Cart | `cart_service.dart:25` | **Medium** | Validation | Stock availability ignored when adding items to cart |
| Cart | `checkout_screen.dart:410` | **High** | Concurrency | Non-atomic read-modify-write stock deduction |
| Products | `real_firestore_service.dart:595` | **Critical** | Performance | `streamCatalog` performs full global `get()` queries on every snapshot update |
| Products | `inventory_management_screen.dart:36` | **High** | Memory Leak | `streamCatalog().listen()` never cancelled in `dispose()` |
| Products | `real_firestore_service.dart:777` | **High** | Data Safety | Non-atomic customer credit updates risk lost updates |
| Catalog | `catalog_template_service.dart:18` | **Medium** | Integrity | Template cloning uses unbatched parallel writes without rollback |
| Catalog | `catalog_screen.dart:181` | **Medium** | UI Safety | `FileImage` loading missing file existence check |

---

## Verification & Remediation Recommendations

1. **Invoices Module:**
   - Update `store_invoice.dart` `isCash` / `isPaid` logic to properly classify `online` as paid revenue rather than credit.
   - Filter out `isVoided == true` invoices inside `StoreInvoiceListX.totals`.
   - Use UUIDs or server timestamps + random salt for unique invoice IDs (`UUID.v4()`).
   - Clean up listeners in `Autocomplete` builders.

2. **Cart Module:**
   - Match cart items by `product.id` rather than `product.barcode` (or fallback to ID if barcode is empty).
   - Validate `item.quantity < product.quantity` inside `CartService.addProduct`.
   - Implement Firestore atomic transactions or field increments for stock deduction during checkout.

3. **Products Module:**
   - Refactor `streamCatalog` in `real_firestore_service.dart` to rely on reactive Firestore collection queries instead of performing manual `get()` fetches inside `asyncMap`.
   - Maintain `StreamSubscription` reference in `_InventoryManagementScreenState` and cancel it in `dispose()`.
   - Replace manual `creditBalance` arithmetic in Firestore updates with `FieldValue.increment(delta)`.

4. **Catalog Module:**
   - Use Firestore `WriteBatch` in `CatalogTemplateService.cloneTemplate` for atomic catalog insertion.
   - Add `File(path).existsSync()` check before rendering `FileImage` in `catalog_screen.dart`.
