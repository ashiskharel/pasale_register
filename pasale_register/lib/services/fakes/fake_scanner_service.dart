import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pasale_register/services/scanner_service.dart';

class FakeScannerService implements ScannerService {
  final StreamController<String> _barcodeController =
      StreamController<String>.broadcast();
  int _feedbackCount = 0;
  String? errorToThrow;
  bool returnNull = false;
  bool throwFeedbackError = false;

  // Stream getter/helper to push mock barcodes
  StreamController<String> get barcodeController => _barcodeController;

  void simulateScan(String barcode) {
    _barcodeController.add(barcode);
  }

  int get feedbackCount => _feedbackCount;

  @override
  Future<String?> scan() async {
    if (errorToThrow != null) {
      throw Exception(errorToThrow);
    }
    if (returnNull) {
      return null;
    }
    final val = await _barcodeController.stream.first;
    if (val == "__null__") {
      return null;
    }
    return val;
  }

  @override
  Future<void> triggerFeedback() async {
    if (throwFeedbackError) {
      throw Exception("Feedback failure");
    }
    _feedbackCount++;
  }

  @override
  Widget buildScannerWidget() {
    return Container(
      key: const Key('scanPreview'),
      color: Colors.black,
      alignment: Alignment.center,
      child: const Text('Fake Camera Active', style: TextStyle(color: Colors.white)),
    );
  }
}
