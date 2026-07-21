import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;
import 'services/service_locator.dart';

/// Compile-time overrides:
/// - `--dart-define=USE_FAKES=true` → all fakes (tests)
/// - `--dart-define=REAL_CAMERA_ONLY=true` → real ML Kit, fake Firestore
/// - `--dart-define=ENV=Prod` (or `prod`) → Firebase **prod** project options
/// - default `ENV=dev` → Firebase **dev** project options
///
/// We have separate Firebase / Firestore projects for dev vs prod — always
/// pass `ENV=Prod` for real store data / production demos.
const bool kForceFakes = bool.fromEnvironment('USE_FAKES', defaultValue: false);
const bool kRealCameraOnly =
    bool.fromEnvironment('REAL_CAMERA_ONLY', defaultValue: false);
const String kEnvironment = String.fromEnvironment('ENV', defaultValue: 'dev');

/// True when [kEnvironment] is prod (case-insensitive: `prod`, `Prod`, `PROD`).
bool get kIsProdEnvironment =>
    kEnvironment.toLowerCase() == 'prod';

class BootstrapResult {
  const BootstrapResult({
    required this.backend,
    required this.firebaseReady,
    this.message,
  });

  final ServiceBackend backend;
  final bool firebaseReady;
  final String? message;
}

/// Initialize Flutter bindings, optional Firebase, and the service locator.
Future<BootstrapResult> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  /*
  if (kForceFakes) {
    setupLocator(backend: ServiceBackend.fakes);
    return const BootstrapResult(
      backend: ServiceBackend.fakes,
      firebaseReady: false,
      message: 'USE_FAKES=true — all services faked',
    );
  }

  if (kRealCameraOnly) {
    setupLocator(backend: ServiceBackend.realCamera);
    return const BootstrapResult(
      backend: ServiceBackend.realCamera,
      firebaseReady: false,
      message: 'REAL_CAMERA_ONLY — ML Kit on, Firestore faked',
    );
  }
  */

  final firebaseOptions = kIsProdEnvironment
      ? prod.DefaultFirebaseOptions.currentPlatform
      : dev.DefaultFirebaseOptions.currentPlatform;

  try {
    await Firebase.initializeApp(
      options: firebaseOptions,
    );
    setupLocator(backend: ServiceBackend.production);
    return BootstrapResult(
      backend: ServiceBackend.production,
      firebaseReady: true,
      message: 'Firebase [$kEnvironment] + real ML Kit camera ready',
    );
  } catch (e, st) {
    if (e is FirebaseException && e.code == 'duplicate-app') {
      setupLocator(backend: ServiceBackend.production);
      return BootstrapResult(
        backend: ServiceBackend.production,
        firebaseReady: true,
        message: 'Firebase [$kEnvironment] already initialized',
      );
    }
    
    debugPrint('Firebase.initializeApp failed: $e\n$st');
    // Force production anyway since user requested it
    setupLocator(backend: ServiceBackend.production);
    return BootstrapResult(
      backend: ServiceBackend.production,
      firebaseReady: false,
      message: 'Firebase init failed ($e) — forcing production backend anyway',
    );
  }
}
