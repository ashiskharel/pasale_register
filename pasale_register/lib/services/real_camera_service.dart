import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mlkit_camera/mlkit_camera.dart';

import 'camera_service.dart';

/// Invoice / product still capture via shared [MlkitCameraController].
class RealCameraService implements CameraService {
  RealCameraService({required MlkitCameraController controller})
      : _controller = controller;

  final MlkitCameraController _controller;

  @override
  Future<String?> captureInvoicePhoto() async {
    if (!_controller.isInitialized) {
      try {
        await _controller.initialize();
      } catch (e) {
        debugPrint('Camera error: $e');
      }
    }
    // Invoice flow can resume scan stream afterward.
    return _controller.captureStill(resumeStream: true);
  }

  @override
  Future<String?> captureProductPhoto() async {
    await prepareProductPhotoSession();
    // Fix CAM-01: resume stream after capturing photo
    return _controller.captureStill(resumeStream: true);
  }

  @override
  Future<void> prepareProductPhotoSession() async {
    // Start text OCR stream instead of just the visual preview
    if (!_controller.isInitialized) {
      try {
        await _controller.initialize();
      } catch (e) {
        debugPrint('Camera error: $e');
      }
    }
    await _controller.start(mode: CameraVisionMode.text);
  }

  @override
  Stream<String> get productNameStream {
    return _controller.results
        .where((r) => r.mode == CameraVisionMode.text && r.textBlocks.isNotEmpty)
        .map((result) {
      // Find the text block with the largest physical bounding box area
      var largestBlock = result.textBlocks.reduce((a, b) {
        final aArea = (a.boundingBox?.width ?? 0) * (a.boundingBox?.height ?? 0);
        final bArea = (b.boundingBox?.width ?? 0) * (b.boundingBox?.height ?? 0);
        return aArea > bArea ? a : b;
      });
      return largestBlock.text.replaceAll('\n', ' ').trim();
    }).distinct();
  }

  @override
  Widget? buildProductPhotoPreview() {
    final cam = _controller.cameraController;
    if (cam == null || !cam.value.isInitialized) {
      return null;
    }
    return ColoredBox(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: cam.value.previewSize?.height ?? 480,
          height: cam.value.previewSize?.width ?? 640,
          child: CameraPreview(cam),
        ),
      ),
    );
  }
}
