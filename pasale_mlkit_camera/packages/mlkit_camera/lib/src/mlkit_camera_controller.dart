import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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
class MlkitCameraController extends ChangeNotifier {
  MlkitCameraController({
    CameraScopePolicy? policy,
    this.barcodeDebounceWindow = const Duration(seconds: 2),
    this.processInterval = const Duration(milliseconds: 250),
    this.resolution = ResolutionPreset.medium,
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
  bool _initializing = false;
  Future<void>? _initFuture;
  int _multiPhase = 0;
  VisionResult? _lastMulti;
  String? _error;
  DeviceOrientation _orientation = DeviceOrientation.portraitUp;
  int _dropLogCount = 0;

  Stream<VisionResult> get results => _resultsController.stream;

  CameraController? get cameraController => _camera;
  CameraVisionMode get mode => _mode;
  CameraScopePolicy get policy => _policy;
  Set<CameraVisionMode> get allowedModes => _policy.allowedModes;
  bool get isRunning => _running;
  bool get isInitialized => _camera?.value.isInitialized ?? false;
  bool get isInitializing => _initializing;
  String? get error => _error;
  VisionResult? get lastMultiSnapshot => _lastMulti;

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

  /// Request camera permission, open device camera (back preferred).
  Future<void> initialize({
    CameraLensDirection prefer = CameraLensDirection.back,
  }) {
    if (_disposed) return Future.value();
    if (isInitialized) return Future.value();
    _initFuture ??= _doInitialize(prefer: prefer);
    return _initFuture!.whenComplete(() {
      _initFuture = null;
    });
  }

  Future<void> _doInitialize({
    required CameraLensDirection prefer,
  }) async {
    if (_disposed || isInitialized) return;
    _initializing = true;
    _error = null;
    notifyListeners();

    try {
      final permitted = await _ensureCameraPermission();
      if (!permitted) {
        _error =
            'Camera permission denied. Enable Camera in system settings for Pasale Register.';
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _error = 'No cameras available on this device.';
        return;
      }
      _description = cameras.firstWhere(
        (c) => c.lensDirection == prefer,
        orElse: () => cameras.first,
      );
      await _createCamera();
      if (isInitialized) {
        _error = null;
        debugPrint(
          'MlkitCameraController: ready '
          '${_description?.name} '
          'preview=${_camera?.value.previewSize}',
        );
      }
    } catch (e, st) {
      _error = 'Camera init failed: $e';
      debugPrint('MlkitCameraController.initialize: $e\n$st');
      await _camera?.dispose();
      _camera = null;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  /// Request camera permission without jumping to system Settings.
  ///
  /// Previously we called [openAppSettings] on permanently-denied, which sent
  /// users to the Android App Info page the moment they tapped Open Scanner.
  /// Now we only request the system dialog; Settings is opened only when the
  /// user taps an explicit "Open settings" control in the UI.
  Future<bool> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted || status.isLimited) return true;

    // Always try the system prompt first (covers first-run + denied-once).
    status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied || status.isRestricted) {
      _error =
          'Camera access is blocked. Tap Open settings, enable Camera for '
          'Pasale Register, then return and try again.';
    } else {
      _error =
          'Camera permission is required to scan. Tap Allow when prompted, '
          'or Open settings if the prompt does not appear.';
    }
    return false;
  }

  /// Opens the OS app settings page (user-initiated only).
  Future<bool> openSystemAppSettings() => openAppSettings();

  Future<void> _createCamera() async {
    final desc = _description;
    if (desc == null) return;
    final previous = _camera;

    // Prefer formats that work for both preview + ML Kit on each platform.
    final formats = <ImageFormatGroup>[
      if (Platform.isAndroid) ImageFormatGroup.nv21,
      if (Platform.isAndroid) ImageFormatGroup.yuv420,
      if (Platform.isIOS) ImageFormatGroup.bgra8888,
      ImageFormatGroup.yuv420,
    ];

    Object? lastError;
    for (final format in formats) {
      try {
        final next = CameraController(
          desc,
          resolution,
          enableAudio: enableAudio,
          imageFormatGroup: format,
        );
        await next.initialize();
        _camera = next;
        await previous?.dispose();
        debugPrint('MlkitCameraController: using imageFormatGroup=$format');
        return;
      } catch (e) {
        lastError = e;
        debugPrint('MlkitCameraController: format $format failed: $e');
      }
    }
    throw lastError ?? Exception('Unable to open camera');
  }

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
    if (!isInitialized) {
      await initialize();
    }
    if (!isInitialized) return;

    // Switching mode while already streaming: update processor without
    // restarting the camera (setMode also handles stop/start when needed).
    if (_running) {
      if (_mode != requested) {
        _mode = requested;
        _barcode.resetDebounce();
        _multiPhase = 0;
        _lastMulti = null;
        debugPrint('MlkitCameraController: live mode → ${requested.name}');
      }
      notifyListeners();
      return;
    }

    _mode = requested;
    _running = true;
    _throttle.reset();
    _barcode.resetDebounce();
    _multiPhase = 0;
    _lastMulti = null;
    _error = null;
    _dropLogCount = 0;
    notifyListeners();

    try {
      if (!_camera!.value.isStreamingImages) {
        await _camera!.startImageStream(_onFrame);
      }
      debugPrint('MlkitCameraController: stream started mode=${_mode.name}');
    } catch (e, st) {
      _error = 'Failed to start image stream: $e';
      _running = false;
      debugPrint('MlkitCameraController.start: $e\n$st');
      notifyListeners();
    }
  }

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

  /// Capture a JPEG still.
  ///
  /// [resumeStream] — when true (default), restarts the vision image stream
  /// if it was running. Use `false` for product-photo capture inside a dialog
  /// so the live [CameraPreview] stays available without ML processing.
  Future<String?> captureStill({bool resumeStream = true}) async {
    if (!isInitialized) {
      await initialize();
    }
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      debugPrint('captureStill: camera not initialized');
      return null;
    }
    final wasRunning = _running;
    if (wasRunning) await stop();
    // stopImageStream can leave the controller briefly busy; brief pause helps
    // takePicture on some Android devices.
    if (wasRunning) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    try {
      final file = await cam.takePicture();
      debugPrint('captureStill: saved ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('captureStill: $e');
      return null;
    } finally {
      if (resumeStream && wasRunning && !_disposed) {
        await start(mode: _mode);
      }
    }
  }

  /// Stop ML image stream but keep the camera open for [CameraPreview] / stills.
  Future<void> preparePreviewOnly() async {
    if (!isInitialized) {
      await initialize();
    }
    if (_running) {
      await stop();
    }
  }

  void updateDeviceOrientation(DeviceOrientation orientation) {
    _orientation = orientation;
  }

  Future<void> _onFrame(CameraImage image) async {
    if (!_running || _busy || _disposed) return;
    if (!_throttle.allow()) return;

    final desc = _description;
    if (desc == null) return;

    final input = inputImageFromCameraImage(
      image: image,
      camera: desc,
      deviceOrientation: _orientation,
    );
    if (input == null) {
      if (_dropLogCount < 5) {
        _dropLogCount++;
        debugPrint(
          'MlkitCameraController: dropped frame '
          '(format=${image.format.raw} planes=${image.planes.length})',
        );
      }
      return;
    }

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
