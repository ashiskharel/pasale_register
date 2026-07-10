# Project: Pasale Register

## Architecture
Pasale Register is a Flutter mobile application integrated with Firebase (Cloud Firestore and Local/Firebase Storage). The architecture follows a clean service-oriented model to isolate business logic, state management, and external service integrations.

### Key Components:
1. **State Management & Models**: Data structures representing `Store`, `Device`, `Product`, and `CartItem`.
2. **Services**:
   - `FirestoreService`: Handles Firestore communication (store activation, catalog CRUD, barcode lookup).
   - `ScannerService`: Wraps camera-based barcode scanning, vibration, and beep audio feedback.
   - `SharingService`: Interfaces with native sharing channels (SMS/WhatsApp).
   - `CameraService`: Manages vendor invoice photo capture and local/remote storage.
3. **UI / Screens**:
   - `ActivationScreen`: Enforces shop activation and tracks active devices.
   - `CatalogScreen`: Lists catalog products and supports manual addition.
   - `CheckoutScreen`: Contains the shopping cart, quantity controls, paid/credit toggle, and checkout/receipt sharing options.
   - `InvoiceIngestorScreen`: Ingests vendor invoice photos, calculates selling price, and saves to Firestore.

### Code Layout
```
pasale_register/
  android/             - Android native configuration
  ios/                 - iOS native configuration
  lib/
    main.dart          - App entry point and initialization
    models/            - Data models
      store.dart
      device.dart
      product.dart
      cart_item.dart
    services/          - Service integrations
      firestore_service.dart
      scanner_service.dart
      sharing_service.dart
      camera_service.dart
    screens/           - App screens
      activation_screen.dart
      catalog_screen.dart
      checkout_screen.dart
      invoice_ingestor_screen.dart
    widgets/           - Reusable UI elements
      cart_item_widget.dart
      product_dialog.dart
  test/                - Unit and Widget tests
    cart_test.dart
    quantity_test.dart
    bill_format_test.dart
  integration_test/    - Integration / E2E tests
    app_test.dart
  scripts/             - Seeding scripts
    seed_db.py         - Catalog scraping and seeding script
```

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Setup & Activation | Flutter project init, Firebase config, Store/Device activation logic | None | DONE |
| 2 | Catalog & Seeding | Firestore catalog schema, online scraper script, catalog seeding | M1 | DONE |
| 3 | Checkout & Cart | Catalog screen, Checkout screen, +/- controls, Paid/Credit toggle, receipt share | M2 | IN_PROGRESS |
| 4 | Barcode Scanner | Continuous Barcode Scanner (Split-screen or swipeable layout showing scanner active alongside cart items; camera stays active until 'Done Scanning / OK' button tapped), beep/vibe, registration dialog | M2 | PLANNED |
| 5 | Vendor Ingestor | Camera photo capture, cost + markup input fields, selling price calculator | M3 | PLANNED |
| 6 | E2E Integration | E2E integration test suite, passing all Tiers 1-4 tests, Tier 5 hardening | M1-M5 | PLANNED |

## Interface Contracts

### Firestore & Models
- **Product Model**:
  ```dart
  class Product {
    final String id; // barcode or auto-id
    final String name;
    final String barcode;
    final double sellingPrice;
    final double costPrice;
    final double markup;
    
    Product({required this.id, required this.name, required this.barcode, required this.sellingPrice, required this.costPrice, required this.markup});
    Map<String, dynamic> toMap();
    factory Product.fromMap(Map<String, dynamic> map, String id);
  }
  ```

- **Store & Device tracking**:
  - `/stores/{storeId}`: contains store metadata (name, activation date).
  - `/stores/{storeId}/devices/{deviceId}`: contains device metadata (model, OS version, last active timestamp).

### Barcode & Scan Feedback
- `ScannerService.scan()`: returns `Future<String?>` (scanned barcode).
- `ScannerService.triggerFeedback()`: plays a short beep and triggers a haptic vibration on successful match.

### Ingestion & Calculation
- `MarkupCalculator.calculateSellingPrice(double costPrice, double markupPercent)`: returns `double` selling price.
