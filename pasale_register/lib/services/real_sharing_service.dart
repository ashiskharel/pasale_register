import 'package:share_plus/share_plus.dart';
import 'sharing_service.dart';

class RealSharingService implements SharingService {
  @override
  Future<void> shareReceipt(String receiptText, String phoneNumber) async {
    try {
      await Share.share(receiptText);
    } catch (e) {
      throw Exception('share_failed');
    }
  }
}
