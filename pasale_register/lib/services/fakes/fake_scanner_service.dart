import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mlkit_camera/mlkit_camera.dart';
import 'package:pasale_register/services/scanner_service.dart';
import 'package:pasale_register/utils/price_ocr_parser.dart';

class FakeScannerService implements ScannerService {
  final StreamController<String> _barcodeController =
      StreamController<String>.broadcast();
  final StreamController<OcrLabelParse> _ocrController =
      StreamController<OcrLabelParse>.broadcast();
  int _feedbackCount = 0;
  String? errorToThrow;
  bool returnNull = false;
  bool throwFeedbackError = false;
  CameraScopePolicy _policy = CameraScopePolicy.freeDefault();
  CameraVisionMode _mode = CameraVisionMode.barcodeQr;
  int stopCount = 0;

  StreamController<String> get barcodeController => _barcodeController;

  void simulateScan(String barcode) {
    _barcodeController.add(barcode);
  }

  void simulateOcrPrice(double price, {String? notes}) {
    _ocrController.add(OcrLabelParse(
      price: price,
      notes: notes,
      rawSnippet: 'Rs. $price',
    ));
  }

  int get feedbackCount => _feedbackCount;

  @override
  CameraVisionMode get visionMode => _mode;

  @override
  Future<void> setVisionMode(CameraVisionMode mode) async {
    _mode = mode;
  }

  @override
  Future<String?> scan() async {
    _mode = CameraVisionMode.barcodeQr;
    if (errorToThrow != null) {
      throw Exception(errorToThrow);
    }
    if (returnNull) {
      return null;
    }
    final val = await _barcodeController.stream.first;
    if (val == '__null__') {
      return null;
    }
    return val;
  }

  @override
  Future<OcrLabelParse?> scanPriceLabel() async {
    _mode = CameraVisionMode.text;
    if (errorToThrow != null) {
      throw Exception(errorToThrow);
    }
    if (returnNull) return null;
    return _ocrController.stream.first;
  }

  @override
  Future<void> triggerFeedback() async {
    if (throwFeedbackError) {
      throw Exception('Feedback failure');
    }
    _feedbackCount++;
  }

  @override
  Widget buildScannerWidget() {
    return Container(
      key: const Key('scanPreview'),
      color: Colors.black,
      alignment: Alignment.center,
      child: Text(
        _mode == CameraVisionMode.text
            ? 'Fake Camera · Price tag OCR'
            : 'Fake Camera Active',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  Future<void> stopScanning() async {
    stopCount++;
  }

  @override
  Future<void> applyCameraPolicy(CameraScopePolicy policy) async {
    _policy = policy;
  }

  @override
  CameraScopePolicy get cameraPolicy => _policy;
}
