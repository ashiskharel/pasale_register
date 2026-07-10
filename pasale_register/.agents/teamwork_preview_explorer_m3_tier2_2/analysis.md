# Milestone 3: Tier 2 (Boundary & Corner Cases) Test Cases Design Strategy

## Executive Summary
This analysis outlines a robust design strategy for implementing 30 independent E2E boundary, corner, and error test cases (5 per feature across 6 features) for the Pasale Register application. It details the required updates for the existing stub screens (`pasale_register/lib/screens/`) to handle these edge cases gracefully, introduces specific error display validations, and addresses core integration concerns including duplicate keys, loading states, and async flow racing.

---

## 1. Boundary, Corner, and Error Test Cases (30 Cases)

### Feature 1: Device Activation & Tracking
* **F1_T6: Store activation fails on whitespace-only Store ID and Name**
  * *Description*: Validates that input fields containing only whitespaces are rejected.
  * *Inputs*: Store ID = `'   '`, Store Name = `'   '`.
  * *Actions*: Enter inputs, tap "Activate Store".
  * *Expected Output*: `_status` display shows `Error: Store ID and Name required`.
* **F1_T7: Device registration fails on whitespace-only Store ID and Device ID**
  * *Description*: Validates that device registration fields containing only whitespaces are rejected.
  * *Inputs*: Store ID = `'   '`, Device ID = `'   '`.
  * *Actions*: Enter inputs, tap "Register Device".
  * *Expected Output*: `_status` display shows `Error: Store ID and Device ID required`.
* **F1_T8: Device registration with invalid JSON metadata displays validation error**
  * *Description*: Ensures that metadata containing invalid JSON format returns a descriptive error rather than silently failing or falling back.
  * *Inputs*: Store ID = `'store_abc'`, Device ID = `'device_123'`, Metadata = `'{"os": "Android", '` (broken syntax).
  * *Actions*: Enter inputs, tap "Register Device".
  * *Expected Output*: `_status` display shows `Error: Invalid JSON format`.
* **F1_T9: Store activation with extreme input string lengths**
  * *Description*: Test app limits and UI resilience with a very long store name (stress test).
  * *Inputs*: Store ID = `'store_long'`, Store Name = `'A' * 250` (250 characters).
  * *Actions*: Enter inputs, tap "Activate Store".
  * *Expected Output*: Database records the long store name correctly, status shows success.
* **F1_T10: Device registration with empty metadata succeeds with empty map**
  * *Description*: Verifies that metadata is optional and defaults to an empty JSON structure if left blank.
  * *Inputs*: Store ID = `'store_abc'`, Device ID = `'device_123'`, Metadata = `''`.
  * *Actions*: Enter inputs, tap "Register Device".
  * *Expected Output*: Database records device with empty metadata `{}`; status shows `Device Registered Successfully: device_123`.

### Feature 2: Firestore Product Catalog & Seeding
* **F2_T6: Add product fails on whitespace-only name and barcode**
  * *Description*: Ensures product catalog forms reject whitespace-only fields.
  * *Inputs*: Name = `'   '`, Barcode = `'   '`.
  * *Actions*: Toggle form, enter inputs, tap "Save Product".
  * *Expected Output*: `_status` display shows `Error: Name and Barcode required`.
* **F2_T7: Add product fails on negative cost price or negative markup**
  * *Description*: Rejects negative pricing inputs which are mathematically invalid.
  * *Inputs*: Name = `'Apple'`, Barcode = `'123'`, Cost Price = `'-10.0'`, Markup = `'-5.0'`.
  * *Actions*: Toggle form, enter inputs, tap "Save Product".
  * *Expected Output*: `_status` display shows `Error: Cost price and markup must be non-negative`.
* **F2_T8: Add product fails on invalid numeric inputs (alphabetic letters)**
  * *Description*: Verifies that inputs containing letters are detected and rejected as invalid formats rather than quietly defaulting to `0.0`.
  * *Inputs*: Name = `'Apple'`, Barcode = `'123'`, Selling Price = `'abc'`, Cost Price = `'def'`.
  * *Actions*: Toggle form, enter inputs, tap "Save Product".
  * *Expected Output*: `_status` display shows `Error: Invalid number format`.
* **F2_T9: Add product with duplicate barcode overwrites product fields**
  * *Description*: Confirms that saving a product with an existing barcode updates the record successfully in the database (idempotence).
  * *Inputs*: Product A (`name: 'Soda', barcode: '555', price: 50`), then Product B (`name: 'Diet Soda', barcode: '555', price: 55`).
  * *Actions*: Save Product A, then save Product B with same barcode.
  * *Expected Output*: Catalog reflects updated product name `'Diet Soda'` and price `55.0`.
* **F2_T10: Search catalog with special characters handles query safely without crash**
  * *Description*: Ensures the catalog filter stream survives wildcard and special character search inputs.
  * *Inputs*: Search query = `'%@#$*'`
  * *Actions*: Type query in search field.
  * *Expected Output*: Stream finishes loading; UI displays empty list (no match) and doesn't throw errors or crash.

### Feature 3: Cart Management & Calculations
* **F3_T6: Manual barcode add fails and displays error on empty barcode input**
  * *Description*: Tapping the add button on an empty barcode input should alert the user.
  * *Inputs*: Manual barcode input = `''`.
  * *Actions*: Tap "Add" button on checkout screen.
  * *Expected Output*: `_status` display shows `Error: Enter barcode`.
* **F3_T7: Manual barcode add shows specific error for non-existent product barcode**
  * *Description*: Entering a barcode that does not exist in the Firestore database displays a clear error.
  * *Inputs*: Manual barcode input = `'999999'`.
  * *Actions*: Tap "Add" button on checkout screen.
  * *Expected Output*: `_status` display shows `Product not found: 999999`.
* **F3_T8: Cart total correctly updates when incrementing quantity beyond 10 items**
  * *Description*: Ensures bulk increments do not trigger arithmetic or total calculation overflows.
  * *Inputs*: 1 product added with selling price `100.0`.
  * *Actions*: Tap the increment button 10 times.
  * *Expected Output*: Quantity text shows `11` and total price shows `Cart Total: Rs. 1100.0`.
* **F3_T9: Decrementing quantity of a product with quantity 1 removes it from list and updates total to 0**
  * *Description*: Edge check that quantity of 1 transitions to deletion upon decrement.
  * *Inputs*: 1 product (price `50.0`) in cart.
  * *Actions*: Tap decrement button.
  * *Expected Output*: Cart list is empty, product name is no longer found, and total is `Cart Total: Rs. 0.0`.
* **F3_T10: Multiple free items (price 0.0) in cart are listed correctly with total Rs. 0.0**
  * *Description*: Verifies that adding multiple free products is tracked correctly without breaking subtotal calculations.
  * *Inputs*: Product A (`price: 0.0`), Product B (`price: 0.0`).
  * *Actions*: Add both to cart.
  * *Expected Output*: Cart lists both items; total displays `Cart Total: Rs. 0.0`.

### Feature 4: Paid/Credit & Receipt Sharing
* **F4_T6: Share receipt with empty cart displays validation error**
  * *Description*: Block sharing receipts for empty checkouts.
  * *Inputs*: Empty cart, phone number = `'9841000000'`.
  * *Actions*: Tap "Share Receipt".
  * *Expected Output*: `_status` display shows `Error: Cart is empty`.
* **F4_T7: Share receipt with invalid phone format displays error**
  * *Description*: Validates Nepalese mobile number pattern or character validation.
  * *Inputs*: Cart with 1 item, phone number = `'abc'` or `'123'`.
  * *Actions*: Tap "Share Receipt".
  * *Expected Output*: `_status` display shows `Error: Invalid phone number format`.
* **F4_T8: Checkout with empty cart displays validation error**
  * *Description*: Prevents finalizing checkouts when no products are present.
  * *Inputs*: Empty cart.
  * *Actions*: Tap "Checkout" button.
  * *Expected Output*: `_status` display shows `Error: Cart is empty`.
* **F4_T9: Share receipt before checkout displays status "Pending" in receipt**
  * *Description*: Verifies receipt metadata state when sharing an active cart that hasn't finalized checkout.
  * *Inputs*: Cart with 1 item (Milk, price `50.0`), phone = `'9841000000'`.
  * *Actions*: Tap "Share Receipt" without tapping "Checkout".
  * *Expected Output*: Shared receipt text contains `'Status: Pending'`.
* **F4_T10: Share receipt after checkout displays status "Completed" in receipt**
  * *Description*: Verifies receipt metadata state when sharing a cart that has finalized checkout.
  * *Inputs*: Cart with 1 item (Milk, price `50.0`), phone = `'9841000000'`.
  * *Actions*: Tap "Checkout", then tap "Share Receipt".
  * *Expected Output*: Shared receipt text contains `'Status: Completed'`.

### Feature 5: Barcode Scanner & Matching
* **F5_T6: Scanner returns null (cancelled scan) changes status to "Scan cancelled" safely**
  * *Description*: Ensures the application handles cancellation gracefully without modification to cart.
  * *Inputs*: Mock scanner returning `null` on scan trigger.
  * *Actions*: Tap "Scan Barcode", simulate scan cancellation.
  * *Expected Output*: `_status` display shows `Scan cancelled`, cart count/total remains unchanged.
* **F5_T7: Scanning barcode with leading/trailing whitespaces matches trimmed barcode**
  * *Description*: Correctly matches database barcode even if barcode contains surrounding whitespace.
  * *Inputs*: Database barcode = `'888'`. Scanned barcode = `'  888  '`.
  * *Actions*: Tap "Scan Barcode", simulate scan.
  * *Expected Output*: Product added to cart successfully.
* **F5_T8: Rapid multiple scans of same barcode increases quantity sequentially**
  * *Description*: Tests async event debouncing and registration under consecutive scans.
  * *Inputs*: Barcode = `'888'`.
  * *Actions*: Trigger scan twice rapidly.
  * *Expected Output*: Cart quantity increases to `2`, total price updates to double, scanner feedback triggers twice.
* **F5_T9: Scanner returns empty barcode string shows scan error**
  * *Description*: Prevents looking up or processing empty string inputs from scanner.
  * *Inputs*: Scanner returns `""`.
  * *Actions*: Tap "Scan Barcode", simulate scan.
  * *Expected Output*: `_status` display shows `Scan error: Empty barcode`.
* **F5_T10: Scanner service throws exception is caught and displayed in status**
  * *Description*: Verifies robustness against low-level hardware or camera exceptions.
  * *Inputs*: Mock scanner throws `'Camera error description'`.
  * *Actions*: Tap "Scan Barcode".
  * *Expected Output*: `_status` display shows `Scan error: Camera error description`.

### Feature 6: Vendor Invoice Ingestor & Markup
* **F6_T6: Invoice photo capture cancellation shows cancelled message**
  * *Description*: Ensures cancellation of photo capture is handled gracefully.
  * *Inputs*: Camera service returns `null`.
  * *Actions*: Tap "Capture Invoice Photo", simulate cancellation.
  * *Expected Output*: `_status` display shows `Photo capture cancelled`.
* **F6_T7: Ingestor saves product successfully when all inputs are correct (including photo)**
  * *Description*: Full success flow validation for photo capture + inputs.
  * *Inputs*: Barcode = `'inv_001'`, Name = `'Apple'`, Cost = `100.0`, Markup = `25.0`, Photo = `'/mock/path/to/invoice.jpg'`.
  * *Actions*: Capture photo, enter inputs, tap "Save Ingested Product".
  * *Expected Output*: `_status` shows `Invoice product saved successfully`, database contains correct product.
* **F6_T8: Ingestor save fails when no photo has been captured**
  * *Description*: Ensures image capture is a hard constraint before database write.
  * *Inputs*: Barcode = `'inv_001'`, Name = `'Apple'`, Cost = `100.0`, Markup = `25.0`, Photo = `''` (not captured).
  * *Actions*: Tap "Save Ingested Product".
  * *Expected Output*: `_status` shows `Error: Capture invoice photo first`.
* **F6_T9: Ingestor validation fails on negative cost price or negative markup**
  * *Description*: Validates numerical boundaries on ingestor screen fields.
  * *Inputs*: Barcode = `'inv_001'`, Name = `'Apple'`, Cost = `'-10.0'` or Markup = `'-5.0'`.
  * *Actions*: Tap "Save Ingested Product".
  * *Expected Output*: `_status` shows `Error: Cost price and markup must be non-negative`.
* **F6_T10: Ingestor calculator handles extremely large inputs without crashing**
  * *Description*: Boundary verification of calculation accuracy with large integer values.
  * *Inputs*: Cost = `'999999999'`, Markup = `'500'`.
  * *Actions*: Enter inputs, check calculated selling price display.
  * *Expected Output*: UI displays: `Calculated Selling Price: Rs. 5999999994.0` (or appropriate big number) and doesn't crash.

---

## 2. Screen & Validation Updates Checklist

To support the above test cases, the stub screens require the following updates:

### Activation Screen (`activation_screen.dart`)
1. **Trim Fields**: Trim user inputs using `.trim()` on `storeId` and `storeName`.
2. **Metadata JSON Format Validation**:
   * Replace line 54-60 parser block with structured try-catch check:
     ```dart
     if (metadataStr.isNotEmpty) {
       try {
         metadata = jsonDecode(metadataStr) as Map<String, dynamic>;
       } catch (e) {
         setState(() {
           _status = 'Error: Invalid JSON format';
         });
         return;
       }
     }
     ```
3. **Whitespace validation check**: Update line 25 to check `storeId.trim().isEmpty || storeName.trim().isEmpty`.

### Catalog Screen (`catalog_screen.dart`)
1. **Empty/Whitespace Check**: Validate name and barcode using `.trim()`.
2. **Numeric Validation**:
   * Show `Error: Invalid number format` if `double.tryParse` fails on non-empty numeric inputs (selling price, cost price, markup).
3. **Non-Negative Validation**:
   * Verify parsed numbers: `if (sellingPrice < 0 || costPrice < 0 || markup < 0)` -> set status `Error: Cost price and markup must be non-negative`.
4. **Unique Row Keys in ListView**:
   * Replace ListTile item builder in line 175 with:
     ```dart
     return ListTile(
       key: ValueKey('catalog_item_${product.barcode}'),
       title: Text(product.name),
       ...
     ```

### Checkout Screen (`checkout_screen.dart`)
1. **Cart Empty Checkout Block**: In `_checkout()`, set `_status = 'Error: Cart is empty'` if `_cart.isEmpty`.
2. **Empty Cart Share Receipt Block**: In `_shareReceipt()`, set `_status = 'Error: Cart is empty'` if `_cart.isEmpty` before phone checking.
3. **Empty Barcode Input Warning**: In `_addBarcodeToCart()`, if `barcode.trim().isEmpty`, set `_status = 'Error: Enter barcode'`.
4. **Phone Number Length and Format Validation**:
   * Validate phone input against standard regex or simple length constraints (e.g. Nepali number starts with 9 and has 10 digits):
     ```dart
     final phone = _phoneController.text.trim();
     final regex = RegExp(r'^9[78]\d{8}$'); // Example Nepali pattern
     if (!regex.hasMatch(phone)) {
       setState(() {
         _status = 'Error: Invalid phone number format';
       });
       return;
     }
     ```
5. **Unique ListView Row & Button Keys**:
   * Currently, increment/decrement button keys are duplicated (`AppKeys.decrementQtyButton`, `AppKeys.incrementQtyButton`) across all rows.
   * Update keys dynamically in the `ListView.builder`:
     * Item row: `key: ValueKey('cart_item_${item.product.barcode}')`
     * Decrement button: `key: ValueKey('decrement_${item.product.barcode}')`
     * Increment button: `key: ValueKey('increment_${item.product.barcode}')`
     * Quantity text: `key: ValueKey('qty_${item.product.barcode}')`

### Invoice Ingestor Screen (`invoice_ingestor_screen.dart`)
1. **Require Invoice Photo Capture**:
   * Add check to `_saveInvoiceProduct()`: `if (_imagePath.isEmpty) { setState(() { _status = 'Error: Capture invoice photo first'; }); return; }`.
2. **Whitespace and Numeric Validation**:
   * Show `Error: Barcode, Name, Cost, and Markup are required` if inputs are empty/whitespaces.
   * Reject negative or invalid numbers for Cost/Markup with status `Error: Cost price and markup must be non-negative` or `Error: Invalid number format`.

---

## 3. Potential Integration Issues & Solutions

| Concern / Risk | Severity | Detailed Impact | Resolution Strategy |
| :--- | :--- | :--- | :--- |
| **Duplicate Keys in Checkout Cart** | **High** | Tests trying to click "increment" or "decrement" on a specific product row will crash or select the first matching widget if keys are statically shared. | Implement dynamic ValueKeys: `ValueKey('increment_${item.product.barcode}')` in `checkout_screen.dart`. |
| **Async Flow Racing during Barcode Scan** | **Medium** | Tapping "Scan Barcode" triggers an async stream listen. If the test simulates a scan before the listener is active, the event is lost. | In tests, run the simulator callback inside `runAsync` or await `tester.pump()` right after clicking scan to ensure the scan stream is initialized. |
| **StreamBuilder loading spinners** | **Low** | Tests may execute checks before snapshot has data, leading to `CircularProgressIndicator` matches instead of list items. | Always use `await tester.pumpAndSettle()` after navigation and before querying catalog contents. |
| **Input Overflow in Calculations** | **Low** | Calculations with enormous inputs (e.g. price seeding) might cause display truncation or number parsing errors. | Enforce input length caps in TextFields using `LengthLimitingTextInputFormatter`. |
