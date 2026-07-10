# Analysis Report: Milestone 3 — Checkout & Cart

## Overview
This report provides a read-only investigation and design analysis for **Milestone 3: Checkout & Cart**. It outlines current limitations in state management, suggests architecture modifications (introducing `CartItem`, `CartService`, and `BillFormatter`), details the implementation plan for native receipt sharing, and provides full templates/code specifications for the three required test files: `cart_test.dart`, `quantity_test.dart`, and `bill_format_test.dart`.

---

## 1. Observation

### Code Structure & Current State
1. **Catalog Screen (`lib/screens/catalog_screen.dart`)**:
   - Lists products from a Firestore stream using `locator<FirestoreService>().streamCatalog()`.
   - Supports manual product creation via an add product form that saves to Firestore.
   - **Crucial Gap**: There is currently no option to add products to the cart from this screen. The `ListTile` trailing contains price text but has no `onTap` behavior.
2. **Checkout Screen (`lib/screens/checkout_screen.dart`)**:
   - Contains a local definition of the `CartItem` class (lines 9-13).
   - State (the list of cart items `_cart`, toggles, checkout status) is held in `_CheckoutScreenState`.
   - **Crucial Bug**: In `lib/main.dart` (lines 121-127), the navigation menu recreates the active screen widgets from scratch on every index change. Since the cart state is local to `_CheckoutScreenState`, **switching tabs from Checkout to Catalog and back completely wipes out all cart contents**.
3. **Sharing Service (`lib/services/real_sharing_service.dart`)**:
   - `RealSharingService.shareReceipt` is completely unimplemented and throws `UnimplementedError`.
4. **Service Locator (`lib/services/service_locator.dart`)**:
   - Registers standard services (`FirestoreService`, `ScannerService`, `CameraService`, `SharingService`) as lazy singletons, using fakes when `useFakes: true` is passed (default in `main.dart`).

### Files to Modify and Create
- **Create**:
  - `lib/models/cart_item.dart` (as specified in layout)
  - `lib/utils/bill_formatter.dart` (to extract receipt formatting for isolated unit tests)
  - `lib/services/cart_service.dart` (to manage the global, tab-persistent cart state)
- **Modify**:
  - `lib/services/service_locator.dart` (to register `CartService`)
  - `lib/screens/catalog_screen.dart` (to trigger product addition to the cart)
  - `lib/screens/checkout_screen.dart` (to integrate with `CartService` and use extracted `BillFormatter`)
  - `lib/services/real_sharing_service.dart` (to implement native receipt sharing)
- **Add Tests**:
  - `test/cart_test.dart` (tests cart service methods and Catalog-to-Checkout widget integration)
  - `test/quantity_test.dart` (tests checkout increment/decrement button triggers)
  - `test/bill_format_test.dart` (tests receipt formatting rules)

---

## 2. Logic Chain

### State Management Design
To solve the data loss bug when switching tabs, we must lift the cart state out of `_CheckoutScreenState` and manage it globally. 
- **Design Choice**: Introduce a `CartService` class extending `ChangeNotifier` and register it as a singleton via the `GetIt` service locator.
- **Benefits**:
  - Encapsulates cart logic (adding, quantity limits, sums).
  - Retains state across tab switching (ephemeral memory).
  - Clean integration in widget trees using simple listener attachments or `ListenableBuilder`.
  - Easy to mock/inject and resets cleanly in tests since `setUp()` recreation calls `setupLocator(useFakes: true)`.

### Extraction of Bill Formatting
The current text layout is compiled inside `_shareReceipt` in `CheckoutScreen`. We should extract this compilation to `BillFormatter.formatReceipt` under `lib/utils/bill_formatter.dart` to make it cleanly testable in pure unit tests (`test/bill_format_test.dart`) without requiring widget tests or mocked services.

### Sharing Service Strategy
The interface defines:
`Future<void> shareReceipt(String receiptText, String phoneNumber)`
Natively, we have two directions:
1. **System Share Dialog**: Uses `share_plus` (already in `pubspec.yaml`). Note that `share_plus` opens the standard share dialog where users can select WhatsApp or SMS. It does not natively support pre-populating recipient phone numbers.
2. **Direct Intent Integration**: Can use `url_launcher` (needs to be added to `pubspec.yaml`) to launch custom URIs (e.g. `sms:$phoneNumber?body=$encodedText` or `whatsapp://send?phone=$phoneNumber&text=$encodedText`).
- **Recommendation**: Implement `RealSharingService` using `share_plus` as the baseline. In the analysis, provide a fallback script that checks if specific app schemas can launch, else fallback to standard system sharing.

### Mock Testing Strategy
For unit/widget testing:
- Use `FakeFirestoreService` to stream seeded products in the catalog screen.
- Inject a real `CartService` instance that handles adding products and checking totals.
- Inject `FakeSharingService` to assert that sharing triggers with the correct formatting and phone number.

---

## 3. Caveats & Edge Cases

1. **Nepali Phone Number Validation**:
   - The checkout screen checks phone format using: `RegExp(r'^9[78]\d{8}$')`. This matches valid mobile formats in Nepal (10 digits, starting with 98 or 97). Ensure the validation remains strict.
2. **Negative Quantities / Empty Carts**:
   - Decrmenting below 1 must remove the item from the cart.
   - Sharing a receipt or checking out with an empty cart must be blocked with an error status: `'Cart is empty'`.
3. **Upper Bound Limit (999)**:
   - Quantities must not exceed 999 items. Attempts to exceed 999 must trigger a visible error state (`'Error: Max quantity reached'`).
4. **`share_plus` Limitation**:
   - The `share_plus` plugin cannot pre-fill the phone number for WhatsApp or SMS automatically on all OS versions. The phone number field in the UI can still be captured and logged/used if a direct URI fallback is integrated, but the user must be informed that the native OS share sheet may require manual recipient selection.

---

## 4. Conclusion & Recommended Worker Instructions

Below are the step-by-step instructions for the worker to implement this milestone.

### Step 1: Create `lib/models/cart_item.dart`
Implement the `CartItem` model:
```dart
import 'product.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}
```

### Step 2: Create `lib/utils/bill_formatter.dart`
Implement the receipt formatting logic:
```dart
import '../models/cart_item.dart';

class BillFormatter {
  static String formatReceipt({
    required List<CartItem> items,
    required double totalPrice,
    required bool isPaid,
    required bool isCheckedOut,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('--- Pasale Receipt ---');
    for (var item in items) {
      buffer.writeln('${item.product.name} x${item.quantity} - Rs. ${(item.product.sellingPrice * item.quantity).toStringAsFixed(2)}');
    }
    buffer.writeln('Total: Rs. ${totalPrice.toStringAsFixed(2)}');
    buffer.writeln('Payment: ${isPaid ? "Paid" : "Credit"}');
    buffer.writeln('Status: ${isCheckedOut ? "Completed" : "Pending"}');
    return buffer.toString();
  }
}
```

### Step 3: Create `lib/services/cart_service.dart`
Implement the state notifier service:
```dart
import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];
  bool _isPaid = true;
  bool _checkedOut = false;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isPaid => _isPaid;
  bool get checkedOut => _checkedOut;

  double get totalPrice {
    return _items.fold(0.0, (sum, item) => sum + (item.product.sellingPrice * item.quantity));
  }

  void setPaid(bool value) {
    if (_isPaid != value) {
      _isPaid = value;
      notifyListeners();
    }
  }

  void setCheckedOut(bool value) {
    if (_checkedOut != value) {
      _checkedOut = value;
      notifyListeners();
    }
  }

  void addProduct(Product product) {
    final index = _items.indexWhere((item) => item.product.barcode == product.barcode);
    if (index >= 0) {
      if (_items[index].quantity < 999) {
        _items[index].quantity++;
        _checkedOut = false;
        notifyListeners();
      } else {
        throw Exception('Max quantity reached');
      }
    } else {
      _items.add(CartItem(product: product));
      _checkedOut = false;
      notifyListeners();
    }
  }

  void incrementQuantity(String barcode) {
    final index = _items.indexWhere((item) => item.product.barcode == barcode);
    if (index >= 0) {
      if (_items[index].quantity < 999) {
        _items[index].quantity++;
        _checkedOut = false;
        notifyListeners();
      } else {
        throw Exception('Max quantity reached');
      }
    }
  }

  void decrementQuantity(String barcode) {
    final index = _items.indexWhere((item) => item.product.barcode == barcode);
    if (index >= 0) {
      _checkedOut = false;
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    _isPaid = true;
    _checkedOut = false;
    notifyListeners();
  }
}
```

### Step 4: Register `CartService` in `lib/services/service_locator.dart`
Add the following imports and registers:
```dart
import 'cart_service.dart';

// Inside setupLocator():
  if (locator.isRegistered<CartService>()) {
    locator.unregister<CartService>();
  }
  locator.registerLazySingleton<CartService>(() => CartService());
```

### Step 5: Update `lib/screens/catalog_screen.dart`
Integrate the `CartService` to support adding items to the cart when tapping a product tile:
- Add `import '../services/cart_service.dart';`
- Inside the ListView's `itemBuilder`, add an `onTap` listener to the `ListTile`:
  ```dart
  onTap: () {
    try {
      locator<CartService>().addProduct(product);
      setState(() {
        _status = 'Added ${product.name} to cart';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: Max quantity reached';
      });
    }
  },
  ```

### Step 6: Refactor `lib/screens/checkout_screen.dart`
Migrate local state of the checkout cart to use the registered `CartService`:
- Remove local class declaration of `CartItem` (import `../models/cart_item.dart` instead).
- Add `import '../services/cart_service.dart';` and `import '../utils/bill_formatter.dart';`.
- Listen to `locator<CartService>()` within `_CheckoutScreenState`:
  ```dart
  late final CartService _cartService;

  @override
  void initState() {
    super.initState();
    _cartService = locator<CartService>();
    _cartService.addListener(_onCartChanged);
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    _manualBarcodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
  ```
- Update UI builder to reference `_cartService.items`, `_cartService.totalPrice`, `_cartService.isPaid`, and `_cartService.checkedOut`.
- Replace manual cart alterations (quantity changes, addition) with `CartService` methods (`_cartService.addProduct`, `_cartService.incrementQuantity`, `_cartService.decrementQuantity`).
- In `_shareReceipt()`, construct the receipt content using the new formatter:
  ```dart
  final receiptText = BillFormatter.formatReceipt(
    items: _cartService.items,
    totalPrice: _cartService.totalPrice,
    isPaid: _cartService.isPaid,
    isCheckedOut: _cartService.checkedOut,
  );
  await locator<SharingService>().shareReceipt(receiptText, phone);
  ```

### Step 7: Implement `RealSharingService`
In `lib/services/real_sharing_service.dart`, implement `shareReceipt` using `share_plus`:
```dart
import 'package:share_plus/share_plus.dart';
import 'sharing_service.dart';

class RealSharingService implements SharingService {
  @override
  Future<void> shareReceipt(String receiptText, String phoneNumber) async {
    // For standard sharing, trigger share_plus
    await Share.share(receiptText);
  }
}
```

---

## 5. Test File Implementation Blueprints

The worker must write the following three test files exactly as designed.

### 1. `pasale_register/test/cart_test.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pasale_register/main.dart';
import 'package:pasale_register/models/product.dart';
import 'package:pasale_register/services/service_locator.dart';
import 'package:pasale_register/services/cart_service.dart';
import 'package:pasale_register/services/firestore_service.dart';
import 'package:pasale_register/services/fakes/fake_firestore_service.dart';
import 'package:pasale_register/constants/keys.dart';

void main() {
  setUp(() {
    setupLocator(useFakes: true);
  });

  group('CartService Unit Tests', () {
    test('Initializes with empty cart and default values', () {
      final cartService = locator<CartService>();
      expect(cartService.items, isEmpty);
      expect(cartService.totalPrice, 0.0);
      expect(cartService.isPaid, isTrue);
      expect(cartService.checkedOut, isFalse);
    });

    test('Adding product adds new item or increments quantity', () {
      final cartService = locator<CartService>();
      final product = Product(
        id: '9770000000001',
        name: 'Biscuit',
        barcode: '9770000000001',
        sellingPrice: 50.0,
        costPrice: 40.0,
        markup: 25.0,
      );

      cartService.addProduct(product);
      expect(cartService.items.length, 1);
      expect(cartService.items.first.product.barcode, '9770000000001');
      expect(cartService.items.first.quantity, 1);
      expect(cartService.totalPrice, 50.0);

      cartService.addProduct(product);
      expect(cartService.items.length, 1);
      expect(cartService.items.first.quantity, 2);
      expect(cartService.totalPrice, 100.0);
    });

    test('Enforces maximum quantity of 999', () {
      final cartService = locator<CartService>();
      final product = Product(
        id: '9770000000001',
        name: 'Biscuit',
        barcode: '9770000000001',
        sellingPrice: 50.0,
        costPrice: 40.0,
        markup: 25.0,
      );

      for (int i = 0; i < 999; i++) {
        cartService.addProduct(product);
      }
      expect(cartService.items.first.quantity, 999);
      expect(() => cartService.addProduct(product), throwsException);
    });

    test('Clearing cart resets all state', () {
      final cartService = locator<CartService>();
      final product = Product(
        id: '9770000000001',
        name: 'Biscuit',
        barcode: '9770000000001',
        sellingPrice: 50.0,
        costPrice: 40.0,
        markup: 25.0,
      );

      cartService.addProduct(product);
      cartService.setPaid(false);
      cartService.setCheckedOut(true);

      cartService.clear();
      expect(cartService.items, isEmpty);
      expect(cartService.totalPrice, 0.0);
      expect(cartService.isPaid, isTrue);
      expect(cartService.checkedOut, isFalse);
    });
  });

  group('Catalog to Checkout Widget Integration Tests', () {
    testWidgets('Tapping product in CatalogScreen adds it to Cart and displays in CheckoutScreen', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'storeId': 'store_ok',
        'deviceId': 'device_ok',
        'isActivated': true,
      });

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Ensure we start on Catalog Screen
      expect(find.byKey(AppKeys.productSearchInput), findsOneWidget);

      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      final seededProducts = await firestore.streamCatalog().first;
      final firstProduct = seededProducts.first;

      final firstProductTile = find.byKey(ValueKey('catalog_item_\${firstProduct.barcode}'));
      expect(firstProductTile, findsOneWidget);

      // Tap first product to add to cart
      await tester.tap(firstProductTile);
      await tester.pumpAndSettle();

      // Check that it's added in CartService
      final cartService = locator<CartService>();
      expect(cartService.items.length, 1);
      expect(cartService.items.first.product.barcode, firstProduct.barcode);

      // Navigate to Checkout tab
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      // Verify Checkout screen shows the added product in cart
      expect(find.byKey(ValueKey('cart_item_\${firstProduct.barcode}')), findsOneWidget);
      expect(find.textContaining('x 1'), findsOneWidget);
    });
  });
}
```

### 2. `pasale_register/test/quantity_test.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pasale_register/main.dart';
import 'package:pasale_register/models/product.dart';
import 'package:pasale_register/services/service_locator.dart';
import 'package:pasale_register/services/cart_service.dart';
import 'package:pasale_register/constants/keys.dart';

void main() {
  setUp(() {
    setupLocator(useFakes: true);
  });

  group('Cart Quantity Adjustments Tests', () {
    testWidgets('Incrementing quantity updates total and quantity text', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'storeId': 'store_ok',
        'deviceId': 'device_ok',
        'isActivated': true,
      });

      final cartService = locator<CartService>();
      final product = Product(
        id: '9770000000001',
        name: 'Biscuit',
        barcode: '9770000000001',
        sellingPrice: 50.0,
        costPrice: 40.0,
        markup: 25.0,
      );
      cartService.addProduct(product);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rs. 50.00 x 1'), findsOneWidget);
      expect(find.text('Cart Total: Rs. 50.00'), findsOneWidget);

      final incBtn = find.byKey(ValueKey('increment_qty_\${product.barcode}'));
      expect(incBtn, findsOneWidget);
      await tester.tap(incBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Rs. 50.00 x 2'), findsOneWidget);
      expect(find.text('Cart Total: Rs. 100.00'), findsOneWidget);
      expect(cartService.items.first.quantity, 2);
    });

    testWidgets('Decrementing quantity reduces count and removes item at 0', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'storeId': 'store_ok',
        'deviceId': 'device_ok',
        'isActivated': true,
      });

      final cartService = locator<CartService>();
      final product = Product(
        id: '9770000000001',
        name: 'Biscuit',
        barcode: '9770000000001',
        sellingPrice: 50.0,
        costPrice: 40.0,
        markup: 25.0,
      );
      cartService.addProduct(product);
      cartService.addProduct(product); // quantity = 2

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      final decBtn = find.byKey(ValueKey('decrement_qty_\${product.barcode}'));
      expect(decBtn, findsOneWidget);

      await tester.tap(decBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Rs. 50.00 x 1'), findsOneWidget);
      expect(cartService.items.first.quantity, 1);

      await tester.tap(decBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('cart_item_\${product.barcode}')), findsNothing);
      expect(cartService.items, isEmpty);
    });

    testWidgets('Cannot exceed quantity of 999 and shows error', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'storeId': 'store_ok',
        'deviceId': 'device_ok',
        'isActivated': true,
      });

      final cartService = locator<CartService>();
      final product = Product(
        id: '9770000000001',
        name: 'Biscuit',
        barcode: '9770000000001',
        sellingPrice: 50.0,
        costPrice: 40.0,
        markup: 25.0,
      );
      
      cartService.addProduct(product);
      cartService.items.first.quantity = 999;

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      final incBtn = find.byKey(ValueKey('increment_qty_\${product.barcode}'));
      await tester.tap(incBtn);
      await tester.pumpAndSettle();

      expect(cartService.items.first.quantity, 999);
      expect(find.byKey(AppKeys.statusText), findsOneWidget);
      expect(find.textContaining('Error: Max quantity reached'), findsOneWidget);
    });
  });
}
```

### 3. `pasale_register/test/bill_format_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pasale_register/models/product.dart';
import 'package:pasale_register/models/cart_item.dart';
import 'package:pasale_register/utils/bill_formatter.dart';

void main() {
  group('BillFormatter Unit Tests', () {
    test('Formats a standard receipt with a single item (Paid, Completed)', () {
      final items = [
        CartItem(
          product: Product(
            id: '977111',
            name: 'Wai Wai Noodles',
            barcode: '977111',
            sellingPrice: 20.0,
            costPrice: 16.0,
            markup: 25.0,
          ),
          quantity: 3,
        ),
      ];

      final receipt = BillFormatter.formatReceipt(
        items: items,
        totalPrice: 60.0,
        isPaid: true,
        isCheckedOut: true,
      );

      final expected = '--- Pasale Receipt ---\\n'
          'Wai Wai Noodles x3 - Rs. 60.00\\n'
          'Total: Rs. 60.00\\n'
          'Payment: Paid\\n'
          'Status: Completed\\n';

      expect(receipt.replaceAll('\\r\\n', '\\n'), expected);
    });

    test('Formats receipt with multiple items (Credit, Pending)', () {
      final items = [
        CartItem(
          product: Product(
            id: '977111',
            name: 'Wai Wai Noodles',
            barcode: '977111',
            sellingPrice: 20.0,
            costPrice: 16.0,
            markup: 25.0,
          ),
          quantity: 2,
        ),
        CartItem(
          product: Product(
            id: '977222',
            name: 'Coke 500ml',
            barcode: '977222',
            sellingPrice: 85.50,
            costPrice: 75.0,
            markup: 14.0,
          ),
          quantity: 1,
        ),
      ];

      final receipt = BillFormatter.formatReceipt(
        items: items,
        totalPrice: 125.50,
        isPaid: false,
        isCheckedOut: false,
      );

      final expected = '--- Pasale Receipt ---\\n'
          'Wai Wai Noodles x2 - Rs. 40.00\\n'
          'Coke 500ml x1 - Rs. 85.50\\n'
          'Total: Rs. 125.50\\n'
          'Payment: Credit\\n'
          'Status: Pending\\n';

      expect(receipt.replaceAll('\\r\\n', '\\n'), expected);
    });
  });
}
```
