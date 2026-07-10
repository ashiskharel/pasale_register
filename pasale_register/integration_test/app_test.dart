import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pasale_register/main.dart';
import 'package:pasale_register/constants/keys.dart';
import 'package:pasale_register/models/product.dart';
import 'package:pasale_register/services/service_locator.dart';
import 'package:pasale_register/services/firestore_service.dart';
import 'package:pasale_register/services/scanner_service.dart';
import 'package:pasale_register/services/sharing_service.dart';
import 'package:pasale_register/services/camera_service.dart';
import 'package:pasale_register/services/fakes/fake_firestore_service.dart';
import 'package:pasale_register/services/fakes/fake_scanner_service.dart';
import 'package:pasale_register/services/fakes/fake_sharing_service.dart';
import 'package:pasale_register/services/fakes/fake_camera_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 1 - Feature Coverage', () {
    setUp(() {
      setupLocator(useFakes: true);
    });

    // ==========================================
    // FEATURE 1: Device Activation & Tracking
    // ==========================================

    testWidgets('F1_T1: Store activation saves to FakeFirestoreService', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.storeIdInput), 'store_abc');
      await tester.enterText(find.byKey(AppKeys.storeNameInput), 'My Bakery');
      await tester.tap(find.byKey(AppKeys.activateStoreButton));
      await tester.pumpAndSettle();

      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      expect(firestore.stores['store_abc'], 'My Bakery');
    });

    testWidgets('F1_T2: Store activation shows success message', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.storeIdInput), 'store_abc');
      await tester.enterText(find.byKey(AppKeys.storeNameInput), 'My Bakery');
      await tester.tap(find.byKey(AppKeys.activateStoreButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Store Activated Successfully: My Bakery'), findsOneWidget);
    });

    testWidgets('F1_T3: Device registration saves to FakeFirestoreService', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.storeIdInput), 'store_abc');
      await tester.enterText(find.byKey(AppKeys.deviceIdInput), 'device_123');
      await tester.enterText(find.byKey(AppKeys.deviceMetadataInput), '{"os": "Android"}');
      await tester.tap(find.byKey(AppKeys.registerDeviceButton));
      await tester.pumpAndSettle();

      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      expect(firestore.devices['store_abc']?['device_123']?['os'], 'Android');
    });

    testWidgets('F1_T4: Device registration shows success message', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.storeIdInput), 'store_abc');
      await tester.enterText(find.byKey(AppKeys.deviceIdInput), 'device_123');
      await tester.tap(find.byKey(AppKeys.registerDeviceButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Device Registered Successfully: device_123'), findsOneWidget);
    });

    testWidgets('F1_T5: Store activation fails on empty inputs', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.activateStoreButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Store ID and Name required'), findsOneWidget);
    });

    // ==========================================
    // FEATURE 2: Firestore Product Catalog & Seeding
    // ==========================================

    testWidgets('F2_T1: Catalog screen streams and lists items from firestore', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(
        id: '999',
        name: 'Initial Product',
        barcode: '999',
        sellingPrice: 100.0,
        costPrice: 80.0,
        markup: 25.0,
      ));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCatalog));
      await tester.pumpAndSettle();

      expect(find.text('Initial Product'), findsOneWidget);
      expect(find.text('Rs. 100.0'), findsOneWidget);
    });

    testWidgets('F2_T2: Add product manually saves product to FakeFirestoreService', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCatalog));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Manual Bread');
      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), '111222');
      await tester.enterText(find.byKey(AppKeys.productSellingPriceInput), '45.0');
      await tester.enterText(find.byKey(AppKeys.productCostPriceInput), '35.0');
      await tester.enterText(find.byKey(AppKeys.productMarkupInput), '28.5');

      await tester.tap(find.byKey(AppKeys.saveProductButton));
      await tester.pumpAndSettle();

      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      final prod = await firestore.getProduct('111222');
      expect(prod, isNotNull);
      expect(prod!.name, 'Manual Bread');
      expect(prod.sellingPrice, 45.0);
    });

    testWidgets('F2_T3: Add product manually updates UI list', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCatalog));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Manual Bread');
      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), '111222');
      await tester.enterText(find.byKey(AppKeys.productSellingPriceInput), '45.0');
      await tester.tap(find.byKey(AppKeys.saveProductButton));
      await tester.pumpAndSettle();

      expect(find.text('Manual Bread'), findsOneWidget);
    });

    testWidgets('F2_T4: Search field filters product list by name', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '1', name: 'Apple', barcode: '1', sellingPrice: 10, costPrice: 8, markup: 25));
      await firestore.saveProduct(Product(id: '2', name: 'Banana', barcode: '2', sellingPrice: 15, costPrice: 12, markup: 25));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCatalog));
      await tester.pumpAndSettle();

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);

      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'App');
      await tester.pumpAndSettle();

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsNothing);
    });

    testWidgets('F2_T5: Search field filters product list by barcode', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '101', name: 'Apple', barcode: '101', sellingPrice: 10, costPrice: 8, markup: 25));
      await firestore.saveProduct(Product(id: '202', name: 'Banana', barcode: '202', sellingPrice: 15, costPrice: 12, markup: 25));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCatalog));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), '202');
      await tester.pumpAndSettle();

      expect(find.text('Apple'), findsNothing);
      expect(find.text('Banana'), findsOneWidget);
    });

    // ==========================================
    // FEATURE 3: Cart Management & Calculations
    // ==========================================

    testWidgets('F3_T1: Add product to cart by barcode lookup increases cart total', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '123', name: 'Milk', barcode: '123', sellingPrice: 50.0, costPrice: 40.0, markup: 25.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), '123');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cart Total: Rs. 50.0'), findsOneWidget);
    });

    testWidgets('F3_T2: Incrementing item quantity updates cart total correctly', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '123', name: 'Milk', barcode: '123', sellingPrice: 50.0, costPrice: 40.0, markup: 25.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), '123');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('increment_qty_123')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cart Total: Rs. 100.0'), findsOneWidget);
    });

    testWidgets('F3_T3: Decrementing item quantity updates cart total correctly', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '123', name: 'Milk', barcode: '123', sellingPrice: 50.0, costPrice: 40.0, markup: 25.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), '123');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('increment_qty_123')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('decrement_qty_123')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cart Total: Rs. 50.0'), findsOneWidget);
    });

    testWidgets('F3_T4: Decrementing item quantity to zero removes it from the cart', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '123', name: 'Milk', barcode: '123', sellingPrice: 50.0, costPrice: 40.0, markup: 25.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), '123');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('decrement_qty_123')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cart Total: Rs. 0.0'), findsOneWidget);
      expect(find.text('Milk'), findsNothing);
    });

    testWidgets('F3_T5: Multiple distinct items in cart are listed correctly with correct subtotal', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '123', name: 'Milk', barcode: '123', sellingPrice: 50.0, costPrice: 40.0, markup: 25.0));
      await firestore.saveProduct(Product(id: '456', name: 'Egg', barcode: '456', sellingPrice: 10.0, costPrice: 8.0, markup: 25.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), '123');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), '456');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Egg'), findsOneWidget);
      expect(find.textContaining('Cart Total: Rs. 60.0'), findsOneWidget);
    });

    // ==========================================
    // FEATURE 4: Paid/Credit & Receipt Sharing
    // ==========================================

    testWidgets('F4_T1: Toggle paid/credit state updates UI status text', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      expect(find.text('Paid'), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.paidCreditToggle));
      await tester.pumpAndSettle();

      expect(find.text('Credit'), findsOneWidget);
    });

    testWidgets('F4_T2: Pressing checkout button sets checkout complete status', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '123', name: 'Milk', barcode: '123', sellingPrice: 50.0, costPrice: 40.0, markup: 25.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), '123');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.checkoutButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Checkout complete'), findsOneWidget);
    });

    testWidgets('F4_T3: Share receipt triggers SharingService and records last shared receipt text', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '123', name: 'Milk', barcode: '123', sellingPrice: 50.0, costPrice: 40.0, markup: 25.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), '123');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.customerPhoneInput), '9841000000');
      await tester.tap(find.byKey(AppKeys.shareReceiptButton));
      await tester.pumpAndSettle();

      final sharing = locator<SharingService>() as FakeSharingService;
      expect(sharing.shareCount, 1);
      expect(sharing.lastSharedReceiptText, contains('Milk'));
      expect(sharing.lastSharedReceiptText, contains('Total: Rs. 50.0'));
    });

    testWidgets('F4_T4: Share receipt records correct customer phone number in SharingService', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '123', name: 'Milk', barcode: '123', sellingPrice: 50.0, costPrice: 40.0, markup: 25.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), '123');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.customerPhoneInput), '9841984198');
      await tester.tap(find.byKey(AppKeys.shareReceiptButton));
      await tester.pumpAndSettle();

      final sharing = locator<SharingService>() as FakeSharingService;
      expect(sharing.lastSharedPhoneNumber, '9841984198');
    });

    testWidgets('F4_T5: Share receipt without phone number fails and displays error', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '123', name: 'Milk', barcode: '123', sellingPrice: 50.0, costPrice: 40.0, markup: 25.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), '123');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.shareReceiptButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Enter phone number first'), findsOneWidget);
    });

    // ==========================================
    // FEATURE 5: Barcode Scanner & Matching
    // ==========================================

    testWidgets('F5_T1: Tapping Scan Barcode button invokes ScannerService.scan and updates cart on success', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '888', name: 'Chips', barcode: '888', sellingPrice: 20.0, costPrice: 15.0, markup: 33.3));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      final scanner = locator<ScannerService>() as FakeScannerService;

      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump();

      await tester.runAsync(() async {
        scanner.simulateScan('888');
        await Future.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      expect(find.text('Chips'), findsOneWidget);
      expect(find.textContaining('Cart Total: Rs. 20.0'), findsOneWidget);
    });

    testWidgets('F5_T2: Tapping Scan Barcode triggers ScannerService feedback on success', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '888', name: 'Chips', barcode: '888', sellingPrice: 20.0, costPrice: 15.0, markup: 33.3));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      final scanner = locator<ScannerService>() as FakeScannerService;
      expect(scanner.feedbackCount, 0);

      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump();

      await tester.runAsync(() async {
        scanner.simulateScan('888');
        await Future.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      expect(scanner.feedbackCount, 1);
    });

    testWidgets('F5_T3: Scan of non-existent product shows "Product not found" in status', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      final scanner = locator<ScannerService>() as FakeScannerService;

      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump();

      await tester.runAsync(() async {
        scanner.simulateScan('999999');
        await Future.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('Product not found: 999999'), findsOneWidget);
    });

    testWidgets('F5_T4: Scanning same barcode multiple times increments its quantity in cart', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '888', name: 'Chips', barcode: '888', sellingPrice: 20.0, costPrice: 15.0, markup: 33.3));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      final scanner = locator<ScannerService>() as FakeScannerService;

      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump();
      await tester.runAsync(() async {
        scanner.simulateScan('888');
        await Future.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump();
      await tester.runAsync(() async {
        scanner.simulateScan('888');
        await Future.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('Cart Total: Rs. 40.0'), findsOneWidget);
    });

    testWidgets('F5_T5: Scan feedback counter increments on every successful scan addition', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '888', name: 'Chips', barcode: '888', sellingPrice: 20.0, costPrice: 15.0, markup: 33.3));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      final scanner = locator<ScannerService>() as FakeScannerService;

      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump();
      await tester.runAsync(() async {
        scanner.simulateScan('888');
        await Future.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump();
      await tester.runAsync(() async {
        scanner.simulateScan('888');
        await Future.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      expect(scanner.feedbackCount, 2);
    });

    // ==========================================
    // FEATURE 6: Vendor Invoice Ingestor & Markup
    // ==========================================

    testWidgets('F6_T1: Capture invoice photo triggers CameraService and updates image path display', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToInvoiceIngestor));
      await tester.pumpAndSettle();

      final camera = locator<CameraService>() as FakeCameraService;
      expect(camera.captureCount, 0);

      await tester.tap(find.byKey(AppKeys.captureInvoiceButton));
      await tester.pumpAndSettle();

      expect(camera.captureCount, 1);
      expect(find.textContaining('Photo captured successfully: /mock/path/to/invoice.jpg'), findsOneWidget);
    });

    testWidgets('F6_T2: Markup calculator computes selling price correctly from cost and markup inputs', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToInvoiceIngestor));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.costPriceInput), '100');
      await tester.enterText(find.byKey(AppKeys.markupInput), '25');
      await tester.pumpAndSettle();

      expect(find.textContaining('Calculated Selling Price: Rs. 125.0'), findsOneWidget);
    });

    testWidgets('F6_T3: Saving ingested product writes it to FakeFirestoreService', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToInvoiceIngestor));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), 'inv_001');
      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Ingested Apple');
      await tester.enterText(find.byKey(AppKeys.costPriceInput), '100');
      await tester.enterText(find.byKey(AppKeys.markupInput), '25');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.saveInvoiceProductButton));
      await tester.pumpAndSettle();

      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      final product = await firestore.getProduct('inv_001');
      expect(product, isNotNull);
      expect(product!.name, 'Ingested Apple');
      expect(product.costPrice, 100.0);
      expect(product.markup, 25.0);
    });

    testWidgets('F6_T4: Ingested product selling price in database matches the calculated markup price', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToInvoiceIngestor));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), 'inv_001');
      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Ingested Apple');
      await tester.enterText(find.byKey(AppKeys.costPriceInput), '200');
      await tester.enterText(find.byKey(AppKeys.markupInput), '10');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.saveInvoiceProductButton));
      await tester.pumpAndSettle();

      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      final product = await firestore.getProduct('inv_001');
      expect(product!.sellingPrice, 220.0);
    });

    testWidgets('F6_T5: Empty fields on ingestor screen display validation error message', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToInvoiceIngestor));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.saveInvoiceProductButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Barcode and Name are required'), findsOneWidget);
    });
  });

  group('Tier 2 - Boundary & Corner Cases', () {
    setUp(() {
      setupLocator(useFakes: true);
    });

    // ==========================================
    // FEATURE 1: Device Activation & Tracking
    // ==========================================

    testWidgets('F1_T2_1: Store activation with trimmed whitespace-only inputs shows error', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.storeIdInput), '   ');
      await tester.enterText(find.byKey(AppKeys.storeNameInput), '   ');
      await tester.tap(find.byKey(AppKeys.activateStoreButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Store ID and Name required'), findsOneWidget);
    });

    testWidgets('F1_T2_2: Store activation with non-alphanumeric Store ID shows error', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.storeIdInput), 'shop-123!');
      await tester.enterText(find.byKey(AppKeys.storeNameInput), 'My Shop');
      await tester.tap(find.byKey(AppKeys.activateStoreButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Store ID must be alphanumeric'), findsOneWidget);
    });

    testWidgets('F1_T2_3: Device registration with trimmed whitespace-only inputs shows error', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.storeIdInput), '   ');
      await tester.enterText(find.byKey(AppKeys.deviceIdInput), '   ');
      await tester.tap(find.byKey(AppKeys.registerDeviceButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Store ID and Device ID required'), findsOneWidget);
    });

    testWidgets('F1_T2_4: Device registration with malformed JSON metadata falls back to raw string', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.storeIdInput), 'st1');
      await tester.enterText(find.byKey(AppKeys.deviceIdInput), 'd1');
      await tester.enterText(find.byKey(AppKeys.deviceMetadataInput), '{invalid_json');
      await tester.tap(find.byKey(AppKeys.registerDeviceButton));
      await tester.pumpAndSettle();

      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      expect(firestore.devices['st1']?['d1']?['raw'], '{invalid_json');
    });

    testWidgets('F1_T2_5: Device registration fails when store is not activated', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      firestore.checkStoreActivation = true;

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.storeIdInput), 'st_not_active');
      await tester.enterText(find.byKey(AppKeys.deviceIdInput), 'd1');
      await tester.tap(find.byKey(AppKeys.registerDeviceButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Exception: Store not activated'), findsOneWidget);
    });

    // ==========================================
    // FEATURE 2: Firestore Product Catalog & Seeding
    // ==========================================

    testWidgets('F2_T2_1: Add product manually with whitespace-only inputs shows error', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCatalog));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productNameInput), '   ');
      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), '   ');
      await tester.tap(find.byKey(AppKeys.saveProductButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Name and Barcode required'), findsOneWidget);
    });

    testWidgets('F2_T2_2: Add product manually with negative prices/markup is rejected', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCatalog));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Negative Product');
      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), 'neg123');
      await tester.enterText(find.byKey(AppKeys.productSellingPriceInput), '-12.0');
      await tester.enterText(find.byKey(AppKeys.productCostPriceInput), '-10.0');
      await tester.enterText(find.byKey(AppKeys.productMarkupInput), '-5.0');
      await tester.tap(find.byKey(AppKeys.saveProductButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Prices and markup must be non-negative'), findsOneWidget);
    });

    testWidgets('F2_T2_3: Add product manually with non-numeric inputs shows error', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCatalog));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Bad Input');
      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), 'bad123');
      await tester.enterText(find.byKey(AppKeys.productSellingPriceInput), 'abc');
      await tester.enterText(find.byKey(AppKeys.productCostPriceInput), 'def');
      await tester.enterText(find.byKey(AppKeys.productMarkupInput), 'ghi');
      await tester.tap(find.byKey(AppKeys.saveProductButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Prices and markup must be valid numbers'), findsOneWidget);
    });

    testWidgets('F2_T2_4: Add product manually with selling price lower than cost price is rejected', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCatalog));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Lower Price Product');
      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), 'low123');
      await tester.enterText(find.byKey(AppKeys.productSellingPriceInput), '90.0');
      await tester.enterText(find.byKey(AppKeys.productCostPriceInput), '100.0');
      await tester.enterText(find.byKey(AppKeys.productMarkupInput), '10.0');
      await tester.tap(find.byKey(AppKeys.saveProductButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Selling price cannot be less than cost price'), findsOneWidget);
    });

    testWidgets('F2_T2_5: Add product manually with duplicate barcode overwrites product details', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCatalog));
      await tester.pumpAndSettle();

      // First addition
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Bread Old');
      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), 'col_1');
      await tester.enterText(find.byKey(AppKeys.productSellingPriceInput), '40.0');
      await tester.tap(find.byKey(AppKeys.saveProductButton));
      await tester.pumpAndSettle();

      // Second addition (with same barcode)
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Bread New');
      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), 'col_1');
      await tester.enterText(find.byKey(AppKeys.productSellingPriceInput), '45.0');
      await tester.tap(find.byKey(AppKeys.saveProductButton));
      await tester.pumpAndSettle();

      expect(find.text('Bread New'), findsOneWidget);
      expect(find.text('Bread Old'), findsNothing);
    });

    // ==========================================
    // FEATURE 3: Cart Management & Calculations
    // ==========================================

    testWidgets('F3_T2_1: Cart manual barcode lookup with empty/whitespace input shows error', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), '   ');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Barcode is empty'), findsOneWidget);
    });

    testWidgets('F3_T2_2: Quantity increment behaves correctly for multiple clicks', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '123', name: 'Milk', barcode: '123', sellingPrice: 10.0, costPrice: 8.0, markup: 25.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), '123');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      final incBtn = find.byKey(const ValueKey('increment_qty_123'));
      for (int i = 0; i < 5; i++) {
        await tester.tap(incBtn);
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('Cart Total: Rs. 60.00'), findsOneWidget);
    });

    testWidgets('F3_T2_3: Decrementing quantity to zero removes item widget completely', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '123', name: 'Milk', barcode: '123', sellingPrice: 10.0, costPrice: 8.0, markup: 25.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), '123');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      final decBtn = find.byKey(const ValueKey('decrement_qty_123'));
      await tester.tap(decBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Cart Total: Rs. 0.00'), findsOneWidget);
      expect(find.text('Milk'), findsNothing);
    });

    testWidgets('F3_T2_4: Product with Rs. 0.00 selling price is added successfully', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: 'free', name: 'Free Item', barcode: 'free', sellingPrice: 0.0, costPrice: 0.0, markup: 0.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'free');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      expect(find.text('Free Item'), findsOneWidget);
      expect(find.textContaining('Cart Total: Rs. 0.00'), findsOneWidget);
    });

    testWidgets('F3_T2_5: Cart ListView renders items with product-specific keys', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: 'item1', name: 'Item One', barcode: 'item1', sellingPrice: 10.0, costPrice: 8.0, markup: 25.0));
      await firestore.saveProduct(Product(id: 'item2', name: 'Item Two', barcode: 'item2', sellingPrice: 20.0, costPrice: 15.0, markup: 33.3));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'item1');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'item2');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      // Only increment item1
      await tester.tap(find.byKey(const ValueKey('increment_qty_item1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cart Total: Rs. 40.00'), findsOneWidget);
    });

    // ==========================================
    // FEATURE 4: Paid/Credit & Receipt Sharing
    // ==========================================

    testWidgets('F4_T2_1: Share receipt with empty cart displays error', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.customerPhoneInput), '9841234567');
      await tester.tap(find.byKey(AppKeys.shareReceiptButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Cart is empty, cannot share receipt'), findsOneWidget);
    });

    testWidgets('F4_T2_2: Share receipt with invalid phone format shows error', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: 'item1', name: 'Item One', barcode: 'item1', sellingPrice: 10.0, costPrice: 8.0, markup: 25.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'item1');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.customerPhoneInput), '12345');
      await tester.tap(find.byKey(AppKeys.shareReceiptButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Invalid phone number format'), findsOneWidget);
    });

    testWidgets('F4_T2_3: Shared receipt text tracks pending vs completed checkout status', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: 'item1', name: 'Item One', barcode: 'item1', sellingPrice: 10.0, costPrice: 8.0, markup: 25.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'item1');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.customerPhoneInput), '9841234567');
      await tester.tap(find.byKey(AppKeys.shareReceiptButton));
      await tester.pumpAndSettle();

      final sharing = locator<SharingService>() as FakeSharingService;
      expect(sharing.lastSharedReceiptText, contains('Status: Pending'));

      await tester.tap(find.byKey(AppKeys.checkoutButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.shareReceiptButton));
      await tester.pumpAndSettle();

      expect(sharing.lastSharedReceiptText, contains('Status: Completed'));
    });

    testWidgets('F4_T2_4: Re-adding items after checkout resets checkout status', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: 'item1', name: 'Item One', barcode: 'item1', sellingPrice: 10.0, costPrice: 8.0, markup: 25.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'item1');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.checkoutButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('Checkout complete'), findsOneWidget);

      // Re-add/increment item to reset checkout status
      await tester.tap(find.byKey(const ValueKey('increment_qty_item1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Checkout complete'), findsNothing);
    });

    testWidgets('F4_T2_5: Share receipt exception handling on native share channel', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: 'item1', name: 'Item One', barcode: 'item1', sellingPrice: 10.0, costPrice: 8.0, markup: 25.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'item1');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.customerPhoneInput), '9841234567');

      final sharing = locator<SharingService>() as FakeSharingService;
      sharing.throwError = true;

      await tester.tap(find.byKey(AppKeys.shareReceiptButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Share error: Exception: share_failed'), findsOneWidget);
    });

    // ==========================================
    // FEATURE 5: Barcode Scanner & Matching
    // ==========================================

    testWidgets('F5_T2_1: Canceled scan returning null is handled gracefully', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      final scanner = locator<ScannerService>() as FakeScannerService;

      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump();

      await tester.runAsync(() async {
        scanner.simulateScan('__null__');
        await Future.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('Scan cancelled'), findsOneWidget);
    });

    testWidgets('F5_T2_2: Scanner service hardware exception does not crash app', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      final scanner = locator<ScannerService>() as FakeScannerService;
      scanner.errorToThrow = 'Camera permission denied';

      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Scan error: Exception: Camera permission denied'), findsOneWidget);
    });

    testWidgets('F5_T2_3: Successive scanner triggers do not cause state race condition', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '888', name: 'Chips', barcode: '888', sellingPrice: 20.0, costPrice: 15.0, markup: 33.3));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      final scanner = locator<ScannerService>() as FakeScannerService;

      // Tap scan button twice rapidly
      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump();

      await tester.runAsync(() async {
        scanner.simulateScan('888');
        await Future.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      expect(find.text('Chips'), findsOneWidget);
      expect(find.textContaining('Cart Total: Rs. 20.00'), findsOneWidget);
    });

    testWidgets('F5_T2_4: Scanner returning empty string is rejected', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      final scanner = locator<ScannerService>() as FakeScannerService;

      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump();

      await tester.runAsync(() async {
        scanner.simulateScan('   ');
        await Future.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('Scan cancelled'), findsOneWidget);
    });

    testWidgets('F5_T2_5: Haptic feedback vibrate exception does not break scan add flow', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '888', name: 'Chips', barcode: '888', sellingPrice: 20.0, costPrice: 15.0, markup: 33.3));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      final scanner = locator<ScannerService>() as FakeScannerService;
      scanner.throwFeedbackError = true;

      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump();

      await tester.runAsync(() async {
        scanner.simulateScan('888');
        await Future.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      expect(find.text('Chips'), findsOneWidget);
      expect(find.textContaining('Cart Total: Rs. 20.00'), findsOneWidget);
    });

    testWidgets('F5_T2_6: Continuous Scanning: Simulated scan of multiple products successively succeeds without re-tapping scan button', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '888', name: 'Chips', barcode: '888', sellingPrice: 20.0, costPrice: 15.0, markup: 33.3));
      await firestore.saveProduct(Product(id: '999', name: 'Soda', barcode: '999', sellingPrice: 15.0, costPrice: 10.0, markup: 50.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      final scanner = locator<ScannerService>() as FakeScannerService;

      // Start scanning
      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump(); // Start the loop

      // First simulated scan (Chips)
      await tester.runAsync(() async {
        scanner.simulateScan('888');
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      // Second simulated scan (Soda) without re-tapping
      await tester.runAsync(() async {
        scanner.simulateScan('999');
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      expect(find.text('Chips'), findsOneWidget);
      expect(find.text('Soda'), findsOneWidget);
      expect(find.textContaining('Cart Total: Rs. 35.00'), findsOneWidget);
    });

    testWidgets('F5_T2_7: Split-screen UI: Scanned items list is visible and updates in real-time while the scanner is active', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '888', name: 'Chips', barcode: '888', sellingPrice: 20.0, costPrice: 15.0, markup: 33.3));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      final scanner = locator<ScannerService>() as FakeScannerService;

      // Tap scan button to activate split-screen
      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump();

      // Verify that the split-screen view is visible
      expect(find.byKey(const Key('scanPreview')), findsOneWidget);
      expect(find.byKey(AppKeys.doneScanningButton), findsOneWidget);
      // Verify empty cart list is visible
      expect(find.textContaining('Cart Total: Rs. 0.00'), findsOneWidget);

      // Perform a scan
      await tester.runAsync(() async {
        scanner.simulateScan('888');
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      // Verify that scanner is still active and split screen is still visible
      expect(find.byKey(const Key('scanPreview')), findsOneWidget);
      expect(find.byKey(AppKeys.doneScanningButton), findsOneWidget);

      // Verify that the cart updates in real-time with the scanned item
      expect(find.text('Chips'), findsOneWidget);
      expect(find.textContaining('Cart Total: Rs. 20.00'), findsOneWidget);
    });

    testWidgets('F5_T2_8: Done Scanning button: Tapping doneScanningButton turns off scanning state and closes camera view', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: '888', name: 'Chips', barcode: '888', sellingPrice: 20.0, costPrice: 15.0, markup: 33.3));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      final scanner = locator<ScannerService>() as FakeScannerService;

      // Start scanning
      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump();

      // Verify camera preview is open (scanning is active)
      expect(find.byKey(const Key('scanPreview')), findsOneWidget);
      expect(find.byKey(AppKeys.doneScanningButton), findsOneWidget);

      // Tap Done Scanning button
      await tester.tap(find.byKey(AppKeys.doneScanningButton));
      await tester.pumpAndSettle();

      // Verify camera preview is closed
      expect(find.byKey(const Key('scanPreview')), findsNothing);
      expect(find.byKey(AppKeys.doneScanningButton), findsNothing);

      // Verify we are back to the main checkout screen (e.g. manual barcode input is visible)
      expect(find.byKey(AppKeys.productSearchInput), findsOneWidget);
      expect(find.textContaining('Scanning stopped'), findsOneWidget);
    });

    // ==========================================
    // FEATURE 6: Vendor Invoice Ingestor & Markup
    // ==========================================

    testWidgets('F6_T2_1: Ingestor validation - Negative cost price or negative markup validation', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToInvoiceIngestor));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), 'neg_inv');
      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Neg Ingest');
      await tester.enterText(find.byKey(AppKeys.costPriceInput), '-50');
      await tester.enterText(find.byKey(AppKeys.markupInput), '10');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.captureInvoiceButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.saveInvoiceProductButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Cost and markup must be non-negative'), findsOneWidget);
    });

    testWidgets('F6_T2_2: Ingestor validation - Non-numeric inputs show validation error', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToInvoiceIngestor));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), 'bad_inv');
      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Bad Ingest');
      await tester.enterText(find.byKey(AppKeys.costPriceInput), 'abc');
      await tester.enterText(find.byKey(AppKeys.markupInput), 'xyz');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.captureInvoiceButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.saveInvoiceProductButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Cost and markup must be valid numbers'), findsOneWidget);
    });

    testWidgets('F6_T2_3: Camera photo capture cancellation handling', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToInvoiceIngestor));
      await tester.pumpAndSettle();

      final camera = locator<CameraService>() as FakeCameraService;
      camera.returnNull = true;

      await tester.tap(find.byKey(AppKeys.captureInvoiceButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Photo capture cancelled'), findsOneWidget);
    });

    testWidgets('F6_T2_4: Camera service permission exception handling', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToInvoiceIngestor));
      await tester.pumpAndSettle();

      final camera = locator<CameraService>() as FakeCameraService;
      camera.errorToThrow = 'Camera error';

      await tester.tap(find.byKey(AppKeys.captureInvoiceButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Capture error: Exception: Camera error'), findsOneWidget);
    });

    testWidgets('F6_T2_5: Ingestor validation - Mandatory invoice photo', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToInvoiceIngestor));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), 'i_man');
      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Mandatory Photo');
      await tester.enterText(find.byKey(AppKeys.costPriceInput), '100');
      await tester.enterText(find.byKey(AppKeys.markupInput), '20');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.saveInvoiceProductButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Invoice photo is required'), findsOneWidget);
    });

    testWidgets('F6_T2_6: Markup calculations format precision correctly (double precision overflow)', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.navToInvoiceIngestor));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), 'i_prec');
      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Precision Product');
      await tester.enterText(find.byKey(AppKeys.costPriceInput), '10.55');
      await tester.enterText(find.byKey(AppKeys.markupInput), '15.5');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.captureInvoiceButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Calculated Selling Price: Rs. 12.19'), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.saveInvoiceProductButton));
      await tester.pumpAndSettle();

      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      final product = await firestore.getProduct('i_prec');
      expect(product!.sellingPrice, 12.19);
    });
  });

  group('Tier 3 - Cross-Feature Combinations', () {
    setUp(() {
      setupLocator(useFakes: true);
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('F6_F2_T1: Ingest product via Invoice Ingestor, save, navigate to Catalog and verify streamed and searchable with correct selling price', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      
      // First, activate the store to unlock navigation
      await tester.enterText(find.byKey(AppKeys.storeIdInput), 'shop101');
      await tester.enterText(find.byKey(AppKeys.storeNameInput), 'Mega Mart');
      await tester.tap(find.byKey(AppKeys.activateStoreButton));
      await tester.pumpAndSettle();

      // Navigate to Invoice Ingestor
      await tester.tap(find.byKey(AppKeys.navToInvoiceIngestor));
      await tester.pumpAndSettle();

      // Capture photo
      await tester.tap(find.byKey(AppKeys.captureInvoiceButton));
      await tester.pumpAndSettle();

      // Fill in invoice ingestion fields
      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), 'ingest_test_1');
      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Fresh Orange Juice');
      await tester.enterText(find.byKey(AppKeys.costPriceInput), '80.0');
      await tester.enterText(find.byKey(AppKeys.markupInput), '25.0');
      await tester.pumpAndSettle();

      expect(find.textContaining('Calculated Selling Price: Rs. 100.00'), findsOneWidget);

      // Save the product
      await tester.tap(find.byKey(AppKeys.saveInvoiceProductButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('Invoice product saved successfully'), findsOneWidget);

      // Navigate to Catalog screen
      await tester.tap(find.byKey(AppKeys.navToCatalog));
      await tester.pumpAndSettle();

      // Verify product is streamed and listed in the catalog with correct price
      expect(find.text('Fresh Orange Juice'), findsOneWidget);
      expect(find.text('Rs. 100.0'), findsOneWidget);

      // Search for the product using barcode
      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'ingest_test_1');
      await tester.pumpAndSettle();
      expect(find.text('Fresh Orange Juice'), findsOneWidget);

      // Search for the product using name
      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'Orange');
      await tester.pumpAndSettle();
      expect(find.text('Fresh Orange Juice'), findsOneWidget);

      // Search for another string to verify filtering
      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'nonexistent');
      await tester.pumpAndSettle();
      expect(find.text('Fresh Orange Juice'), findsNothing);
    });

    testWidgets('F6_F5_F3_T2: Ingest product via Invoice Ingestor, go to Checkout, scan and verify split-screen real-time cart update and total', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      
      // Activate store
      await tester.enterText(find.byKey(AppKeys.storeIdInput), 'shop101');
      await tester.enterText(find.byKey(AppKeys.storeNameInput), 'Mega Mart');
      await tester.tap(find.byKey(AppKeys.activateStoreButton));
      await tester.pumpAndSettle();

      // Navigate to Invoice Ingestor
      await tester.tap(find.byKey(AppKeys.navToInvoiceIngestor));
      await tester.pumpAndSettle();

      // Capture photo
      await tester.tap(find.byKey(AppKeys.captureInvoiceButton));
      await tester.pumpAndSettle();

      // Fill in invoice ingestion fields
      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), 'ingest_test_2');
      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Ingested Soda');
      await tester.enterText(find.byKey(AppKeys.costPriceInput), '50.0');
      await tester.enterText(find.byKey(AppKeys.markupInput), '10.0');
      await tester.pumpAndSettle();

      expect(find.textContaining('Calculated Selling Price: Rs. 55.00'), findsOneWidget);

      // Save product
      await tester.tap(find.byKey(AppKeys.saveInvoiceProductButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('Invoice product saved successfully'), findsOneWidget);

      // Go to Checkout
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      // Tap Scan Barcode
      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump();

      // Verify camera view key('scanPreview') and doneScanningButton are visible (split-screen mode)
      expect(find.byKey(const Key('scanPreview')), findsOneWidget);
      expect(find.byKey(AppKeys.doneScanningButton), findsOneWidget);

      // Simulate scan of that barcode via FakeScannerService
      final scanner = locator<ScannerService>() as FakeScannerService;
      expect(scanner.feedbackCount, 0);
      await tester.runAsync(() async {
        scanner.simulateScan('ingest_test_2');
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(scanner.feedbackCount, 1);

      // Verify item added to cart in split-screen in real-time
      expect(find.text('Ingested Soda'), findsOneWidget);
      // Verify cart total is 55.00
      expect(find.textContaining('Cart Total: Rs. 55.00'), findsOneWidget);

      // Tap Done Scanning
      await tester.tap(find.byKey(AppKeys.doneScanningButton));
      await tester.pumpAndSettle();

      // Verify camera view is closed
      expect(find.byKey(const Key('scanPreview')), findsNothing);
    });

    testWidgets('F1_F3_F4_T3: Verify navigation is locked before activation, activate store and register device, navigate to checkout, add seeded item, toggle Credit, checkout, share receipt, and verify receipt details', (tester) async {
      // Seed product in Firestore
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(
        id: 'seeded_item_3',
        name: 'Seeded Apple',
        barcode: 'seeded_item_3',
        sellingPrice: 100.0,
        costPrice: 80.0,
        markup: 25.0,
      ));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();

      // 1. Verify navigation is locked before activation
      expect(find.byKey(AppKeys.activateStoreButton), findsOneWidget);
      expect(find.byKey(AppKeys.addProductButton), findsNothing);

      // Try navigating to Catalog screen (should do nothing because button is disabled)
      await tester.tap(find.byKey(AppKeys.navToCatalog));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.addProductButton), findsNothing);
      expect(find.byKey(AppKeys.activateStoreButton), findsOneWidget);

      // Try navigating to Checkout screen (should do nothing because button is disabled)
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.scanBarcodeButton), findsNothing);
      expect(find.byKey(AppKeys.activateStoreButton), findsOneWidget);

      // 2. Activate store and register device
      await tester.enterText(find.byKey(AppKeys.storeIdInput), 'shop101');
      await tester.enterText(find.byKey(AppKeys.storeNameInput), 'Mega Mart');
      await tester.enterText(find.byKey(AppKeys.deviceIdInput), 'dev101');
      await tester.enterText(find.byKey(AppKeys.deviceMetadataInput), '{"os": "Android"}');
      await tester.tap(find.byKey(AppKeys.activateStoreButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Store Activated Successfully: Mega Mart'), findsOneWidget);

      // Verify it saved device and store in Firestore
      expect(firestore.stores['shop101'], 'Mega Mart');
      expect(firestore.devices['shop101']?['dev101']?['os'], 'Android');

      // 3. Navigate to Checkout (now unlocked)
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.scanBarcodeButton), findsOneWidget);

      // 4. Add seeded item
      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'seeded_item_3');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();
      expect(find.text('Seeded Apple'), findsOneWidget);
      expect(find.textContaining('Cart Total: Rs. 100.00'), findsOneWidget);

      // 5. Toggle payment to Credit
      expect(find.text('Paid'), findsOneWidget);
      await tester.tap(find.byKey(AppKeys.paidCreditToggle));
      await tester.pumpAndSettle();
      expect(find.text('Credit'), findsOneWidget);

      // 6. Enter phone number
      await tester.enterText(find.byKey(AppKeys.customerPhoneInput), '9841234567');
      await tester.pumpAndSettle();

      // 7. Checkout
      await tester.tap(find.byKey(AppKeys.checkoutButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('Checkout complete'), findsOneWidget);

      // 8. Share receipt
      await tester.tap(find.byKey(AppKeys.shareReceiptButton));
      await tester.pumpAndSettle();

      // 9. Verify receipt text contains payment Credit, status Completed, phone number, and item
      final sharing = locator<SharingService>() as FakeSharingService;
      expect(sharing.shareCount, 1);
      expect(sharing.lastSharedPhoneNumber, '9841234567');
      expect(sharing.lastSharedReceiptText, contains('Seeded Apple x1 - Rs. 100.00'));
      expect(sharing.lastSharedReceiptText, contains('Payment: Credit'));
      expect(sharing.lastSharedReceiptText, contains('Status: Completed'));
    });

    testWidgets('F2_F3_F4_T4: Catalog screen manually add product, search catalog to verify DB write, checkout screen manual barcode lookup, add to cart, enter phone number, share receipt, and verify receipt items', (tester) async {
      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      
      // Activate store
      await tester.enterText(find.byKey(AppKeys.storeIdInput), 'shop101');
      await tester.enterText(find.byKey(AppKeys.storeNameInput), 'Mega Mart');
      await tester.tap(find.byKey(AppKeys.activateStoreButton));
      await tester.pumpAndSettle();

      // 1. Go to Catalog screen
      await tester.tap(find.byKey(AppKeys.navToCatalog));
      await tester.pumpAndSettle();

      // 2. Add product manually
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Catalog Mango');
      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), 'catalog_item_4');
      await tester.enterText(find.byKey(AppKeys.productSellingPriceInput), '120.0');
      await tester.enterText(find.byKey(AppKeys.productCostPriceInput), '90.0');
      await tester.enterText(find.byKey(AppKeys.productMarkupInput), '33.33');
      await tester.tap(find.byKey(AppKeys.saveProductButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Product Saved: Catalog Mango'), findsOneWidget);

      // 3. Search catalog to verify database write
      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'catalog_item_4');
      await tester.pumpAndSettle();
      expect(find.text('Catalog Mango'), findsOneWidget);

      // 4. Navigate to Checkout screen
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      // 5. Manual barcode lookup
      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'catalog_item_4');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      // 6. Verify added to cart
      expect(find.text('Catalog Mango'), findsOneWidget);
      expect(find.textContaining('Cart Total: Rs. 120.00'), findsOneWidget);

      // 7. Enter phone number
      await tester.enterText(find.byKey(AppKeys.customerPhoneInput), '9841234567');
      await tester.pumpAndSettle();

      // 8. Tap share receipt
      await tester.tap(find.byKey(AppKeys.shareReceiptButton));
      await tester.pumpAndSettle();

      // 9. Verify FakeSharingService receipt has correct items
      final sharing = locator<SharingService>() as FakeSharingService;
      expect(sharing.shareCount, 1);
      expect(sharing.lastSharedPhoneNumber, '9841234567');
      expect(sharing.lastSharedReceiptText, contains('Catalog Mango x1 - Rs. 120.00'));
    });

    testWidgets('F5_F3_F4_T5: Checkout screen scan product 1 and 2, Done scanning, increment product 1, decrement product 2 to 0, enter phone, share receipt, and verify receipt content', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      await firestore.saveProduct(Product(id: 'prod_1', name: 'Product One', barcode: 'prod_1', sellingPrice: 50.0, costPrice: 40.0, markup: 25.0));
      await firestore.saveProduct(Product(id: 'prod_2', name: 'Product Two', barcode: 'prod_2', sellingPrice: 30.0, costPrice: 20.0, markup: 50.0));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      
      // Activate store
      await tester.enterText(find.byKey(AppKeys.storeIdInput), 'shop101');
      await tester.enterText(find.byKey(AppKeys.storeNameInput), 'Mega Mart');
      await tester.tap(find.byKey(AppKeys.activateStoreButton));
      await tester.pumpAndSettle();

      // Navigate to Checkout
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      // Tap scan barcode
      await tester.tap(find.byKey(AppKeys.scanBarcodeButton));
      await tester.pump();

      final scanner = locator<ScannerService>() as FakeScannerService;
      expect(scanner.feedbackCount, 0);

      // Simulate scan of product 1 and product 2
      await tester.runAsync(() async {
        scanner.simulateScan('prod_1');
        await Future.delayed(const Duration(milliseconds: 150));
        scanner.simulateScan('prod_2');
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(scanner.feedbackCount, 2);

      // Tap Done scanning
      await tester.tap(find.byKey(AppKeys.doneScanningButton));
      await tester.pumpAndSettle();

      // Verify cart has both products
      expect(find.text('Product One'), findsOneWidget);
      expect(find.text('Product Two'), findsOneWidget);
      expect(find.textContaining('Cart Total: Rs. 80.00'), findsOneWidget);

      // Increment product 1 quantity (now 2)
      await tester.tap(find.byKey(const ValueKey('increment_qty_prod_1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cart Total: Rs. 130.00'), findsOneWidget);

      // Decrement product 2 quantity (from 1 to 0, removing it)
      await tester.tap(find.byKey(const ValueKey('decrement_qty_prod_2')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cart Total: Rs. 100.00'), findsOneWidget);
      expect(find.text('Product Two'), findsNothing);

      // Enter phone number
      await tester.enterText(find.byKey(AppKeys.customerPhoneInput), '9841234567');
      await tester.pumpAndSettle();

      // Share receipt
      await tester.tap(find.byKey(AppKeys.shareReceiptButton));
      await tester.pumpAndSettle();

      // Verify receipt only has product 1 x2
      final sharing = locator<SharingService>() as FakeSharingService;
      expect(sharing.shareCount, 1);
      expect(sharing.lastSharedPhoneNumber, '9841234567');
      expect(sharing.lastSharedReceiptText, contains('Product One x2 - Rs. 100.00'));
      expect(sharing.lastSharedReceiptText, isNot(contains('Product Two')));
    });

    testWidgets('F6_F5_F4_F3_T6: Ingest product with precision price, add with seeded cheap item to checkout, verify subtotal, checkout, reset on increment, quantity limits, and phone validation errors', (tester) async {
      final firestore = locator<FirestoreService>() as FakeFirestoreService;
      // Seed Rs. 5.50 item
      await firestore.saveProduct(Product(
        id: 'seeded_5_50',
        name: 'Seeded Cheap Item',
        barcode: 'seeded_5_50',
        sellingPrice: 5.50,
        costPrice: 4.0,
        markup: 37.5,
      ));

      await tester.pumpWidget(MyApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      
      // Activate store
      await tester.enterText(find.byKey(AppKeys.storeIdInput), 'shop101');
      await tester.enterText(find.byKey(AppKeys.storeNameInput), 'Mega Mart');
      await tester.tap(find.byKey(AppKeys.activateStoreButton));
      await tester.pumpAndSettle();

      // 1. Ingest product with cost=10.55, markup=15.5 (selling=12.19)
      await tester.tap(find.byKey(AppKeys.navToInvoiceIngestor));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.captureInvoiceButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.productBarcodeInput), 'bulk_biscuit_007');
      await tester.enterText(find.byKey(AppKeys.productNameInput), 'Ingested Biscuit');
      await tester.enterText(find.byKey(AppKeys.costPriceInput), '10.55');
      await tester.enterText(find.byKey(AppKeys.markupInput), '15.5');
      await tester.pumpAndSettle();

      expect(find.textContaining('Calculated Selling Price: Rs. 12.19'), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.saveInvoiceProductButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('Invoice product saved successfully'), findsOneWidget);

      // 2. Go to Checkout
      await tester.tap(find.byKey(AppKeys.navToCheckout));
      await tester.pumpAndSettle();

      // Add ingested product
      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'bulk_biscuit_007');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      // Add seeded Rs. 5.50 item
      await tester.enterText(find.byKey(AppKeys.productSearchInput), 'seeded_5_50');
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle();

      // 3. Verify subtotal is exactly Rs. 17.69
      expect(find.textContaining('Cart Total: Rs. 17.69'), findsOneWidget);

      // 4. Tap checkout
      await tester.tap(find.byKey(AppKeys.checkoutButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('Checkout complete'), findsOneWidget);

      // 5. Increment item (resets checkout complete status)
      await tester.tap(find.byKey(const ValueKey('increment_qty_seeded_5_50')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Checkout complete'), findsNothing);

      // 6. Verify quantity bounds (max 999 limit and error message on overflow)
      // We currently have 1 of 'bulk_biscuit_007'. We click increment 1000 times.
      final incBtn = find.byKey(const ValueKey('increment_qty_bulk_biscuit_007'));
      for (int i = 0; i < 1000; i++) {
        await tester.tap(incBtn);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Verify error message on overflow is displayed
      expect(find.textContaining('Error: Max quantity reached'), findsOneWidget);
      // Verify quantity capped at 999
      expect(find.textContaining('Rs. 12.19 x 999'), findsOneWidget);
      // Verify cart total matches the calculation: (12.19 * 999) + (5.50 * 2) = 12177.81 + 11.00 = 12188.81
      expect(find.textContaining('Cart Total: Rs. 12188.81'), findsOneWidget);

      // 7. Verify invalid phone format errors
      // First, verify empty phone number error
      await tester.enterText(find.byKey(AppKeys.customerPhoneInput), '');
      await tester.tap(find.byKey(AppKeys.shareReceiptButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter phone number first'), findsOneWidget);

      // Verify invalid format error (needs to match ^9[78]\d{8}$)
      await tester.enterText(find.byKey(AppKeys.customerPhoneInput), '12345');
      await tester.tap(find.byKey(AppKeys.shareReceiptButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('Error: Invalid phone number format'), findsOneWidget);
    });
  });
}

