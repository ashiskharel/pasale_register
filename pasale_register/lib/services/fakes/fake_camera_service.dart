import 'package:pasale_register/services/camera_service.dart';

class FakeCameraService implements CameraService {
  String _mockPath = '/mock/path/to/invoice.jpg';
  int _captureCount = 0;
  String? errorToThrow;
  bool returnNull = false;

  int get captureCount => _captureCount;
  String get mockPath => _mockPath;

  void setMockPath(String path) {
    _mockPath = path;
  }

  @override
  Future<String?> captureInvoicePhoto() async {
    if (errorToThrow != null) {
      throw Exception(errorToThrow);
    }
    _captureCount++;
    if (returnNull) {
      return null;
    }
    return _mockPath;
  }

  @override
  Future<String?> captureProductPhoto() => captureInvoicePhoto();
}
