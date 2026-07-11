import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models/camera_scope_policy.dart';
import 'models/camera_vision_mode.dart';
import 'models/vision_result.dart';
import 'modes/barcode_processor.dart';
import 'modes/object_processor.dart';
import 'modes/text_processor.dart';
import 'platform/input_image_converter.dart';
import 'utils/barcode_debounce.dart';
import 'utils/frame_throttle.dart';

/// Lifecycle + ML Kit processing for a continuous camera session.
///
/// **Scope:** [policy] (from superadmin / plan tier) decides which modes may
/// run. Free default is barcode + QR only; premium unlocks object detection
/// and batch checkout (segmentation path later).
///
/// Host UI owns Start / Done controls. Camera stays active until [stop] or
/// [dispose]. Results are pushed on [results].
class MlkitCameraController extends ChangeNotifier {
  MlkitCameraController({
    CameraScopePolicy? policy,
    this.barcodeDebounceWindow = const Duration(seconds: 2),
    this.processInterval = const Duration(milliseconds: 250),
    this.resolution = ResolutionPreset.high,
    this.enableAudio = false,
    BarcodeProcessor? barcodeProcessor,
    TextProcessor? textProcessor,
    ObjectProcessor? objectProcessor,
  })  : _policy = policy ?? CameraScopePolicy.freeDefault(),
        _barcode = barcodeProcessor ??
            BarcodeProcessor(
              debounce: BarcodeDebounce(window: barcodeDebounceWindow),
            ),
        _text = textProcessor ?? TextProcessor(),
        _objects = objectProcessor ?? ObjectProcessor(),
        _throttle = FrameThrottle(minInterval: processInterval) {
    _mode = _policy.defaultMode;
  }

  final Duration barcodeDebounceWindow;
  final Duration processInterval;
  final ResolutionPreset resolution;
  final bool enableAudio;

  final BarcodeProcessor _barcode;
  final TextProcessor _text;
  final ObjectProcessor _objects;
  final FrameThrottle _throttle;

  final _resultsController = StreamController<VisionResult>.broadcast();

  CameraController? _camera;
  CameraDescription? _description;
  late CameraVisionMode _mode;
  CameraScopePolicy _policy;
  bool _running = false;
  bool _busy = false;
  bool _disposed = false;
  int _multiPhase = 0;
  VisionResult? _lastMulti;
  String? _error;
  DeviceOrientation _orientation = DeviceOrientation.portraitUp;

  /// Live detection stream (debounced barcodes/QR; throttled OCR/objects).
  Stream<VisionResult> get results => _resultsController.stream;

  CameraController? get cameraController => _camera;
  CameraVisionMode get mode => _mode;
  CameraScopePolicy get policy => _policy;
  Set<CameraVisionMode> get allowedModes => _policy.allowedModes;
  bool get isRunning => _running;
  bool get isInitialized => _camera?.value.isInitialized ?? false;
  String? get error => _error;
  VisionResult? get lastMultiSnapshot => _lastMulti;

  /// Superadmin (or backend sync) updates camera scope at runtime.
  ///
  /// If the current mode is no longer allowed, falls back to [CameraScopePolicy.defaultMode]
  /// and restarts the stream when running.
  Future<void> updatePolicy(CameraScopePolicy policy) async {
    if (_disposed) return;
    _policy = policy;
    if (!_policy.allowsMode(_mode)) {
      final next = _policy.defaultMode;
      if (_running) {
        await start(mode: next);
      } else {
        _mode = next;
      }
    }
    notifyListeners();
  }

  /// Initialize the first available camera (back preferred) without starting
  /// the image stream. Safe to call from app startup.
  Future<void> initialize({
    CameraLensDirection prefer = CameraLensDirection.back,
  }) async {
    if (_disposed) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _error = 'No cameras available';
        notifyListeners();
        return;
      }
      _description = cameras.firstWhere(
        (c) => c.lensDirection == prefer,
        orElse: () => cameras.first,
      );
      await _createCamera();
      _error = null;
    } catch (e, st) {
      _error = 'Camera init failed: $e';
      debugPrint('MlkitCameraController.initialize: $e\n$st');
    }
    notifyListeners();
  }

  Future<void> _createCamera() async {
    final desc = _description;
    if (desc == null) return;
    final previous = _camera;
    _camera = CameraController(
      desc,
      resolution,
      enableAudio: enableAudio,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _camera!.initialize();
    await previous?.dispose();
  }

  /// Start continuous processing in [mode] if allowed by [policy].
  Future<void> start({CameraVisionMode? mode}) async {
    if (_disposed) return;
    final requested = mode ?? _policy.defaultMode;
    if (!_policy.allowsMode(requested)) {
      _error =
          'Mode ${requested.name} is not enabled for this store. '
          'Ask a superadmin to change camera scope, or upgrade for premium vision.';
      notifyListeners();
      return;
    }
    _mode = requested;
    if (!isInitialized) {
      await initialize();
    }
    if (!isInitialized) return;

    if (_running) {
      await stop();
    }

    _running = true;
    _throttle.reset();
    _barcode.resetDebounce();
    _multiPhase = 0;
    _lastMulti = null;
    _error = null;
    notifyListeners();

    try {
      await _camera!.startImageStream(_onFrame);
    } catch (e, st) {
      _error = 'Failed to start image stream: $e';
      _running = false;
      debugPrint('MlkitCameraController.start: $e\n$st');
      notifyListeners();
    }
  }

  /// Stop the image stream (maps to "Done Scanning / OK"). Preview may remain.
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    try {
      if (_camera != null && _camera!.value.isStreamingImages) {
        await _camera!.stopImageStream();
      }
    } catch (e) {
      debugPrint('MlkitCameraController.stop: $e');
    }
    notifyListeners();
  }

  Future<void> setMode(CameraVisionMode mode) async {
    if (!_policy.allowsMode(mode)) {
      _error =
          'Mode ${mode.name} is locked by camera scope '
          '(tier: ${_policy.tier.name}).';
      notifyListeners();
      return;
    }
    if (_mode == mode) return;
    final wasRunning = _running;
    if (wasRunning) await stop();
    _mode = mode;
    notifyListeners();
    if (wasRunning) await start(mode: mode);
  }

  Future<void> setTorch(bool enabled) async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    try {
      await cam.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
    } catch (e) {
      debugPrint('setTorch: $e');
    }
  }

  Future<void> switchCamera() async {
    final cameras = await availableCameras();
    if (cameras.length < 2 || _description == null) return;
    final wasRunning = _running;
    if (wasRunning) await stop();
    final idx = cameras.indexWhere(
      (c) => c.name == _description!.name,
    );
    _description = cameras[(idx + 1) % cameras.length];
    await _createCamera();
    notifyListeners();
    if (wasRunning) await start(mode: _mode);
  }

  /// Capture a still image path (invoice / tray photo). Stops stream first.
  Future<String?> captureStill() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return null;
    final wasRunning = _running;
    if (wasRunning) await stop();
    try {
      final file = await cam.takePicture();
      return file.path;
    } catch (e) {
      debugPrint('captureStill: $e');
      return null;
    } finally {
      if (wasRunning) await start(mode: _mode);
    }
  }

  void updateDeviceOrientation(DeviceOrientation orientation) {
    _orientation = orientation;
  }

  Future<void> _onFrame(CameraImage image) async {
    if (!_running || _busy || _disposed) return;
    if (!_throttle.allow()) return;

    final cam = _camera;
    final desc = _description;
    if (cam == null || desc == null) return;

    final input = inputImageFromCameraImage(
      image: image,
      camera: desc,
      deviceOrientation: _orientation,
    );
    if (input == null) return;

    _busy = true;
    try {
      final result = await _process(input);
      if (result != null && result.isNotEmpty && !_disposed) {
        if (!_resultsController.isClosed) {
          _resultsController.add(result);
        }
      }
    } catch (e, st) {
      debugPrint('MlkitCameraController._onFrame: $e\n$st');
    } finally {
      _busy = false;
    }
  }

  Future<VisionResult?> _process(dynamic input) async {
    final now = DateTime.now().toUtc();
    switch (_mode) {
      case CameraVisionMode.barcodeQr:
        final hits = await _barcode.process(input);
        if (hits.isEmpty) return null;
        return VisionResult(
          timestamp: now,
          mode: _mode,
          barcodes: hits,
        );
      case CameraVisionMode.text:
        final blocks = await _text.process(input);
        if (blocks.isEmpty) return null;
        return VisionResult(
          timestamp: now,
          mode: _mode,
          textBlocks: blocks,
        );
      case CameraVisionMode.objectDetection:
        final objs = await _objects.process(input);
        if (objs.isEmpty) return null;
        return VisionResult(
          timestamp: now,
          mode: _mode,
          objects: objs,
        );
      case CameraVisionMode.batchCheckout:
        // Premium path stub: rotate barcode/QR + objects.
        // Later: trained segmentation model → instance masks → SKU match.
        final phase = _multiPhase % 2;
        _multiPhase++;
        late VisionResult partial;
        if (phase == 0) {
          final hits = await _barcode.process(input);
          partial = VisionResult(
            timestamp: now,
            mode: CameraVisionMode.batchCheckout,
            barcodes: hits,
          );
        } else {
          final objs = await _objects.process(input);
          partial = VisionResult(
            timestamp: now,
            mode: CameraVisionMode.batchCheckout,
            objects: objs,
          );
        }
        _lastMulti = (_lastMulti ?? partial).merge(partial).copyWith(
              mode: CameraVisionMode.batchCheckout,
            );
        if (partial.isEmpty) return null;
        return _lastMulti;
    }
  }

  /// Async resource cleanup. Prefer calling this before [dispose] when possible.
  Future<void> close() async {
    if (_disposed) return;
    await stop();
    await _camera?.dispose();
    _camera = null;
    await _barcode.close();
    await _text.close();
    await _objects.close();
    if (!_resultsController.isClosed) {
      await _resultsController.close();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    unawaited(_camera?.dispose() ?? Future.value());
    unawaited(_barcode.close());
    unawaited(_text.close());
    unawaited(_objects.close());
    if (!_resultsController.isClosed) {
      unawaited(_resultsController.close());
    }
    super.dispose();
  }
}
