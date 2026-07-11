import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mlkit_camera/mlkit_camera.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MlkitCameraExampleApp());
}

class MlkitCameraExampleApp extends StatelessWidget {
  const MlkitCameraExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ML Kit Camera',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const CameraHomePage(),
    );
  }
}

class CameraHomePage extends StatefulWidget {
  const CameraHomePage({super.key});

  @override
  State<CameraHomePage> createState() => _CameraHomePageState();
}

class _CameraHomePageState extends State<CameraHomePage> {
  late final MlkitCameraController _controller;
  StreamSubscription<VisionResult>? _sub;
  late CameraScopePolicy _policy;
  late CameraVisionMode _mode;
  final List<VisionResult> _history = [];
  bool _torch = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Free users start with barcode + QR only.
    _policy = CameraScopePolicy.freeDefault(updatedBy: 'system');
    _mode = _policy.defaultMode;
    _controller = MlkitCameraController(policy: _policy);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _controller.initialize();
    _sub = _controller.results.listen((r) {
      if (!mounted) return;
      setState(() {
        _history.insert(0, r);
        if (_history.length > 50) {
          _history.removeLast();
        }
      });
    });
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(_controller.close());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _applyPolicy(CameraScopePolicy policy) async {
    _policy = policy;
    await _controller.updatePolicy(policy);
    _mode = _controller.mode;
    setState(() {});
  }

  Future<void> _toggleRun() async {
    if (_controller.isRunning) {
      await _controller.stop();
    } else {
      await _controller.start(mode: _mode);
    }
    setState(() {});
  }

  Future<void> _onMode(CameraVisionMode mode) async {
    if (!_policy.allowsMode(mode)) {
      final cap = CameraScopePolicy.capabilityForMode(mode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${cap.displayName} is premium / disabled. '
            'Open Superadmin to change camera scope.',
          ),
        ),
      );
      return;
    }
    setState(() => _mode = mode);
    if (_controller.isRunning) {
      await _controller.setMode(mode);
    }
    setState(() {});
  }

  String _exportJson() {
    final payload = {
      'schemaVersion': VisionResult.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'policy': _policy.toJson(),
      'mode': _mode.name,
      'results': _history.map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> _copyJson() async {
    await Clipboard.setData(ClipboardData(text: _exportJson()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON copied to clipboard')),
    );
  }

  Future<void> _shareJson() async {
    await Share.share(_exportJson(), subject: 'mlkit_camera export');
  }

  Future<void> _openSuperadmin() async {
    final next = await Navigator.of(context).push<CameraScopePolicy>(
      MaterialPageRoute(
        builder: (_) => SuperadminScopePage(policy: _policy),
      ),
    );
    if (next != null) {
      await _applyPolicy(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _policy.lockedPremiumCapabilities;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode & QR Camera'),
        actions: [
          IconButton(
            tooltip: 'Superadmin camera scope',
            onPressed: _openSuperadmin,
            icon: const Icon(Icons.admin_panel_settings),
          ),
          IconButton(
            tooltip: 'Torch',
            onPressed: !_ready
                ? null
                : () async {
                    _torch = !_torch;
                    await _controller.setTorch(_torch);
                    setState(() {});
                  },
            icon: Icon(_torch ? Icons.flash_on : Icons.flash_off),
          ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: !_ready ? null : () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch),
          ),
          IconButton(
            tooltip: 'Copy JSON',
            onPressed: _history.isEmpty ? null : _copyJson,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: 'Share JSON',
            onPressed: _history.isEmpty ? null : _shareJson,
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListTile(
              dense: true,
              leading: Icon(
                _policy.tier == PlanTier.premium
                    ? Icons.workspace_premium
                    : Icons.qr_code_2,
              ),
              title: Text(
                'Plan: ${_policy.tier.name} · Scope: '
                '${_policy.enabled.map((e) => e.displayName).join(', ')}',
              ),
              subtitle: locked.isEmpty
                  ? const Text('All premium vision capabilities unlocked')
                  : Text(
                      'Upgrade / superadmin for: '
                      '${locked.map((e) => e.displayName).join(', ')}',
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Wrap(
              spacing: 6,
              children: CameraVisionMode.values.map((m) {
                final allowed = _policy.allowsMode(m);
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_modeLabel(m)),
                      if (!allowed) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.lock, size: 14),
                      ],
                    ],
                  ),
                  selected: _mode == m && allowed,
                  onSelected: (_) => _onMode(m),
                );
              }).toList(),
            ),
          ),
          if (_controller.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _controller.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            flex: 3,
            child: ColoredBox(
              color: Colors.black,
              child: _ready
                  ? MlkitCameraView(controller: _controller)
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: !_ready ? null : _toggleRun,
                    icon: Icon(
                      _controller.isRunning ? Icons.stop : Icons.play_arrow,
                    ),
                    label: Text(
                      _controller.isRunning
                          ? 'Done Scanning / OK'
                          : 'Start barcode & QR scan',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _history.isEmpty
                      ? null
                      : () => setState(_history.clear),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _history.isEmpty
                ? const Center(
                    child: Text(
                      'Point at a product barcode or QR code.\n'
                      'Premium: object detection & batch checkout later.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, i) {
                      final r = _history[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(_modeIcon(r.mode)),
                        title: Text(_summary(r)),
                        subtitle: Text(
                          r.timestamp.toLocal().toIso8601String(),
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _modeLabel(CameraVisionMode m) => switch (m) {
        CameraVisionMode.barcodeQr => 'Barcode & QR',
        CameraVisionMode.text => 'OCR',
        CameraVisionMode.objectDetection => 'Objects',
        CameraVisionMode.batchCheckout => 'Batch',
      };

  IconData _modeIcon(CameraVisionMode m) => switch (m) {
        CameraVisionMode.barcodeQr => Icons.qr_code_scanner,
        CameraVisionMode.text => Icons.text_fields,
        CameraVisionMode.objectDetection => Icons.category,
        CameraVisionMode.batchCheckout => Icons.shopping_basket,
      };

  String _summary(VisionResult r) {
    final parts = <String>[];
    if (r.barcodes.isNotEmpty) {
      parts.add(
        'Code: ${r.barcodes.map((b) => '${b.rawValue}'
            '${b.format != null ? ' (${b.format})' : ''}').join(', ')}',
      );
    }
    if (r.textBlocks.isNotEmpty) {
      final t = r.textBlocks.map((b) => b.text).join(' | ');
      parts.add('TXT: ${t.length > 60 ? '${t.substring(0, 60)}…' : t}');
    }
    if (r.objects.isNotEmpty) {
      parts.add(
        'OBJ: ${r.objects.map((o) => o.labels.isNotEmpty ? o.labels.first.text : '#${o.trackingId}').join(', ')}',
      );
    }
    return parts.isEmpty ? '(empty)' : parts.join(' · ');
  }
}

/// Simulates superadmin changing camera scope / plan tier for a store.
class SuperadminScopePage extends StatefulWidget {
  const SuperadminScopePage({super.key, required this.policy});

  final CameraScopePolicy policy;

  @override
  State<SuperadminScopePage> createState() => _SuperadminScopePageState();
}

class _SuperadminScopePageState extends State<SuperadminScopePage> {
  late CameraScopePolicy _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.policy;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Superadmin · Camera scope'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _draft),
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Change what this store’s camera can do without shipping a new app. '
            'Free users get barcode & QR; object detection and batch segmentation '
            'are premium (enable after models are trained / self-labeled).',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text('Plan tier', style: Theme.of(context).textTheme.titleMedium),
          SegmentedButton<PlanTier>(
            segments: const [
              ButtonSegment(value: PlanTier.free, label: Text('Free')),
              ButtonSegment(value: PlanTier.premium, label: Text('Premium')),
            ],
            selected: {_draft.tier},
            onSelectionChanged: (s) {
              setState(() {
                _draft = _draft.withTier(
                  s.first,
                  resetToPreset: true,
                  updatedBy: 'superadmin@demo',
                );
              });
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Capabilities',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...CameraCapability.values.map((cap) {
            final on = _draft.allows(cap);
            return SwitchListTile(
              title: Text(cap.displayName),
              subtitle: Text(
                cap.description +
                    (cap.isPremiumDefault ? ' · premium default' : ''),
              ),
              value: on,
              onChanged: (v) {
                setState(() {
                  _draft = _draft.withCapability(
                    cap,
                    enabled: v,
                    updatedBy: 'superadmin@demo',
                  );
                });
              },
            );
          }),
          const SizedBox(height: 16),
          Text(
            'Policy JSON (persist to Firestore later)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SelectableText(
            const JsonEncoder.withIndent('  ').convert(_draft.toJson()),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }
}
