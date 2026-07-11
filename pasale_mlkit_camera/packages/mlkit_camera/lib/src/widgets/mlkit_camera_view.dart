import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mlkit_camera_controller.dart';
import '../models/vision_result.dart';
import 'detection_overlay.dart';

/// Camera preview bound to [MlkitCameraController], with optional overlays.
///
/// Host owns Start / Done buttons and result lists — this widget only shows
/// the live feed and last detection boxes.
class MlkitCameraView extends StatefulWidget {
  const MlkitCameraView({
    super.key,
    required this.controller,
    this.showOverlay = true,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.onResult,
  });

  final MlkitCameraController controller;
  final bool showOverlay;
  final BoxFit fit;
  final Widget? placeholder;
  final ValueChanged<VisionResult>? onResult;

  @override
  State<MlkitCameraView> createState() => _MlkitCameraViewState();
}

class _MlkitCameraViewState extends State<MlkitCameraView> {
  VisionResult? _last;
  late final VoidCallback _listener;
  StreamSubscription<VisionResult>? _sub;

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (mounted) setState(() {});
    };
    widget.controller.addListener(_listener);
    _sub = widget.controller.results.listen((r) {
      if (!mounted) return;
      setState(() => _last = r);
      widget.onResult?.call(r);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.orientationOf(context);
    widget.controller.updateDeviceOrientation(
      orientation == Orientation.portrait
          ? DeviceOrientation.portraitUp
          : DeviceOrientation.landscapeLeft,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final cam = c.cameraController;
    final err = c.error;

    if (err != null && !c.isInitialized) {
      return widget.placeholder ??
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(err, textAlign: TextAlign.center),
            ),
          );
    }

    if (cam == null || !cam.value.isInitialized) {
      return widget.placeholder ??
          const Center(child: CircularProgressIndicator());
    }

    final previewSize = cam.value.previewSize;
    final imageSize = previewSize != null
        ? Size(previewSize.height, previewSize.width)
        : const Size(1, 1);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: widget.fit,
            child: SizedBox(
              width: cam.value.previewSize?.height ?? 1,
              height: cam.value.previewSize?.width ?? 1,
              child: CameraPreview(cam),
            ),
          ),
          if (widget.showOverlay)
            DetectionOverlay(result: _last, imageSize: imageSize),
          if (err != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    err,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
