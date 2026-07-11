import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mlkit_camera/mlkit_camera.dart';
import 'package:vibration/vibration.dart';

import 'scanner_service.dart';

/// Real checkout scanner backed by [mlkit_camera] (barcode + QR free default).
class MlkitScannerService implements ScannerService {
  MlkitScannerService({
    required MlkitCameraController controller,
    AudioPlayer? audioPlayer,
  })  : _controller = controller,
        _audioPlayer = audioPlayer ?? AudioPlayer();

  final MlkitCameraController _controller;
  final AudioPlayer _audioPlayer;

  StreamController<String>? _barcodeOut;
  StreamSubscription<VisionResult>? _resultsSub;
  bool _wired = false;
  Future<void>? _sessionFuture;

  MlkitCameraController get controller => _controller;

  @override
  CameraScopePolicy get cameraPolicy => _controller.policy;

  void _ensureWired() {
    if (_wired) return;
    _wired = true;
    _barcodeOut = StreamController<String>.broadcast();
    _resultsSub = _controller.results.listen((result) {
      for (final hit in result.barcodes) {
        final raw = hit.rawValue.trim();
        if (raw.isNotEmpty) {
          debugPrint('MlkitScannerService: barcode $raw');
          _barcodeOut?.add(raw);
        }
      }
    });
  }

  /// Opens camera (with permission) and starts barcode/QR stream once.
  Future<void> ensureSession() {
    _sessionFuture ??= _openSession().whenComplete(() {
      // Allow retry after failure / stop.
      if (!_controller.isRunning) {
        _sessionFuture = null;
      }
    });
    return _sessionFuture!;
  }

  Future<void> _openSession() async {
    _ensureWired();
    if (!_controller.isInitialized) {
      await _controller.initialize();
    }
    if (!_controller.isInitialized) {
      throw StateError(
        _controller.error ?? 'Camera failed to initialize',
      );
    }
    if (!_controller.isRunning) {
      final mode = _controller.policy.allowsMode(CameraVisionMode.barcodeQr)
          ? CameraVisionMode.barcodeQr
          : _controller.policy.defaultMode;
      await _controller.start(mode: mode);
    }
  }

  @override
  Future<String?> scan() async {
    await ensureSession();
    return _barcodeOut!.stream.first;
  }

  @override
  Future<void> triggerFeedback() async {
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 200);
      }
      await _audioPlayer.play(AssetSource('beep.mp3'));
    } catch (e) {
      debugPrint('Feedback error: $e');
    }
  }

  @override
  Widget buildScannerWidget() {
    return _PasaleScannerPreview(service: this);
  }

  @override
  Future<void> stopScanning() async {
    await _controller.stop();
    _sessionFuture = null;
  }

  @override
  Future<void> applyCameraPolicy(CameraScopePolicy policy) async {
    await _controller.updatePolicy(policy);
  }

  Future<void> dispose() async {
    await _resultsSub?.cancel();
    await _barcodeOut?.close();
    await _audioPlayer.dispose();
    await _controller.close();
    _controller.dispose();
  }
}

/// Stateful preview so camera init runs once and rebuilds when ready.
class _PasaleScannerPreview extends StatefulWidget {
  const _PasaleScannerPreview({required this.service});

  final MlkitScannerService service;

  @override
  State<_PasaleScannerPreview> createState() => _PasaleScannerPreviewState();
}

class _PasaleScannerPreviewState extends State<_PasaleScannerPreview> {
  late Future<void> _ready;
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _ready = widget.service.ensureSession();
    _listener = () {
      if (mounted) setState(() {});
    };
    widget.service.controller.addListener(_listener);
  }

  @override
  void dispose() {
    widget.service.controller.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ColoredBox(
            color: Colors.black,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Camera error:\n${snapshot.error}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return MlkitCameraView(
          controller: widget.service.controller,
          showOverlay: true,
        );
      },
    );
  }
}
