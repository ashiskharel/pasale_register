// File generated-style stub for Firebase options.
// Replace by running FlutterFire configure (see FIREBASE_SETUP.md):
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=YOUR_PROJECT_ID
//
// Until then, [isConfigured] is false and the app runs real camera + fake Firestore.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  /// True when [android]/[ios]/etc. hold real project values (not placeholders).
  /// After `flutterfire configure`, keys no longer look like YOUR_* / placeholder.
  static bool get isConfigured {
    final id = android.projectId;
    final key = android.apiKey;
    if (id.isEmpty || key.isEmpty) return false;
    if (id.contains('placeholder') || id.contains('YOUR_')) return false;
    if (key.contains('Placeholder') || key.contains('YOUR_')) return false;
    return true;
  }

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw UnsupportedError(
        'DefaultFirebaseOptions is not configured. '
        'Run `flutterfire configure` or follow FIREBASE_SETUP.md.',
      );
    }
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // --- Placeholders: flutterfire configure overwrites these ---

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: 'YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCcWXicFcXvrBCY1JJGv7alm7DYcj5pzd8',
    appId: '1:455280907863:android:f45d64404a563fe7dc3512',
    messagingSenderId: '455280907863',
    projectId: 'pasal-b84c5',
    storageBucket: 'pasal-b84c5.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.example.pasaleRegister',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.example.pasaleRegister',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR_WINDOWS_API_KEY',
    appId: 'YOUR_WINDOWS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );
}
