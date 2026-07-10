import 'package:flutter/material.dart';

abstract class ScannerService {
  Future<String?> scan();
  Future<void> triggerFeedback();
  Widget buildScannerWidget();
}
