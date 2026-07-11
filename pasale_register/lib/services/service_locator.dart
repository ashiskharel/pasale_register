import 'package:get_it/get_it.dart';
import 'package:mlkit_camera/mlkit_camera.dart';

import 'camera_service.dart';
import 'cart_service.dart';
import 'fakes/fake_camera_service.dart';
import 'fakes/fake_firestore_service.dart';
import 'fakes/fake_scanner_service.dart';
import 'fakes/fake_sharing_service.dart';
import 'firestore_service.dart';
import 'mlkit_scanner_service.dart';
import 'real_camera_service.dart';
import 'real_firestore_service.dart';
import 'real_sharing_service.dart';
import 'scanner_service.dart';
import 'sharing_service.dart';

final GetIt locator = GetIt.instance;

void setupLocator({bool useFakes = false}) {
  if (locator.isRegistered<FirestoreService>()) {
    locator.unregister<FirestoreService>();
  }
  if (locator.isRegistered<ScannerService>()) {
    locator.unregister<ScannerService>();
  }
  if (locator.isRegistered<CameraService>()) {
    locator.unregister<CameraService>();
  }
  if (locator.isRegistered<SharingService>()) {
    locator.unregister<SharingService>();
  }
  if (locator.isRegistered<CartService>()) {
    locator.unregister<CartService>();
  }
  if (locator.isRegistered<MlkitCameraController>()) {
    locator.unregister<MlkitCameraController>();
  }

  if (useFakes) {
    locator.registerLazySingleton<FirestoreService>(() => FakeFirestoreService());
    locator.registerLazySingleton<ScannerService>(() => FakeScannerService());
    locator.registerLazySingleton<CameraService>(() => FakeCameraService());
    locator.registerLazySingleton<SharingService>(() => FakeSharingService());
  } else {
    locator.registerLazySingleton<FirestoreService>(() => RealFirestoreService());
    locator.registerLazySingleton<MlkitCameraController>(
      () => MlkitCameraController(
        policy: CameraScopePolicy.freeDefault(updatedBy: 'system'),
      ),
    );
    locator.registerLazySingleton<ScannerService>(
      () => MlkitScannerService(
        controller: locator<MlkitCameraController>(),
      ),
    );
    locator.registerLazySingleton<CameraService>(
      () => RealCameraService(
        controller: locator<MlkitCameraController>(),
      ),
    );
    locator.registerLazySingleton<SharingService>(() => RealSharingService());
  }

  locator.registerLazySingleton<CartService>(() => CartService());
}

/// Load store camera scope from Firestore and apply to the live scanner.
Future<void> loadAndApplyCameraScope(String storeId) async {
  final policy = await locator<FirestoreService>().getCameraScope(storeId);
  await locator<ScannerService>().applyCameraPolicy(policy);
}
