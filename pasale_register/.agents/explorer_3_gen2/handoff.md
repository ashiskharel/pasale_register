# Handoff Report — Explorer 3 Gen2 (Modules 9 & 10 Code Review)

## 1. Observation

Direct code analysis was conducted across all files in Target Modules 9 and 10 within `C:\Users\aerok\Pasale Register-grok\pasale_register`.

### Key Direct Code Observations:
1. **Unsaved Vendor Invoices**: In `lib/screens/invoice_ingestor_screen.dart`, `_saveSelected()` (lines 161–288) saves products (`saveProduct`), inventory logs (`saveInventoryLog`), and vendor profiles (`saveVendor`), but **never calls `saveVendorInvoice`**.
2. **Thousand-Separator Comma Parsing Failure**: In `lib/utils/invoice_line_parser.dart` (lines 247–250), `_toDouble()` executes `raw.replaceAll(',', '.')`. As a result, string `"1,500.00"` becomes `"1.500.00"`, causing `double.tryParse` to return `null` and dropping all prices >= 1,000 formatted with thousand separators.
3. **Shared Camera Controller State Conflicts**: In `lib/services/service_locator.dart` (lines 155–170), `_registerRealCameraStack()` initializes a single `MlkitCameraController` lazy singleton shared by `ScannerService` and `CameraService`. Calling `captureProductPhoto()` or `prepareProductPhotoSession()` in `InvoiceIngestorScreen` alters vision modes and leaves `resumeStream: false`, causing live scanner streams in POS screens to freeze without recovery handlers.
4. **Validation Bypasses & Division by Zero**: `lib/screens/invoice_ingestor_screen.dart` (lines 167–180) checks `line.costPrice < 0`, but allows `line.quantity <= 0` and `line.costPrice == 0`. When `line.costPrice == 0`, computing `((sellingPrice - costPrice) / costPrice) * 100` on line 218 results in `double.infinity`.
5. **Native OCR Memory Churn**: `lib/screens/invoice_ingestor_screen.dart` (lines 108–110) creates a new `InvoiceOcrService` instance on every capture button press, allocating and disposing native C++ `TextRecognizer` objects per image capture.

---

## 2. Logic Chain

1. **Vendor Invoice Records Missing**:
   - *Observation*: `_saveSelected()` in `invoice_ingestor_screen.dart` executes database writes for `Vendor`, `Product`, and `InventoryLog`, but lacks any invocation of `saveVendorInvoice()`.
   - *Reasoning*: Scanned invoices update stock levels but leave no invoice record in Firestore under `stores/{storeId}/vendor_invoices/`.
   - *Deduction*: `VendorInvoicesScreen` remains empty (`'No invoices found.'`), making vendor debt, billing history, and invoice audit trails unavailable.

2. **OCR Parsing Price Dropping**:
   - *Observation*: `InvoiceLineParser._toDouble()` replaces `,` with `.`.
   - *Reasoning*: Standard currency formatting uses `,` as a thousands separator (e.g. `Rs. 1,500`). Replacing `,` with `.` produces invalid double strings with multiple decimal points (`1.500.00`).
   - *Deduction*: Any item with a cost >= 1,000 formatted with standard separators fails parsing and is excluded from invoice ingestion results.

3. **Camera Stream Freezing**:
   - *Observation*: `RealCameraService` uses the singleton `MlkitCameraController` with `resumeStream: false` on `captureStill()`.
   - *Reasoning*: Pausing the stream stops camera image frame streaming at the controller level.
   - *Deduction*: Navigating back from invoice capture to POS checkout leaves the scanner camera preview frozen because `MlkitScannerService` assumes the camera stream is still running.

4. **Catalog Math Distortion**:
   - *Observation*: `InvoiceIngestorScreen` does not validate `costPrice > 0` or `quantity > 0`.
   - *Reasoning*: `costPrice == 0` causes division by zero when calculating markup percentage; `quantity <= 0` subtracts or corrupts stock levels.
   - *Deduction*: Unvalidated user edits on scanned rows can inject corrupt data into inventory logs and store catalog items.

---

## 3. Caveats

- **Network / Runtime Execution**: Analysis was strictly read-only static code inspection. No build, test execution, or runtime device testing was performed per explicit constraints.
- **ML Kit C++ Native Implementation**: Behavior of `TextRecognizer` and `MlkitCameraController` under low memory conditions on physical devices relies on native ML Kit bindings (`google_mlkit_text_recognition` and `mlkit_camera`).
- **Fake Services**: In `ServiceBackend.fakes` mode, hardware camera issues and Firestore persistence do not trigger because fake implementations are loaded instead.

---

## 4. Conclusion

Modules 9 & 10 contain **11 actionable defects** that impact functionality, data integrity, and system performance:
- Scanned vendor invoices fail to create historical `VendorInvoice` records.
- OCR parsing fails on invoice item amounts over 1,000 NPR formatted with commas.
- Shared camera controller singleton causes POS scanning streams to freeze after invoice photo capture.
- Data validation gaps allow zero cost (`Infinity` markup) and non-positive quantities.
- Native ML Kit `TextRecognizer` instances are repeatedly re-created on each capture, creating native memory churn.

A complete breakdown of each issue and recommended code patches is documented in `analysis.md`.

---

## 5. Verification Method

To independently verify these findings without modifying source code:

1. **Verify Missing Vendor Invoice Persistence**:
   - Inspect `lib/screens/invoice_ingestor_screen.dart` lines 161–288 (`_saveSelected`). Confirm that `saveVendorInvoice` is nowhere in the method.
2. **Verify Thousand Separator Comma Bug**:
   - Inspect `lib/utils/invoice_line_parser.dart` lines 247–250 (`_toDouble`). Test mentally or in Dart REPL: `double.tryParse("1,500.00".replaceAll(',', '.'))` -> `double.tryParse("1.500.00")` -> `null`.
3. **Verify Shared Singleton Camera Stream Pause**:
   - Inspect `lib/services/service_locator.dart` line 155–170 (`_registerRealCameraStack`) and `lib/services/real_camera_service.dart` line 27 (`captureStill(resumeStream: false)`). Confirm that the same controller instance is shared and paused without resume on pop.
4. **Verify Infinity Markup on Zero Cost**:
   - Inspect `lib/screens/invoice_ingestor_screen.dart` line 218: `((line.sellingPrice - line.costPrice) / line.costPrice) * 100`. When `line.costPrice == 0`, evaluate result (`double.infinity`).
