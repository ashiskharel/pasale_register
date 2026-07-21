import 'dart:io';

import 'package:flutter/material.dart';

import '../constants/keys.dart';
import '../services/camera_service.dart';
import '../services/scanner_service.dart';
import '../services/service_locator.dart';
import '../theme/pasale_theme.dart';

/// Live camera preview + shutter for product registration (catalog photo).
///
/// Shows the live feed in the placeholder area; capture freezes a still.
/// Retake returns to live preview.
class ProductPhotoCapture extends StatefulWidget {
  const ProductPhotoCapture({
    super.key,
    required this.photoPath,
    required this.onPhotoChanged,
    this.onProductNameParsed,
  });

  final String? photoPath;
  final ValueChanged<String?> onPhotoChanged;
  final ValueChanged<String>? onProductNameParsed;

  @override
  State<ProductPhotoCapture> createState() => _ProductPhotoCaptureState();
}

class _ProductPhotoCaptureState extends State<ProductPhotoCapture> {
  bool _preparing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() {
      _preparing = true;
      _error = null;
    });
    try {
      // Free the shared camera from continuous scan/OCR stream.
      try {
        await locator<ScannerService>().stopScanning();
      } catch (_) {}
      await locator<CameraService>().prepareProductPhotoSession();
      // Brief yield so CameraController notifies ready.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      _error = 'Camera unavailable: $e';
    }
    if (mounted) {
      setState(() => _preparing = false);
    }
  }

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      final path = await locator<CameraService>().captureProductPhoto();
      if (path != null && path.isNotEmpty) {
        widget.onPhotoChanged(path);
      } else {
        setState(() {
          _error = 'Could not capture photo. Try again.';
        });
        await _prepare();
      }
    } catch (e) {
      setState(() => _error = 'Photo failed: $e');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _retake() async {
    widget.onPhotoChanged(null);
    await _prepare();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = widget.photoPath;
    final hasFile = path != null && path.isNotEmpty && File(path).existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PasaleTheme.radiusMd),
            child: Container(
              key: AppKeys.registerProductPhotoPreview,
              width: double.infinity,
              height: 200,
              color: Colors.black,
              child: hasFile
                  ? Image.file(File(path), fit: BoxFit.cover)
                  : _buildLiveOrPlaceholder(scheme),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: scheme.error, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 10),
        if (hasFile)
          OutlinedButton.icon(
            key: AppKeys.registerProductPhotoButton,
            onPressed: _capturing ? null : _retake,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retake photo'),
          )
        else
          FilledButton.icon(
            key: AppKeys.registerProductPhotoButton,
            onPressed: (_preparing || _capturing) ? null : _capture,
            icon: _capturing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera_alt_rounded),
            label: Text(_capturing ? 'Capturing…' : 'Capture photo'),
          ),
      ],
    );
  }

  Widget _buildLiveOrPlaceholder(ColorScheme scheme) {
    if (_preparing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white70),
            SizedBox(height: 10),
            Text(
              'Starting camera…',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final preview = locator<CameraService>().buildProductPhotoPreview();
    if (preview != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          preview,
          // Soft framing guide
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: StreamBuilder<String>(
              stream: locator<CameraService>().productNameStream,
              builder: (context, snapshot) {
                final text = snapshot.data ?? '';
                if (text.isNotEmpty && widget.onProductNameParsed != null) {
                  return Center(
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onProductNameParsed!(text),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: Flexible(
                        child: Text(
                          'Use: $text',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary.withValues(alpha: 0.9),
                        foregroundColor: scheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  );
                }
                return const Text(
                  'Frame the product, then Capture',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_rounded, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Camera preview unavailable',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: _prepare,
            child: const Text('Retry camera'),
          ),
        ],
      ),
    );
  }
}
