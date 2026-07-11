import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'firebase_options.dart';
import 'services/service_locator.dart';

/// Compile-time overrides:
/// - `--dart-define=USE_FAKES=true` → all fakes (tests)
/// - `--dart-define=REAL_CAMERA_ONLY=true` → real ML Kit, fake Firestore
/// - default → try Firebase production; if not configured, real camera only
const bool kForceFakes = bool.fromEnvironment('USE_FAKES', defaultValue: false);
const bool kRealCameraOnly =
    bool.fromEnvironment('REAL_CAMERA_ONLY', defaultValue: false);

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

  if (!DefaultFirebaseOptions.isConfigured) {
    debugPrint(
      'Firebase options not configured. '
      'Run: dart run flutterfire_cli:flutterfire configure\n'
      'Falling back to real camera + fake Firestore.',
    );
    setupLocator(backend: ServiceBackend.realCamera);
    return const BootstrapResult(
      backend: ServiceBackend.realCamera,
      firebaseReady: false,
      message:
          'Firebase not configured — real camera + local fake catalog. '
          'See FIREBASE_SETUP.md',
    );
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    setupLocator(backend: ServiceBackend.production);
    return const BootstrapResult(
      backend: ServiceBackend.production,
      firebaseReady: true,
      message: 'Firebase + real ML Kit camera ready',
    );
  } catch (e, st) {
    debugPrint('Firebase.initializeApp failed: $e\n$st');
    setupLocator(backend: ServiceBackend.realCamera);
    return BootstrapResult(
      backend: ServiceBackend.realCamera,
      firebaseReady: false,
      message: 'Firebase init failed ($e) — real camera + fake Firestore',
    );
  }
}
