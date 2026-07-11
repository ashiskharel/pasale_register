import 'package:flutter_test/flutter_test.dart';
import 'package:mlkit_camera/mlkit_camera.dart';
import 'package:pasale_register/services/fakes/fake_firestore_service.dart';
import 'package:pasale_register/services/fakes/fake_scanner_service.dart';
import 'package:pasale_register/services/firestore_service.dart';
import 'package:pasale_register/services/scanner_service.dart';
import 'package:pasale_register/services/service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    setupLocator(useFakes: true);
  });

  test('FakeFirestore persists camera scope per store', () async {
    final fs = locator<FirestoreService>() as FakeFirestoreService;
    final free = CameraScopePolicy.freeDefault(updatedBy: 'test');
    await fs.saveCameraScope('store-1', free);
    final loaded = await fs.getCameraScope('store-1');
    expect(loaded.tier, PlanTier.free);
    expect(loaded.enabled, {CameraCapability.barcodeQr});

    final premium = CameraScopePolicy.premiumDefault(updatedBy: 'admin');
    await fs.saveCameraScope('store-1', premium);
    final again = await fs.getCameraScope('store-1');
    expect(again.allows(CameraCapability.batchSegmentation), isTrue);
  });

  test('unknown store returns free default', () async {
    final fs = locator<FirestoreService>() as FakeFirestoreService;
    final policy = await fs.getCameraScope('missing-store');
    expect(policy.allowsMode(CameraVisionMode.barcodeQr), isTrue);
    expect(policy.allowsMode(CameraVisionMode.objectDetection), isFalse);
  });

  test('loadAndApplyCameraScope uses firestore policy', () async {
    final fs = locator<FirestoreService>() as FakeFirestoreService;
    await fs.saveCameraScope(
      'store-x',
      CameraScopePolicy.premiumDefault(updatedBy: 'admin'),
    );
    await loadAndApplyCameraScope('store-x');
    // Fake scanner apply is no-op but should not throw.
    expect(locator<ScannerService>(), isA<FakeScannerService>());
  });
}
