import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  Future<void> initializeAndCheckForUpdates() async {
    if (kIsWeb) return;

    // 1. Initialize Firebase Remote Config
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1), 
      ));
      
      // Default fallback values before fetching
      await remoteConfig.setDefaults(const {
        "maintenance_mode": false,
      });
      
      await remoteConfig.fetchAndActivate();
      
      if (remoteConfig.getBool("maintenance_mode")) {
        debugPrint("Maintenance mode is ON according to Remote Config!");
      }
    } catch (e) {
      debugPrint("Remote Config init failed: $e");
    }

    // 2. Google Play In-App Updates
    // Only runs on Android when installed via Play Store
    if (Platform.isAndroid) {
      try {
        final updateInfo = await InAppUpdate.checkForUpdate();
        
        // If an update is available on the Play Store, trigger the Google Play overlay.
        if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
          // Perform an immediate full-screen update (forces update). 
          await InAppUpdate.performImmediateUpdate();
        }
      } catch (e) {
        debugPrint("In-App Update check failed: $e");
      }
    }
  }
}
