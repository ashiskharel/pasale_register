import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persist a temp camera path into app documents for long-term product photos.
Future<String?> persistProductImage({
  required String sourcePath,
  required String storeId,
  required String barcode,
}) async {
  try {
    final src = File(sourcePath);
    if (!await src.exists()) {
      // Fake paths (e.g. /mock/...) — keep as-is for tests.
      return sourcePath;
    }
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/product_photos/$storeId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final safeBarcode = barcode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final dest = File('${dir.path}/$safeBarcode.jpg');
    await src.copy(dest.path);
    return dest.path;
  } catch (_) {
    return sourcePath;
  }
}
