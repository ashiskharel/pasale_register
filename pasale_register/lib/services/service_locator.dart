import 'package:get_it/get_it.dart';
import 'package:mlkit_camera/mlkit_camera.dart';

import 'app_help_agent_service.dart';
import 'auth_service.dart';
import 'camera_service.dart';
import 'cart_service.dart';
import 'fakes/fake_camera_service.dart';
import 'fakes/fake_firestore_service.dart';
import 'fakes/fake_scanner_service.dart';
import 'fakes/fake_sharing_service.dart';
import 'firestore_service.dart';
import 'invoice_history_service.dart';
import 'deposit_history_service.dart';
import 'mlkit_scanner_service.dart';
import 'real_camera_service.dart';
import 'real_firestore_service.dart';
import 'real_sharing_service.dart';
import 'scanner_service.dart';
import 'sharing_service.dart';
import 'voice_input_service.dart';
import 'voice_output_service.dart';
import 'update_service.dart';

final GetIt locator = GetIt.instance;

/// Last backend chosen by [setupLocator] (for help-agent context).
ServiceBackend activeBackend = ServiceBackend.fakes;

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
  activeBackend = resolved;

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
  if (locator.isRegistered<InvoiceHistoryService>()) {
    locator.unregister<InvoiceHistoryService>();
  }
  if (locator.isRegistered<DepositHistoryService>()) {
    locator.unregister<DepositHistoryService>();
  }
  if (locator.isRegistered<AuthService>()) {
    locator.unregister<AuthService>();
  }
  if (locator.isRegistered<MlkitCameraController>()) {
    locator.unregister<MlkitCameraController>();
  }
  if (locator.isRegistered<AppHelpAgentService>()) {
    locator.unregister<AppHelpAgentService>();
  }
  if (locator.isRegistered<VoiceInputService>()) {
    locator.unregister<VoiceInputService>();
  }
  if (locator.isRegistered<VoiceOutputService>()) {
    locator.unregister<VoiceOutputService>();
  }

  if (!locator.isRegistered<UpdateService>()) {
    locator.registerLazySingleton(() => UpdateService());
  }

  switch (resolved) {
    case ServiceBackend.fakes:
      locator.registerLazySingleton<FirestoreService>(() => FakeFirestoreService());
      locator.registerLazySingleton<ScannerService>(() => FakeScannerService());
      locator.registerLazySingleton<CameraService>(() => FakeCameraService());
      locator.registerLazySingleton<SharingService>(() => FakeSharingService());
      locator.registerLazySingleton<AuthService>(
        () => AuthService(forceDemo: true),
      );
      locator.registerLazySingleton<AppHelpAgentService>(
        () => LocalAppHelpAgentService(),
      );
      locator.registerLazySingleton<VoiceInputService>(
        () => FakeVoiceInputService(),
      );
      locator.registerLazySingleton<VoiceOutputService>(
        () => FakeVoiceOutputService(),
      );
      break;

    case ServiceBackend.realCamera:
      locator.registerLazySingleton<FirestoreService>(() => FakeFirestoreService());
      _registerRealCameraStack();
      locator.registerLazySingleton<SharingService>(() => FakeSharingService());
      // No Firebase Auth — demo OTP / demo Facebook
      locator.registerLazySingleton<AuthService>(
        () => AuthService(forceDemo: true),
      );
      locator.registerLazySingleton<AppHelpAgentService>(
        () => SpaceXaiAppHelpAgentService(),
      );
      locator.registerLazySingleton<VoiceInputService>(() => VoiceInputService());
      locator.registerLazySingleton<VoiceOutputService>(
        () => VoiceOutputService(),
      );
      break;

    case ServiceBackend.production:
      locator.registerLazySingleton<FirestoreService>(() => RealFirestoreService());
      _registerRealCameraStack();
      locator.registerLazySingleton<SharingService>(() => RealSharingService());
      locator.registerLazySingleton<AuthService>(
        () => AuthService(forceDemo: false),
      );
      locator.registerLazySingleton<AppHelpAgentService>(
        () => SpaceXaiAppHelpAgentService(),
      );
      locator.registerLazySingleton<VoiceInputService>(() => VoiceInputService());
      locator.registerLazySingleton<VoiceOutputService>(
        () => VoiceOutputService(),
      );
      break;
  }

  locator.registerLazySingleton<CartService>(() => CartService());
  locator.registerLazySingleton<InvoiceHistoryService>(
    () => InvoiceHistoryService(),
  );
  locator.registerLazySingleton<DepositHistoryService>(
    () => DepositHistoryService(),
  );
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

/// POS always needs barcode + price-tag OCR. Older stores may still have
/// barcode-only scope from before OCR was free — upgrade in place.
CameraScopePolicy ensurePosCameraCapabilities(CameraScopePolicy policy) {
  var next = policy;
  if (!next.allows(CameraCapability.barcodeQr)) {
    next = next.withCapability(
      CameraCapability.barcodeQr,
      enabled: true,
      updatedBy: 'system-pos',
    );
  }
  if (!next.allows(CameraCapability.textOcr)) {
    next = next.withCapability(
      CameraCapability.textOcr,
      enabled: true,
      updatedBy: 'system-pos',
    );
  }
  return next;
}

/// Load store camera scope from Firestore and apply to the live scanner.
Future<void> loadAndApplyCameraScope(String storeId) async {
  final fs = locator<FirestoreService>();
  var policy = await fs.getCameraScope(storeId);
  final upgraded = ensurePosCameraCapabilities(policy);
  if (upgraded.enabled.length != policy.enabled.length ||
      !upgraded.enabled.containsAll(policy.enabled) ||
      !policy.enabled.containsAll(upgraded.enabled)) {
    // Persist so the next launch does not re-hit "mode text not enabled".
    try {
      await fs.saveCameraScope(storeId, upgraded);
    } catch (e) {
      // Still apply locally even if write fails (offline / rules).
      // ignore: avoid_print
      print('loadAndApplyCameraScope: could not save upgraded scope: $e');
    }
    policy = upgraded;
  }
  await locator<ScannerService>().applyCameraPolicy(policy);
}


