import 'package:pasale_register/services/sharing_service.dart';

class FakeSharingService implements SharingService {
  String? _lastSharedReceiptText;
  String? _lastSharedPhoneNumber;
  int _shareCount = 0;
  bool throwError = false;

  String? get lastSharedReceiptText => _lastSharedReceiptText;
  String? get lastSharedPhoneNumber => _lastSharedPhoneNumber;
  int get shareCount => _shareCount;

  @override
  Future<void> shareReceipt(String receiptText, String phoneNumber) async {
    if (throwError) {
      throw Exception('share_failed');
    }
    _lastSharedReceiptText = receiptText;
    _lastSharedPhoneNumber = phoneNumber;
    _shareCount++;
  }
}
