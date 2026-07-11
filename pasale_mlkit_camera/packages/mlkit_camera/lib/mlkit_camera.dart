/// On-device camera vision with Google ML Kit.
///
/// Free default: **barcode + QR** scanning. Premium / superadmin scope can
/// unlock OCR, object detection, and batch checkout (segmentation later).
///
/// **License note:** This Dart package is open source. Google ML Kit binaries
/// are proprietary (free for use) and remain subject to Google's terms.
library;

export 'src/mlkit_camera_controller.dart';
export 'src/models/barcode_hit.dart';
export 'src/models/bounding_box.dart';
export 'src/models/camera_capability.dart';
export 'src/models/camera_scope_policy.dart';
export 'src/models/camera_vision_mode.dart';
export 'src/models/object_hit.dart';
export 'src/models/text_block_hit.dart';
export 'src/models/vision_result.dart';
export 'src/utils/barcode_debounce.dart';
export 'src/utils/frame_throttle.dart';
export 'src/widgets/detection_overlay.dart';
export 'src/widgets/mlkit_camera_view.dart';
