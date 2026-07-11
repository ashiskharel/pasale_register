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
          _barcodeOut?.add(raw);
        }
      }
    });
  }

  Future<void> _ensureSession() async {
    _ensureWired();
    if (!_controller.isInitialized) {
      await _controller.initialize();
    }
    if (!_controller.isRunning) {
      // Prefer barcode/QR; fall back to policy default if somehow locked.
      final mode = _controller.policy.allowsMode(CameraVisionMode.barcodeQr)
          ? CameraVisionMode.barcodeQr
          : _controller.policy.defaultMode;
      await _controller.start(mode: mode);
    }
  }

  @override
  Future<String?> scan() async {
    await _ensureSession();
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
    return FutureBuilder<void>(
      future: _ensureSession(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Camera error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          );
        }
        return MlkitCameraView(
          controller: _controller,
          key: const Key('scanPreview'),
        );
      },
    );
  }

  @override
  Future<void> stopScanning() async {
    await _controller.stop();
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
