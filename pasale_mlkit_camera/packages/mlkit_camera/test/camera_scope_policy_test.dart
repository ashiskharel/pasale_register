import 'package:flutter_test/flutter_test.dart';
import 'package:mlkit_camera/mlkit_camera.dart';

void main() {
  group('CameraScopePolicy', () {
    test('free default is barcode/QR + text OCR', () {
      final p = CameraScopePolicy.freeDefault();
      expect(p.tier, PlanTier.free);
      expect(p.enabled, {
        CameraCapability.barcodeQr,
        CameraCapability.textOcr,
      });
      expect(p.allowsMode(CameraVisionMode.barcodeQr), isTrue);
      expect(p.allowsMode(CameraVisionMode.text), isTrue);
      expect(p.allowsMode(CameraVisionMode.objectDetection), isFalse);
      expect(p.allowsMode(CameraVisionMode.batchCheckout), isFalse);
      expect(p.defaultMode, CameraVisionMode.barcodeQr);
      expect(p.lockedPremiumCapabilities, [
        CameraCapability.objectDetection,
        CameraCapability.batchSegmentation,
      ]);
    });

    test('premium default unlocks detection and batch', () {
      final p = CameraScopePolicy.premiumDefault();
      expect(p.tier, PlanTier.premium);
      expect(p.allows(CameraCapability.objectDetection), isTrue);
      expect(p.allows(CameraCapability.batchSegmentation), isTrue);
      expect(p.allowedModes, contains(CameraVisionMode.batchCheckout));
      expect(p.lockedPremiumCapabilities, isEmpty);
    });

    test('superadmin can enable object detection on free tier', () {
      var p = CameraScopePolicy.freeDefault();
      p = p.withCapability(
        CameraCapability.objectDetection,
        enabled: true,
        updatedBy: 'admin',
      );
      expect(p.tier, PlanTier.free);
      expect(p.allowsMode(CameraVisionMode.objectDetection), isTrue);
      expect(p.updatedBy, 'admin');
    });

    test('cannot disable last capability — falls back to barcodeQr', () {
      var p = CameraScopePolicy.freeDefault();
      p = p.withCapability(CameraCapability.barcodeQr, enabled: false);
      // textOcr still remains
      expect(p.allows(CameraCapability.barcodeQr), isFalse);
      expect(p.allows(CameraCapability.textOcr), isTrue);
      p = p.withCapability(CameraCapability.textOcr, enabled: false);
      // Empty set is replaced with barcodeQr
      expect(p.allows(CameraCapability.barcodeQr), isTrue);
    });

    test('JSON round-trip', () {
      final original = CameraScopePolicy.premiumDefault(updatedBy: 'sa');
      final restored = CameraScopePolicy.fromJson(original.toJson());
      expect(restored.tier, original.tier);
      expect(restored.enabled, original.enabled);
      expect(restored.updatedBy, 'sa');
    });

    test('withTier reset applies presets', () {
      final free = CameraScopePolicy.premiumDefault().withTier(PlanTier.free);
      expect(free.enabled, {
        CameraCapability.barcodeQr,
        CameraCapability.textOcr,
      });
      final prem = free.withTier(PlanTier.premium);
      expect(prem.allows(CameraCapability.batchSegmentation), isTrue);
    });
  });
}
