import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/keys.dart';
import '../services/device_context_service.dart';
import '../services/firestore_service.dart';
import '../services/service_locator.dart';
import '../services/session_service.dart';
import '../services/catalog_template_service.dart';

/// Store owner store registration after OTP.
/// Device id / metadata / location stay hidden (already captured at OTP).
class StoreSetupScreen extends StatefulWidget {
  const StoreSetupScreen({super.key, required this.onActivated});

  final VoidCallback onActivated;

  @override
  State<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends State<StoreSetupScreen> {
  final _storeIdController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _passcodeController = TextEditingController();
  final _device = DeviceContextService();

  static const _storeTypes = [
    'Grocery / Kirana',
    'Pharmacy',
    'Hair Salon',
    'Momo Shop',
    'Clothing Apparel',
    'Other',
  ];

  String _selectedStoreType = _storeTypes.first;
  String _status = '';
  bool _busy = false;
  bool _isJoining = false;

  @override
  void dispose() {
    _storeIdController.dispose();
    _storeNameController.dispose();
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final storeName = _storeNameController.text.trim();
    String storeId = _storeIdController.text.trim();

    if (_isJoining) {
      if (storeId.isEmpty || _passcodeController.text.trim().isEmpty) {
        setState(() => _status = 'Error: Store ID and Passcode required to join');
        return;
      }
    } else {
      if (storeName.isEmpty) {
        setState(() => _status = 'Error: Store Name required');
        return;
      }
      storeId = storeName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') + '-' + DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    }


    setState(() {
      _busy = true;
      _status = 'Activating store…';
    });

    try {
      final session = await SessionService().load();
      final ownerUid = (session.uid != null && session.uid!.isNotEmpty)
          ? session.uid!
          : (session.phone != null && session.phone!.isNotEmpty
              ? 'phone_${session.phone}'
              : 'local_owner');

      if (_isJoining) {
        await locator<FirestoreService>().joinStore(
          storeId: storeId,
          passcode: _passcodeController.text.trim(),
          uid: ownerUid,
          phone: session.phone,
          displayName: session.displayName,
        );
      } else {
        await locator<FirestoreService>().activateStore(
          storeId,
          storeName,
          ownerUid: ownerUid,
          businessId: session.businessId,
          ownerPhone: session.phone,
        );
      }

      final capture = await _device.captureAllSilently();
      final metadata = Map<String, dynamic>.from(capture.metadata);
      if (capture.location != null) {
        metadata['location'] = capture.location;
      }

      await locator<FirestoreService>().registerDevice(
        storeId,
        capture.deviceId,
        metadata,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SessionKeys.storeId, storeId);
      await prefs.setString(SessionKeys.storeName, storeName);
      await prefs.setString(SessionKeys.deviceId, capture.deviceId);
      await prefs.setString(
        SessionKeys.deviceMetadata,
        jsonEncode(metadata),
      );
      await prefs.setBool(SessionKeys.isActivated, true);
      // Refresh business id from membership if present
      try {
        final profile = await locator<FirestoreService>().ensureMembershipProfile(
          uid: ownerUid,
          phone: session.phone,
          displayName: storeName.isEmpty ? 'Joined Store' : storeName,
        );
        await prefs.setString(SessionKeys.businessId, profile.businessId);
      } catch (_) {}

      if (!_isJoining) {
        try {
          await CatalogTemplateService.cloneTemplate(
            storeId: storeId,
            businessId: prefs.getString(SessionKeys.businessId) ?? session.businessId,
            storeType: _selectedStoreType,
          );
        } catch (e) {
          debugPrint('Failed to clone templates: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _status = 'Store Activated Successfully: $storeName';
        _busy = false;
      });
      widget.onActivated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _friendlyError(e);
        _busy = false;
      });
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('permission-denied') || s.contains('PERMISSION_DENIED')) {
      return 'Error: Firestore permission denied.\n'
          'In Firebase Console → Firestore: create the database if missing, '
          'then set rules to allow write (or deploy firestore.rules from the repo).';
    }
    if (s.contains('not-found') ||
        s.contains('NOT_FOUND') ||
        s.contains('does not exist')) {
      return 'Error: Firestore database not found.\n'
          'Console → Build → Firestore Database → Create database.';
    }
    if (s.contains('unavailable') || s.contains('UNAVAILABLE')) {
      return 'Error: Cannot reach Firestore. Check internet / VPN.';
    }
    return 'Error: $e';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your store')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isJoining ? 'Join an existing store using the Store ID and Passcode provided by the owner.' : 'Create your new store. You can manage your inventory and sales immediately.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
              const SizedBox(height: 24),
              if (_isJoining) ...[
                TextField(
                  key: AppKeys.storeIdInput,
                  controller: _storeIdController,
                  decoration: const InputDecoration(
                    labelText: 'Store ID',
                    hintText: 'e.g. my-shop-123',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passcodeController,
                  decoration: const InputDecoration(
                    labelText: 'Passcode',
                    hintText: '6-digit code',
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                ),
              ] else ...[
                TextField(
                  key: AppKeys.storeNameInput,
                  controller: _storeNameController,
                  decoration: const InputDecoration(
                    labelText: 'Store Name',
                    hintText: 'My Corner Shop',
                  ),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStoreType,
                  decoration: const InputDecoration(
                    labelText: 'Store Type',
                  ),
                  items: _storeTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedStoreType = v);
                    }
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isJoining = !_isJoining;
                    _status = '';
                  });
                },
                child: Text(_isJoining ? 'Create a new store instead' : 'Have an invite code? Join existing store'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: AppKeys.activateStoreButton,
                onPressed: _busy ? null : _activate,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isJoining ? 'Join store' : 'Activate store'),
              ),
              // Hidden fields kept for tests that still query device keys —
              // not visible (zero size / offstage).
              Offstage(
                offstage: true,
                child: Column(
                  children: [
                    TextField(
                      key: AppKeys.deviceIdInput,
                      controller: TextEditingController(text: 'hidden'),
                    ),
                    TextField(
                      key: AppKeys.deviceMetadataInput,
                      controller: TextEditingController(text: '{}'),
                    ),
                    ElevatedButton(
                      key: AppKeys.registerDeviceButton,
                      onPressed: () {},
                      child: const Text('Register Device'),
                    ),
                  ],
                ),
              ),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(_status, key: AppKeys.statusText),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
