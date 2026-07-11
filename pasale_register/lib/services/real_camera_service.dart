import 'package:mlkit_camera/mlkit_camera.dart';

import 'camera_service.dart';

/// Invoice / still capture via shared [MlkitCameraController].
class RealCameraService implements CameraService {
  RealCameraService({required MlkitCameraController controller})
      : _controller = controller;

  final MlkitCameraController _controller;

  @override
  Future<String?> captureInvoicePhoto() async {
    if (!_controller.isInitialized) {
      await _controller.initialize();
    }
    return _controller.captureStill();
  }

  @override
  Future<String?> captureProductPhoto() => captureInvoicePhoto();
}
