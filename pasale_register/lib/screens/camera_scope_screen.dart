import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mlkit_camera/mlkit_camera.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/keys.dart';
import '../services/firestore_service.dart';
import '../services/scanner_service.dart';
import '../services/service_locator.dart';

/// Superadmin UI: change camera freemium scope for the activated store.
///
/// Persists to Firestore (`stores/{storeId}/settings/cameraScope`) and applies
/// live to [ScannerService].
class CameraScopeScreen extends StatefulWidget {
  const CameraScopeScreen({super.key});

  @override
  State<CameraScopeScreen> createState() => _CameraScopeScreenState();
}

class _CameraScopeScreenState extends State<CameraScopeScreen> {
  CameraScopePolicy? _draft;
  String? _storeId;
  String _status = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _status = '';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final storeId = prefs.getString('storeId');
      if (storeId == null || storeId.isEmpty) {
        setState(() {
          _loading = false;
          _status = 'Activate a store first to edit camera scope.';
        });
        return;
      }
      final policy =
          await locator<FirestoreService>().getCameraScope(storeId);
      setState(() {
        _storeId = storeId;
        _draft = policy;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Load error: $e';
      });
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    final storeId = _storeId;
    if (draft == null || storeId == null) return;
    setState(() {
      _saving = true;
      _status = 'Saving...';
    });
    try {
      final toSave = draft.copyWith(
        updatedBy: draft.updatedBy ?? 'superadmin',
        updatedAt: DateTime.now().toUtc(),
      );
      await locator<FirestoreService>().saveCameraScope(storeId, toSave);
      await locator<ScannerService>().applyCameraPolicy(toSave);
      setState(() {
        _draft = toSave;
        _saving = false;
        _status = 'Camera scope saved for store $storeId';
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _status = 'Save error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final draft = _draft;
    if (draft == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_status, key: AppKeys.statusText),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Superadmin · Camera scope',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Store: ${_storeId ?? "—"}\n'
          'Free users get barcode & QR. Object detection and batch checkout '
          'are premium (enable after training / self-labeling).',
        ),
        const SizedBox(height: 16),
        Text('Plan tier', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<PlanTier>(
          key: AppKeys.cameraScopeTier,
          segments: const [
            ButtonSegment(value: PlanTier.free, label: Text('Free')),
            ButtonSegment(value: PlanTier.premium, label: Text('Premium')),
          ],
          selected: {draft.tier},
          onSelectionChanged: (s) {
            setState(() {
              _draft = draft.withTier(
                s.first,
                resetToPreset: true,
                updatedBy: 'superadmin',
              );
            });
          },
        ),
        const SizedBox(height: 24),
        Text('Capabilities', style: Theme.of(context).textTheme.titleMedium),
        ...CameraCapability.values.map((cap) {
          return SwitchListTile(
            key: ValueKey('camera_cap_${cap.name}'),
            title: Text(cap.displayName),
            subtitle: Text(
              cap.description +
                  (cap.isPremiumDefault ? ' · premium default' : ''),
            ),
            value: draft.allows(cap),
            onChanged: (v) {
              setState(() {
                _draft = draft.withCapability(
                  cap,
                  enabled: v,
                  updatedBy: 'superadmin',
                );
              });
            },
          );
        }),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: AppKeys.saveCameraScopeButton,
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save),
          label: Text(_saving ? 'Saving…' : 'Save to Firestore'),
        ),
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_status, key: AppKeys.statusText),
        ],
        const SizedBox(height: 16),
        Text('Policy JSON', style: Theme.of(context).textTheme.titleSmall),
        SelectableText(
          const JsonEncoder.withIndent('  ').convert(draft.toJson()),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ],
    );
  }
}
