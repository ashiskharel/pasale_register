import 'package:flutter_test/flutter_test.dart';
import 'package:pasale_register/models/product.dart';
import 'package:pasale_register/services/firestore_service.dart';
import 'package:pasale_register/services/scanner_service.dart';
import 'package:pasale_register/services/camera_service.dart';
import 'package:pasale_register/services/sharing_service.dart';
import 'package:pasale_register/services/service_locator.dart';
import 'package:pasale_register/services/fakes/fake_firestore_service.dart';
import 'package:pasale_register/services/fakes/fake_scanner_service.dart';
import 'package:pasale_register/services/fakes/fake_camera_service.dart';
import 'package:pasale_register/services/fakes/fake_sharing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    setupLocator(useFakes: true);
  });

  test('Locator registers fake services', () {
    expect(locator<FirestoreService>(), isA<FakeFirestoreService>());
    expect(locator<ScannerService>(), isA<FakeScannerService>());
    expect(locator<CameraService>(), isA<FakeCameraService>());
    expect(locator<SharingService>(), isA<FakeSharingService>());
  });

  test('FakeFirestoreService maintains state', () async {
    final firestore = locator<FirestoreService>() as FakeFirestoreService;

    // Store Activation
    await firestore.activateStore('store123', 'My Store', ownerUid: 'user123');
    expect(firestore.stores['store123'], 'My Store');

    // Device registration
    await firestore.registerDevice('store123', 'device789', const {'os': 'android'});
    expect(firestore.devices['store123']?['device789']?['os'], 'android');

    // Product CRUD & stream
    final product = Product(
      id: 'prod001',
      name: 'Product 1',
      barcode: '123456789',
      sellingPrice: 15.0,
      costPrice: 10.0,
      markup: 50.0,
    );

    final catalogStream = firestore.streamCatalog();
    final firstEmission = await catalogStream.first;
    expect(firstEmission.length, 10);
    firestore.products.clear();

    await firestore.saveProduct(product);
    final fetched = await firestore.getProduct('prod001');
    expect(fetched?.name, 'Product 1');

    final updatedEmission = await firestore.streamCatalog().first;
    expect(updatedEmission.length, 1);
    expect(updatedEmission[0].id, 'prod001');
  });

  test('FakeScannerService simulates scans and tracks feedback', () async {
    final scanner = locator<ScannerService>() as FakeScannerService;

    // Simulate scan
    final scanFuture = scanner.scan();
    scanner.simulateScan('987654321');
    final scannedBarcode = await scanFuture;
    expect(scannedBarcode, '987654321');

    // Track feedback
    expect(scanner.feedbackCount, 0);
    await scanner.triggerFeedback();
    expect(scanner.feedbackCount, 1);
  });

  test('FakeCameraService returns mock path and tracks capture count', () async {
    final camera = locator<CameraService>() as FakeCameraService;

    expect(camera.captureCount, 0);
    final path = await camera.captureInvoicePhoto();
    expect(path, '/mock/path/to/invoice.jpg');
    expect(camera.captureCount, 1);

    camera.setMockPath('/custom/path.png');
    final customPath = await camera.captureInvoicePhoto();
    expect(customPath, '/custom/path.png');
    expect(camera.captureCount, 2);
  });

  test('FakeSharingService tracks receipt sharing details', () async {
    final sharing = locator<SharingService>() as FakeSharingService;

    expect(sharing.shareCount, 0);
    await sharing.shareReceipt('Receipt data', '9800000000');
    expect(sharing.shareCount, 1);
    expect(sharing.lastSharedReceiptText, 'Receipt data');
    expect(sharing.lastSharedPhoneNumber, '9800000000');
  });
}
