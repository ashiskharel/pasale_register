import 'package:flutter/material.dart';

/// Brand asset paths (declared in pubspec.yaml).
abstract final class PasaleBrand {
  static const logoAsset = 'assets/brand/pasale_p_logo_icon.jpg';
  /// Optional large marketing video — not bundled by default (APK size).
  /// Re-enable in pubspec after compressing with ffmpeg.
  static const heroVideoAsset = 'assets/brand/pasale_digitally_empowering.mp4';
  static const heroPosterAsset =
      'assets/brand/pasale_digitally_empowering_scene.jpg';

  /// When false, landing uses the static poster only (recommended for field).
  static const bool enableHeroVideo = bool.fromEnvironment(
    'INCLUDE_HERO_VIDEO',
    defaultValue: false,
  );
}

/// App mark: capital P icon (white on black).
class PasaleLogo extends StatelessWidget {
  const PasaleLogo({
    super.key,
    this.size = 40,
    this.borderRadius,
  });

  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.22);
    return ClipRRect(
      borderRadius: radius,
      child: Image.asset(
        PasaleBrand.logoAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: radius,
          ),
          child: Text(
            'P',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.55,
            ),
          ),
        ),
      ),
    );
  }
}
