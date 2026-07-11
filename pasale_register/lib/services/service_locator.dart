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

/// How external services are wired.
enum ServiceBackend {
  /// All fakes — unit/widget tests, no camera plugins.
  fakes,

  /// Real ML Kit camera; fake Firestore/sharing (no Firebase project needed).
  realCamera,

  /// Real ML Kit camera + real Firestore (+ sharing).
  production,
}

void setupLocator({
  ServiceBackend? backend,
  bool useFakes = false,
}) {
  final resolved = backend ??
      (useFakes ? ServiceBackend.fakes : ServiceBackend.fakes);

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

  switch (resolved) {
    case ServiceBackend.fakes:
      locator.registerLazySingleton<FirestoreService>(() => FakeFirestoreService());
      locator.registerLazySingleton<ScannerService>(() => FakeScannerService());
      locator.registerLazySingleton<CameraService>(() => FakeCameraService());
      locator.registerLazySingleton<SharingService>(() => FakeSharingService());
      break;

    case ServiceBackend.realCamera:
      locator.registerLazySingleton<FirestoreService>(() => FakeFirestoreService());
      _registerRealCameraStack();
      locator.registerLazySingleton<SharingService>(() => FakeSharingService());
      break;

    case ServiceBackend.production:
      locator.registerLazySingleton<FirestoreService>(() => RealFirestoreService());
      _registerRealCameraStack();
      locator.registerLazySingleton<SharingService>(() => RealSharingService());
      break;
  }

  locator.registerLazySingleton<CartService>(() => CartService());
}

void _registerRealCameraStack() {
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
}

/// Load store camera scope from Firestore and apply to the live scanner.
Future<void> loadAndApplyCameraScope(String storeId) async {
  final policy = await locator<FirestoreService>().getCameraScope(storeId);
  await locator<ScannerService>().applyCameraPolicy(policy);
}


