import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

/// Converts a [CameraImage] from the `camera` plugin into an ML Kit [InputImage].
///
/// Handles Android YUV_420_888 and iOS BGRA8888. Returns `null` when the
/// platform/format cannot be mapped safely.
InputImage? inputImageFromCameraImage({
  required CameraImage image,
  required CameraDescription camera,
  required DeviceOrientation deviceOrientation,
  int? sensorOrientationOverride,
}) {
  final rotation = _rotation(
    camera: camera,
    deviceOrientation: deviceOrientation,
    sensorOrientationOverride: sensorOrientationOverride,
  );
  if (rotation == null) return null;

  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  // Android: nv21; iOS: bgra8888 — reject unsupported.
  if (format == null ||
      (Platform.isAndroid && format != InputImageFormat.nv21) ||
      (Platform.isIOS && format != InputImageFormat.bgra8888)) {
    // On many Android devices the stream is YUV_420_888; build NV21 bytes.
    if (Platform.isAndroid && image.planes.length >= 2) {
      final bytes = _yuv420ToNv21(image);
      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      );
      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    }
    return null;
  }

  if (image.planes.isEmpty) return null;

  // Single-plane formats (NV21 / BGRA).
  if (image.planes.length == 1 || format == InputImageFormat.bgra8888) {
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // Multi-plane Android: convert to NV21.
  if (Platform.isAndroid) {
    final bytes = _yuv420ToNv21(image);
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      ),
    );
  }

  return null;
}

InputImageRotation? _rotation({
  required CameraDescription camera,
  required DeviceOrientation deviceOrientation,
  int? sensorOrientationOverride,
}) {
  final sensorOrientation = sensorOrientationOverride ?? camera.sensorOrientation;
  if (Platform.isIOS) {
    return InputImageRotationValue.fromRawValue(sensorOrientation);
  }

  // Android: compensate for device orientation.
  final orientations = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
  var rotationCompensation = orientations[deviceOrientation];
  if (rotationCompensation == null) return null;

  if (camera.lensDirection == CameraLensDirection.front) {
    rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
  } else {
    rotationCompensation =
        (sensorOrientation - rotationCompensation + 360) % 360;
  }
  return InputImageRotationValue.fromRawValue(rotationCompensation);
}

/// Packs YUV_420_888 planes into NV21 (Y + interleaved VU).
Uint8List _yuv420ToNv21(CameraImage image) {
  final width = image.width;
  final height = image.height;
  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes.length > 2 ? image.planes[2] : uPlane;

  final ySize = width * height;
  final uvSize = width * height ~/ 2;
  final out = Uint8List(ySize + uvSize);

  // Copy Y, respecting row stride.
  var outIndex = 0;
  final yRowStride = yPlane.bytesPerRow;
  final yBytes = yPlane.bytes;
  for (var row = 0; row < height; row++) {
    final start = row * yRowStride;
    final end = start + width;
    if (end <= yBytes.length) {
      out.setRange(outIndex, outIndex + width, yBytes, start);
    }
    outIndex += width;
  }

  // Interleave V and U for NV21.
  final uvRowStride = vPlane.bytesPerRow;
  final uvPixelStride = vPlane.bytesPerPixel ?? 1;
  final uBytes = uPlane.bytes;
  final vBytes = vPlane.bytes;
  final uvHeight = height ~/ 2;
  final uvWidth = width ~/ 2;

  var uvIndex = ySize;
  for (var row = 0; row < uvHeight; row++) {
    for (var col = 0; col < uvWidth; col++) {
      final vIndex = row * uvRowStride + col * uvPixelStride;
      final uIndex =
          row * uPlane.bytesPerRow + col * (uPlane.bytesPerPixel ?? 1);
      if (vIndex < vBytes.length && uIndex < uBytes.length && uvIndex + 1 < out.length) {
        out[uvIndex++] = vBytes[vIndex];
        out[uvIndex++] = uBytes[uIndex];
      }
    }
  }

  return out;
}
