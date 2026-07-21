import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'session_service.dart';

/// Captures device id, metadata, and optional location **silently**
/// (not shown on OTP UI). Persists for activation / analytics.
///
/// Uses lightweight platform checks only — avoids hanging platform-channel
/// calls (device_info_plus) during tests / desktop without bindings.
class DeviceContextService {
  /// Demo OTP accepted when Firebase Auth is not wired.
  static const demoOtp = '123456';

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(SessionKeys.deviceId);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final deviceId = const Uuid().v4();
    await prefs.setString(SessionKeys.deviceId, deviceId);
    return deviceId;
  }

  Future<Map<String, dynamic>> collectDeviceMetadata() async {
    final meta = <String, dynamic>{
      'model': _modelHint(),
      'osVersion': _osHint(),
      'platform': _platformName(),
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
      if (kDebugMode) 'debug': true,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SessionKeys.deviceMetadata, jsonEncode(meta));
    return meta;
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isWindows) return 'windows';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'other';
  }

  String _modelHint() {
    if (kIsWeb) return 'web';
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'unknown';
    }
  }

  String _osHint() {
    if (kIsWeb) return 'web';
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return 'unknown';
    }
  }

  /// Best-effort location. Never blocks login; returns null if unavailable.
  Future<Map<String, dynamic>?> captureLocationSilently() async {
    try {
      final location = <String, dynamic>{
        'latitude': null,
        'longitude': null,
        'accuracy': null,
        'source': 'deferred',
        'note': 'Location filled when OS permission is granted (geolocator)',
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SessionKeys.lastLocation, jsonEncode(location));
      return location;
    } catch (_) {
      return null;
    }
  }

  /// Full silent capture used during OTP verification.
  Future<DeviceCaptureResult> captureAllSilently() async {
    final deviceId = await getOrCreateDeviceId();
    final metadata = await collectDeviceMetadata();
    final location = await captureLocationSilently();
    return DeviceCaptureResult(
      deviceId: deviceId,
      metadata: metadata,
      location: location,
    );
  }
}

class DeviceCaptureResult {
  const DeviceCaptureResult({
    required this.deviceId,
    required this.metadata,
    this.location,
  });

  final String deviceId;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic>? location;
}
