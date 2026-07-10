import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'scanner_service.dart';

class RealScannerService implements ScannerService {
  StreamController<String>? _controller;
  DateTime? _lastScan;
  String? _lastBarcode;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  Future<String?> scan() async {
    _controller ??= StreamController<String>.broadcast();
    return await _controller!.stream.first;
  }

  @override
  Future<void> triggerFeedback() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 200);
      }
      await _audioPlayer.play(AssetSource('beep.mp3'));
    } catch (e) {
      debugPrint('Feedback error: $e');
    }
  }

  @override
  Widget buildScannerWidget() {
    return MobileScanner(
      onDetect: (capture) {
        final barcodes = capture.barcodes;
        for (final b in barcodes) {
          if (b.rawValue != null) {
            final now = DateTime.now();
            if (_lastBarcode == b.rawValue && _lastScan != null) {
              // Debounce 2 seconds for the same barcode
               if (now.difference(_lastScan!).inSeconds < 2) continue;
            }
            _lastBarcode = b.rawValue;
            _lastScan = now;
            
            _controller?.add(b.rawValue!);
          }
        }
      },
    );
  }
}
