import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mlkit_camera/mlkit_camera.dart';
import 'package:vibration/vibration.dart';

import '../utils/price_ocr_parser.dart';
import 'scanner_service.dart';

/// Real checkout scanner: barcode/QR + live price-tag OCR.
class MlkitScannerService implements ScannerService {
  MlkitScannerService({
    required MlkitCameraController controller,
    AudioPlayer? audioPlayer,
    PriceOcrParser? priceParser,
  })  : _controller = controller,
        _audioPlayer = audioPlayer ?? AudioPlayer(),
        _parser = priceParser ?? PriceOcrParser();

  final MlkitCameraController _controller;
  final AudioPlayer _audioPlayer;
  final PriceOcrParser _parser;

  StreamController<String>? _barcodeOut;
  StreamController<OcrLabelParse>? _ocrOut;
  StreamSubscription<VisionResult>? _resultsSub;
  bool _wired = false;
  Future<void>? _sessionFuture;

  // Debounce OCR: same currency-marked price across several frames.
  double? _lastOcrPrice;
  int _ocrHits = 0;
  static const _ocrConfirmHits = 3;
  static const _priceTolerance = 0.05;

  MlkitCameraController get controller => _controller;

  @override
  CameraScopePolicy get cameraPolicy => _controller.policy;

  @override
  CameraVisionMode get visionMode => _controller.mode;

  void _ensureWired() {
    if (_wired) return;
    _wired = true;
    _barcodeOut = StreamController<String>.broadcast();
    _ocrOut = StreamController<OcrLabelParse>.broadcast();
    _resultsSub = _controller.results.listen(_onVisionResult);
  }

  void _onVisionResult(VisionResult result) {
    if (result.mode == CameraVisionMode.barcodeQr ||
        result.barcodes.isNotEmpty) {
      for (final hit in result.barcodes) {
        final raw = hit.rawValue.trim();
        if (raw.isNotEmpty) {
          debugPrint('MlkitScannerService: barcode $raw');
          _barcodeOut?.add(raw);
        }
      }
    }

    // Only treat text frames when in price-tag mode (avoid random barcode frames).
    if (_controller.mode != CameraVisionMode.text) return;
    if (result.textBlocks.isEmpty) return;

    final texts = <String>[];
    for (final block in result.textBlocks) {
      texts.add(block.text);
      texts.addAll(block.lines);
    }

    final parsed = _parser.parse(texts);
    // Require Rs/NPR/रु (or PRICE/MRP) — never open dialog on bare random digits.
    if (!parsed.isReliableForPos) {
      if (parsed.rawSnippet != null && parsed.rawSnippet!.isNotEmpty) {
        debugPrint(
          'MlkitScannerService: OCR weak/no currency '
          '"${parsed.rawSnippet}" conf=${parsed.confidence}',
        );
      }
      return;
    }

    final p = parsed.price!;
    if (_lastOcrPrice != null && (p - _lastOcrPrice!).abs() < _priceTolerance) {
      _ocrHits++;
    } else {
      _lastOcrPrice = p;
      _ocrHits = 1;
    }

    debugPrint(
      'MlkitScannerService: OCR candidate Rs.$p '
      'hits=$_ocrHits/$_ocrConfirmHits currency=${parsed.hasCurrencyMarker}',
    );

    if (_ocrHits >= _ocrConfirmHits) {
      debugPrint('MlkitScannerService: OCR price CONFIRMED $p');
      if (_ocrOut != null && !_ocrOut!.isClosed) {
        _ocrOut!.add(parsed);
      }
      _ocrHits = 0;
      _lastOcrPrice = null;
    }
  }

  /// Opens camera and starts the current vision mode stream once.
  Future<void> ensureSession({CameraVisionMode? mode}) async {
    // Retry after a failed permission attempt (do not stick on a dead Future).
    if (_sessionFuture != null) {
      try {
        await _sessionFuture;
        if (_controller.isInitialized) {
          // Session ok — only switch mode if needed below.
          await _openSession(mode: mode);
          return;
        }
      } catch (_) {
        _sessionFuture = null;
      }
    }
    final future = _openSession(mode: mode);
    _sessionFuture = future;
    try {
      await future;
    } catch (_) {
      _sessionFuture = null;
      rethrow;
    }
    if (!_controller.isRunning || !_controller.isInitialized) {
      _sessionFuture = null;
    }
  }

  Future<void> _openSession({CameraVisionMode? mode}) async {
    _ensureWired();
    if (!_controller.isInitialized) {
      try {
        await _controller.initialize();
      } catch (e) {
        _sessionFuture = null;
        throw StateError('Camera permission denied or hardware error: $e');
      }
    }
    if (!_controller.isInitialized) {
      final msg = _controller.error ?? 'Camera failed to initialize';
      _sessionFuture = null;
      throw StateError(msg);
    }

    // Important: when [mode] is null (preview warm-up), keep the current mode.
    // Previously we always defaulted to barcode and overwrote Price Tag OCR.
    final want = mode ??
        (_controller.isRunning
            ? _controller.mode
            : (_controller.policy.allowsMode(CameraVisionMode.barcodeQr)
                ? CameraVisionMode.barcodeQr
                : _controller.policy.defaultMode));

    if (!_controller.policy.allowsMode(want)) {
      throw StateError(
        'Camera mode ${want.name} is not enabled for this store. '
        'Enable Text (OCR) in camera scope / plan.',
      );
    }

    if (!_controller.isRunning) {
      await _controller.start(mode: want);
    } else if (_controller.mode != want) {
      // Properly switch processors while streaming (barcode ↔ text).
      await _controller.setMode(want);
    }
  }

  @override
  Future<void> setVisionMode(CameraVisionMode mode) async {
    _lastOcrPrice = null;
    _ocrHits = 0;
    // Ensure price-tag OCR is allowed even if store policy was barcode-only.
    if (mode == CameraVisionMode.text &&
        !_controller.policy.allowsMode(CameraVisionMode.text)) {
      await _controller.updatePolicy(
        _controller.policy.withCapability(
          CameraCapability.textOcr,
          enabled: true,
          updatedBy: 'system-pos',
        ),
      );
    }
    await ensureSession(mode: mode);
    if (_controller.mode != mode) {
      if (!_controller.policy.allowsMode(mode)) {
        throw StateError(
          'Mode ${mode.name} not allowed by camera policy. '
          'Enable Text (OCR) under Cam Scope, or re-open the app after update.',
        );
      }
      await _controller.setMode(mode);
    }
  }

  @override
  Future<String?> scan() async {
    await setVisionMode(CameraVisionMode.barcodeQr);
    return _barcodeOut!.stream.first;
  }

  @override
  Future<OcrLabelParse?> scanPriceLabel() async {
    // Always go through setVisionMode so barcode-only scopes get textOcr
    // and the image stream runs TextRecognizer (not barcode only).
    await setVisionMode(CameraVisionMode.text);
    debugPrint(
      'MlkitScannerService: waiting for OCR price '
      '(mode=${_controller.mode.name} running=${_controller.isRunning})',
    );
    return _ocrOut!.stream.first.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        throw StateError(
          'No reliable price in 45s. Show a clear “Rs. 25” / “NPR 50” style '
          'amount (currency + number). Bare digits are ignored on purpose.',
        );
      },
    );
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
    _lastOcrPrice = null;
    _ocrHits = 0;
  }

  @override
  Future<void> applyCameraPolicy(CameraScopePolicy policy) async {
    await _controller.updatePolicy(policy);
  }

  Future<void> dispose() async {
    await _resultsSub?.cancel();
    await _barcodeOut?.close();
    await _ocrOut?.close();
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
