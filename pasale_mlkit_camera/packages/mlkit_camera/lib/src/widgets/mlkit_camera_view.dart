import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mlkit_camera_controller.dart';
import '../models/vision_result.dart';
import 'detection_overlay.dart';

/// Camera preview bound to [MlkitCameraController], with optional overlays.
class MlkitCameraView extends StatefulWidget {
  const MlkitCameraView({
    super.key,
    required this.controller,
    this.showOverlay = true,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.onResult,
    this.autoStart = false,
  });

  final MlkitCameraController controller;
  final bool showOverlay;
  final BoxFit fit;
  final Widget? placeholder;
  final ValueChanged<VisionResult>? onResult;

  /// When true, initializes (and starts stream if already requested by host).
  final bool autoStart;

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
    if (widget.autoStart && !widget.controller.isInitialized) {
      unawaited(widget.controller.initialize());
    }
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
      return _messageBox(
        err,
        icon: Icons.videocam_off,
        actionLabel: err.contains('permission') ? 'Open settings' : null,
        onAction: err.contains('permission')
            ? () => c.initialize() // re-request / reopen settings path
            : null,
      );
    }

    if (c.isInitializing || cam == null || !cam.value.isInitialized) {
      return widget.placeholder ??
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Starting camera…',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
    }

    final previewSize = cam.value.previewSize;
    // Camera plugin reports size in landscape; swap for portrait preview box.
    final previewW = previewSize?.height ?? 1.0;
    final previewH = previewSize?.width ?? 1.0;
    final imageSize = Size(previewW, previewH);

    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: widget.fit,
                child: SizedBox(
                  width: previewW,
                  height: previewH,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(cam),
                      if (widget.showOverlay)
                        DetectionOverlay(
                          result: _last,
                          imageSize: imageSize,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _messageBox(
    String text, {
    IconData icon = Icons.error_outline,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white70, size: 36),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
