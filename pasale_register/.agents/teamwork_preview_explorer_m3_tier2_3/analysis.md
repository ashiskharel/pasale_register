# Analysis Report: Milestone 3 - Tier 2 (Boundary, Corner, & Error Cases)

## Summary of Findings
1. **Validation Gaps**: The existing stub screens lack proper input validation for negative numbers, space-only fields, invalid phone numbers, non-numeric values, and duplicate barcodes. Adding these validation steps is critical for both robust real-world behavior and E2E testability.
2. **Duplicate Keys**: The `CheckoutScreen` cart list uses static, duplicate keys for increment/decrement buttons across all rows (`AppKeys.incrementQtyButton` and `AppKeys.decrementQtyButton`). This causes finders in Flutter's `integration_test` to throw ambiguity exceptions when multiple items are in the cart.
3. **Async Race Conditions**: Testing the barcode scanner requires running the mock scanner trigger inside `tester.runAsync(...)` because the mock stream subscription relies on Dart's real event loop. Stream-based UI elements (like the Catalog's product list stream) also require proper `pumpAndSettle()` frames to capture emissions.

---

## 30 E2E Boundary, Corner, and Error Test Cases (5 per feature)

### Feature 1: Device Activation & Tracking
* **F1_T6: Store Activation - Space-only inputs rejection**
  * *Description*: Enter space characters (e.g., `"   "`) into `storeIdInput` or `storeNameInput` and tap activate.
  * *Expected Behavior*: App trims inputs, rejects them, and displays `Error: Store ID and Name required` on the status text.
* **F1_T7: Store Activation - Alphanumeric restriction on Store ID**
  * *Description*: Enter non-alphanumeric character (e.g., `"shop-123!"` or `"my shop"`) in `storeIdInput`.
  * *Expected Behavior*: Shows validation error `Error: Store ID must be alphanumeric`.
* **F1_T8: Device Registration - Space-only/empty Device ID rejection**
  * *Description*: Attempt to register a device with an empty or whitespace-only device ID.
  * *Expected Behavior*: Shows validation error `Error: Store ID and Device ID required`.
* **F1_T9: Device Registration - Non-JSON Metadata wraps to 'raw' fallback**
  * *Description*: Input an invalid JSON string (e.g. `"not_a_json"`) into the metadata text field.
  * *Expected Behavior*: App catches parse exception, successfully registers device by packing the raw string inside a `{'raw': metadataStr}` map.
* **F1_T10: Device Registration - Store activation dependency check**
  * *Description*: Register a device for a store that does not exist or has not been activated.
  * *Expected Behavior*: Service throws a store lookup exception, screen displays `Error: Exception: Store not activated`.

### Feature 2: Firestore Product Catalog & Seeding
* **F2_T6: Add Product Manually - Negative selling price rejection**
  * *Description*: Manually add a product with a selling price of `-10.0`.
  * *Expected Behavior*: Prevent saving; show validation error `Error: Prices and markup must be non-negative`.
* **F2_T7: Add Product Manually - Negative cost price rejection**
  * *Description*: Manually add a product with a cost price of `-5.0`.
  * *Expected Behavior*: Prevent saving; show validation error `Error: Prices and markup must be non-negative`.
* **F2_T8: Add Product Manually - Negative markup rejection**
  * *Description*: Manually add a product with a markup percentage of `-2.5`.
  * *Expected Behavior*: Prevent saving; show validation error `Error: Prices and markup must be non-negative`.
* **F2_T9: Add Product Manually - Selling price lower than cost price rejection**
  * *Description*: Set cost price to `100.0` and selling price to `90.0`.
  * *Expected Behavior*: Prevent saving; show validation error `Error: Selling price cannot be less than cost price`.
* **F2_T10: Add Product Manually - Duplicate barcode error**
  * *Description*: Attempt to save a manually added product with a barcode that already exists in the catalog.
  * *Expected Behavior*: Firestore service rejects with barcode constraint error, screen displays `Error: Product with barcode already exists`.

### Feature 3: Cart Management & Calculations
* **F3_T6: Manual Barcode Addition - Search non-existent barcode**
  * *Description*: Enter a barcode that does not exist in the Firestore catalog and try to add it.
  * *Expected Behavior*: App updates status message to `Product not found: <barcode>`.
* **F3_T7: Quantity Increment - Prevents exceeding maximum inventory limit (999)**
  * *Description*: Increment an item's quantity beyond 999.
  * *Expected Behavior*: Increment button disabled or action rejected, displaying `Error: Max quantity reached`.
* **F3_T8: Cart Calculations - Zero-priced product math handling**
  * *Description*: Add a product with a price of `0.0` to the cart.
  * *Expected Behavior*: Math runs successfully; cart total evaluates to `Rs. 0.00` without crashing.
* **F3_T9: Cart Calculations - Floating-point representation precision rounding**
  * *Description*: Add 3 units of an item priced at `Rs. 10.33` (subtotal `30.990000000000002`).
  * *Expected Behavior*: UI display rounds output to two decimal places: `Cart Total: Rs. 30.99`.
* **F3_T10: Cart Operations - Decrementing quantity when quantity is 1 removes the item**
  * *Description*: Click decrement on an item whose quantity is currently 1.
  * *Expected Behavior*: Product is removed from the list; cart total returns to `Rs. 0.00`.

### Feature 4: Paid/Credit & Receipt Sharing
* **F4_T6: Phone Number Validation - Empty phone number rejection**
  * *Description*: Attempt to share receipt without entering a phone number.
  * *Expected Behavior*: Rejects action; shows `Enter phone number first`.
* **F4_T7: Phone Number Validation - Invalid phone format rejection**
  * *Description*: Input short, alphanumeric, or pattern-invalid values (e.g. `"123"`, `"abc"`, `"99999999999999999"`) in phone field.
  * *Expected Behavior*: Rejects action; shows `Error: Invalid phone number`.
* **F4_T8: Share Receipt - Empty cart sharing prevention**
  * *Description*: Tap the share receipt button when there are no items in the cart.
  * *Expected Behavior*: Rejects action; shows `Error: Cart is empty, cannot share receipt`.
* **F4_T9: Share Receipt - Exception handling on native share channel**
  * *Description*: Configure mock sharing service to throw an exception representing a sharing failure.
  * *Expected Behavior*: UI catches exception gracefully and displays `Share error: Exception: share_failed`.
* **F4_T10: Checkout Flow - Cart modifications reset checkout status**
  * *Description*: Complete checkout (displays "Checkout complete"), then modify the cart by adding/incrementing items.
  * *Expected Behavior*: The checkout complete state resets (`_checkedOut = false`) and status changes to indicate the new item addition.

### Feature 5: Barcode Scanner & Matching
* **F5_T6: Scanner - User cancellation**
  * *Description*: Trigger barcode scanner but mock a user close/cancellation (scanner returns `null`).
  * *Expected Behavior*: Screen stops loading, status displays `Scan cancelled`.
* **F5_T7: Scanner - Platform / Permission error handling**
  * *Description*: Mock the camera/scanner throwing a PlatformException (e.g. camera permission denied).
  * *Expected Behavior*: UI catches exception, status updates to `Scan error: Exception: Camera permission denied`.
* **F5_T8: Scanner - Empty or whitespace scanned barcode**
  * *Description*: Mock scanner returning an empty or space-only string.
  * *Expected Behavior*: Rejects string immediately, does not run database fetch, and displays warning/retains cart state.
* **F5_T9: Scanner - Rapid consecutive scans debouncing**
  * *Description*: Tap the scan button multiple times in rapid succession.
  * *Expected Behavior*: A locking mechanism prevents starting multiple concurrent scan sessions.
* **F5_T10: Scanner - Haptic feedback tolerance**
  * *Description*: Scan a valid product, but mock the haptic vibrator/beeper service throwing a device exception.
  * *Expected Behavior*: Product is still added to the cart; the app catches the feedback failure silently without halting the checkout flow.

### Feature 6: Vendor Invoice Ingestor & Markup
* **F6_T6: Camera - Photo capture cancellation**
  * *Description*: Click capture photo but cancel the operation (camera returns `null`).
  * *Expected Behavior*: Path is not set, status updates to `Photo capture cancelled`.
* **F6_T7: Camera - Camera permission/hardware exception handling**
  * *Description*: Mock camera service throwing an exception.
  * *Expected Behavior*: App catches exception, status updates to `Capture error: Exception: Camera error`.
* **F6_T8: Ingestor Validation - Non-numeric cost and markup inputs**
  * *Description*: Input non-numeric characters (e.g., `"10a"` or `"cost"`) in the Cost and Markup fields.
  * *Expected Behavior*: App validates inputs, preventing saving, and displays `Error: Cost and markup must be valid numbers`.
* **F6_T9: Ingestor Validation - Negative cost or markup inputs**
  * *Description*: Input negative values in Cost or Markup fields.
  * *Expected Behavior*: App validates inputs, preventing saving, and displays `Error: Cost and markup must be non-negative`.
* **F6_T10: Ingestor Validation - Mandatory invoice photo**
  * *Description*: Try to save an ingested product without first capturing an invoice photo.
  * *Expected Behavior*: Prevent save; display `Error: Invoice photo is required`.

---

## Detailed updates for Stub Screens

### 1. `pasale_register/lib/screens/activation_screen.dart`
- **Validation of inputs**: Use `.trim().isEmpty` to screen out spaces.
- **Store ID restriction**: Ensure alphanumeric format.
- **Proposed updates**:
  ```dart
  // In _activate():
  final storeId = _storeIdController.text.trim();
  final storeName = _storeNameController.text.trim();
  if (storeId.isEmpty || storeName.isEmpty) {
    setState(() => _status = 'Error: Store ID and Name required');
    return;
  }
  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(storeId)) {
    setState(() => _status = 'Error: Store ID must be alphanumeric');
    return;
  }

  // In _register():
  final storeId = _storeIdController.text.trim();
  final deviceId = _deviceIdController.text.trim();
  if (storeId.isEmpty || deviceId.isEmpty) {
    setState(() => _status = 'Error: Store ID and Device ID required');
    return;
  }
  ```

### 2. `pasale_register/lib/screens/catalog_screen.dart`
- **Validation of manual input values**: Check for double parsing errors, negative numbers, and selling price bounds.
- **Proposed updates**:
  ```dart
  // In _saveProduct():
  final name = _nameController.text.trim();
  final barcode = _barcodeController.text.trim();
  final sellingPriceStr = _sellingPriceController.text.trim();
  final costPriceStr = _costPriceController.text.trim();
  final markupStr = _markupController.text.trim();

  if (name.isEmpty || barcode.isEmpty) {
    setState(() => _status = 'Error: Name and Barcode required');
    return;
  }
  
  final sellingPrice = double.tryParse(sellingPriceStr);
  final costPrice = double.tryParse(costPriceStr);
  final markup = double.tryParse(markupStr);

  if (sellingPrice == null || costPrice == null || markup == null) {
    setState(() => _status = 'Error: Prices and markup must be valid numbers');
    return;
  }

  if (sellingPrice < 0.0 || costPrice < 0.0 || markup < 0.0) {
    setState(() => _status = 'Error: Prices and markup must be non-negative');
    return;
  }

  if (sellingPrice < costPrice) {
    setState(() => _status = 'Error: Selling price cannot be less than cost price');
    return;
  }
  ```

### 3. `pasale_register/lib/screens/checkout_screen.dart`
- **Formatted Decimal Total**: Avoid long float representation by displaying `.toStringAsFixed(2)`.
- **Unique Item Action Keys**: Resolve duplicate keys by appending the product barcode to action keys.
- **Quantity Limits**: Cap quantity increments to 999.
- **Checkout Reset**: Modify quantity controls and product add flows to reset the checkout flag.
- **Phone validation**: Enforce digits and length constraints on the phone number.
- **Scanning flag**: Add `_isScanning` guard.
- **Proposed updates**:
  ```dart
  // Inside State fields:
  bool _isScanning = false;

  // In _addBarcodeToCart():
  if (barcode.trim().isEmpty) return;
  // inside try:
  setState(() {
    _checkedOut = false; // Reset checkout state
    // ... item add logic ...
  });
  try {
    await locator<ScannerService>().triggerFeedback();
  } catch (e) {
    // Tolerates haptic service failure
  }

  // In _scanBarcode():
  if (_isScanning) return;
  setState(() {
    _isScanning = true;
    _status = 'Scanning...';
  });
  try {
    final barcode = await locator<ScannerService>().scan();
    if (barcode != null && barcode.trim().isNotEmpty) {
      await _addBarcodeToCart(barcode);
    } else {
      setState(() => _status = 'Scan cancelled');
    }
  } catch (e) {
    setState(() => _status = 'Scan error: $e');
  } finally {
    setState(() => _isScanning = false);
  }

  // In _checkout():
  if (_cart.isEmpty) {
    setState(() => _status = 'Error: Cart is empty');
    return;
  }

  // In _shareReceipt():
  if (_cart.isEmpty) {
    setState(() => _status = 'Error: Cart is empty, cannot share receipt');
    return;
  }
  final phone = _phoneController.text.trim();
  if (phone.isEmpty) {
    setState(() => _status = 'Enter phone number first');
    return;
  }
  if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(phone)) {
    setState(() => _status = 'Error: Invalid phone number');
    return;
  }

  // In build() - Card Total Display:
  Text('Cart Total: Rs. ${_totalPrice.toStringAsFixed(2)}')

  // In build() - Quantity adjustment buttons keys (unique key update):
  IconButton(
    key: Key('decrementQtyButton_${item.product.barcode}'),
    ...
  )
  IconButton(
    key: Key('incrementQtyButton_${item.product.barcode}'),
    ...
  )
  ```

### 4. `pasale_register/lib/screens/invoice_ingestor_screen.dart`
- **Validation**: Verify photo is captured, inputs are valid numbers, and non-negative.
- **Proposed updates**:
  ```dart
  // In _saveInvoiceProduct():
  final barcode = _barcodeController.text.trim();
  final name = _nameController.text.trim();
  final costStr = _costController.text.trim();
  final markupStr = _markupController.text.trim();

  if (_imagePath.isEmpty) {
    setState(() => _status = 'Error: Invoice photo is required');
    return;
  }

  if (barcode.isEmpty || name.isEmpty) {
    setState(() => _status = 'Error: Barcode and Name are required');
    return;
  }

  final cost = double.tryParse(costStr);
  final markup = double.tryParse(markupStr);

  if (cost == null || markup == null) {
    setState(() => _status = 'Error: Cost and markup must be valid numbers');
    return;
  }

  if (cost < 0.0 || markup < 0.0) {
    setState(() => _status = 'Error: Cost and markup must be non-negative');
    return;
  }
  ```

---

## E2E and Service Layer Architecture Updates

To make sure these test cases are completely verifiable, the following extensions must be made in the test mocks:

1. **`FakeFirestoreService` Store existence checks**:
   Add a boolean flag or verification inside `registerDevice` to check if the store resides in the stores map:
   ```dart
   if (!_stores.containsKey(storeId)) {
     throw Exception('Store not activated');
   }
   ```
2. **Exception Simulation in Fakes**:
   Add a toggle option in `FakeFirestoreService`, `FakeScannerService`, and `FakeSharingService` to throw custom exceptions on demand during tests:
   ```dart
   // inside FakeSharingService
   bool throwErrorOnNextCall = false;
   @override
   Future<void> shareReceipt(String receiptText, String phoneNumber) async {
     if (throwErrorOnNextCall) {
       throw Exception('share_failed');
     }
     // ... normal logic ...
   }
   ```

---

## Summary of Potential Issues and Concerns

1. **Test Flakiness with Async Stream Actions**:
   Flutter's `integration_test` relies heavily on microtask control. Because stream events inside mock service streams span the actual event loop, tests will occasionally hang if `tester.runAsync()` is not consistently used when interacting with the FakeScannerService stream emissions.
2. **Duplicate Keys on Dynamic Rows**:
   Multiple cart rows sharing static keys is a major blocker. Using template keys `Key('incrementQtyButton_${barcode}')` will solve this immediately and prevent key collision.
3. **Double Floating-Point Errors**:
   The cart's accumulated selling prices can easily contain imprecise floats. Text finder assertions (`find.textContaining('Cart Total: Rs. 30.99')`) will break without formatting constraints (e.g. `toStringAsFixed(2)`) in the UI display.
4. **State Cleanup between Tests**:
   Ensure `setupLocator(useFakes: true)` is executed in the `setUp` hook of the test groups. However, the fakes themselves must reset their internal in-memory maps (`stores`, `products`, `devices`) to ensure each test case starts with a clean database state and remains independent.
