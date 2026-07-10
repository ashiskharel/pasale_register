import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants/keys.dart';
import '../services/service_locator.dart';
import '../services/firestore_service.dart';

class ActivationScreen extends StatefulWidget {
  final VoidCallback? onActivated;
  const ActivationScreen({super.key, this.onActivated});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _storeIdController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _deviceMetadataController = TextEditingController();

  String _status = '';

  @override
  void initState() {
    super.initState();
    _initDeviceId();
  }

  Future<void> _initDeviceId() async {
    final deviceId = await _getOrGenerateDeviceId();
    final metadata = await _getDeviceMetadata();
    if (mounted) {
      setState(() {
        _deviceIdController.text = deviceId;
        _deviceMetadataController.text = jsonEncode(metadata);
      });
    }
  }

  Future<String> _getOrGenerateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('deviceId');
    if (deviceId != null && deviceId.isNotEmpty) {
      return deviceId;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceId = webInfo.userAgent;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        deviceId = windowsInfo.deviceId;
      } else if (Platform.isMacOS) {
        final macosInfo = await deviceInfo.macOsInfo;
        deviceId = macosInfo.systemGUID;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        deviceId = linuxInfo.machineId;
      }
    } catch (_) {
      // ignore and fallback
    }

    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
    }
    await prefs.setString('deviceId', deviceId);
    return deviceId;
  }

  Future<Map<String, dynamic>> _getDeviceMetadata() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return {
          'model': webInfo.browserName.toString(),
          'osVersion': webInfo.appVersion ?? 'unknown',
        };
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'model': androidInfo.model,
          'osVersion': androidInfo.version.release,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'model': iosInfo.model,
          'osVersion': iosInfo.systemVersion,
        };
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return {
          'model': 'Windows PC',
          'osVersion': windowsInfo.releaseId,
        };
      } else if (Platform.isMacOS) {
        final macosInfo = await deviceInfo.macOsInfo;
        return {
          'model': macosInfo.model,
          'osVersion': macosInfo.osRelease,
        };
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return {
          'model': linuxInfo.name,
          'osVersion': linuxInfo.versionId ?? 'unknown',
        };
      }
    } catch (_) {
      // ignore and return fallback
    }
    return {
      'model': 'unknown',
      'osVersion': 'unknown',
    };
  }

  Future<void> _activate() async {
    final storeId = _storeIdController.text.trim();
    final storeName = _storeNameController.text.trim();
    if (storeId.isEmpty || storeName.isEmpty) {
      setState(() {
        _status = 'Error: Store ID and Name required';
      });
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(storeId)) {
      setState(() {
        _status = 'Error: Store ID must be alphanumeric';
      });
      return;
    }
    try {
      await locator<FirestoreService>().activateStore(storeId, storeName);
      
      final deviceId = _deviceIdController.text.trim();
      final metadataStr = _deviceMetadataController.text.trim();
      Map<String, dynamic> metadata = {};
      if (metadataStr.isNotEmpty) {
        try {
          metadata = jsonDecode(metadataStr) as Map<String, dynamic>;
        } catch (e) {
          metadata = {'raw': metadataStr};
        }
      }
      await locator<FirestoreService>().registerDevice(storeId, deviceId, metadata);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('storeId', storeId);
      await prefs.setString('storeName', storeName);
      await prefs.setString('deviceId', deviceId);
      await prefs.setBool('isActivated', true);

      setState(() {
        _status = 'Store Activated Successfully: $storeName';
      });

      widget.onActivated?.call();
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _register() async {
    final storeId = _storeIdController.text.trim();
    final deviceId = _deviceIdController.text.trim();
    final metadataStr = _deviceMetadataController.text.trim();
    if (storeId.isEmpty || deviceId.isEmpty) {
      setState(() {
        _status = 'Error: Store ID and Device ID required';
      });
      return;
    }
    Map<String, dynamic> metadata = {};
    if (metadataStr.isNotEmpty) {
      try {
        metadata = jsonDecode(metadataStr) as Map<String, dynamic>;
      } catch (e) {
        metadata = {'raw': metadataStr};
      }
    }
    try {
      await locator<FirestoreService>().registerDevice(storeId, deviceId, metadata);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('storeId', storeId);
      await prefs.setString('deviceId', deviceId);
      await prefs.setBool('isActivated', true);

      setState(() {
        _status = 'Device Registered Successfully: $deviceId';
      });

      widget.onActivated?.call();
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _storeIdController.dispose();
    _storeNameController.dispose();
    _deviceIdController.dispose();
    _deviceMetadataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Activation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              key: AppKeys.storeIdInput,
              controller: _storeIdController,
              decoration: const InputDecoration(labelText: 'Store ID'),
            ),
            TextField(
              key: AppKeys.storeNameInput,
              controller: _storeNameController,
              decoration: const InputDecoration(labelText: 'Store Name'),
            ),
            ElevatedButton(
              key: AppKeys.activateStoreButton,
              onPressed: _activate,
              child: const Text('Activate Store'),
            ),
            const SizedBox(height: 20),
            TextField(
              key: AppKeys.deviceIdInput,
              controller: _deviceIdController,
              decoration: const InputDecoration(labelText: 'Device ID'),
            ),
            TextField(
              key: AppKeys.deviceMetadataInput,
              controller: _deviceMetadataController,
              decoration: const InputDecoration(labelText: 'Device Metadata (JSON or text)'),
            ),
            ElevatedButton(
              key: AppKeys.registerDeviceButton,
              onPressed: _register,
              child: const Text('Register Device'),
            ),
            const SizedBox(height: 20),
            Text(
              _status,
              key: AppKeys.statusText,
            ),
          ],
        ),
      ),
    );
  }
}
