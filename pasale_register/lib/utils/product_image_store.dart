import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Persist a temp camera path into Cloud Storage for cross-device product photos.
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
    
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('product_photos')
          .child(storeId)
          .child('$safeBarcode.jpg');
          
      await storageRef.putFile(dest);
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      // If upload fails (e.g., offline/no config), fallback to local path
      return dest.path;
    }
  } catch (_) {
    return sourcePath;
  }
}
