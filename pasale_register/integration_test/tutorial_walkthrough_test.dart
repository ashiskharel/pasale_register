import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pasale_register/constants/keys.dart';
import 'package:pasale_register/l10n/locale_controller.dart';
import 'package:pasale_register/main.dart';
import 'package:pasale_register/services/service_locator.dart';
import 'package:pasale_register/services/session_service.dart';

/// Timed UI walkthrough for the <30s Nepali tutorial screen recording.
///
/// Uses [setupLocator] fakes — does **not** hit dev/prod Firestore.
/// For a live prod-DB demo: `flutter run --dart-define=ENV=Prod`
///
/// Run (with adb screenrecord in parallel):
///   flutter test integration_test/tutorial_walkthrough_test.dart -d <deviceId>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Pasale tutorial walkthrough (scan → product → invoice → checkout → batch)',
      (tester) async {
    await _seedDemoSession();
    setupLocator(useFakes: true);
    await LocaleController.instance.load();

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Hold first frame for screenrecord lock-on.
    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.pump();

    // ---- Scan / add barcode to cart ----
    expect(find.byKey(AppKeys.storeOwnerShell), findsOneWidget);

    await tester.enterText(
      find.byKey(AppKeys.productSearchInput),
      '9772785855724',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(AppKeys.addProductButton));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump();

    // ---- Catalog → add product ----
    await tester.tap(find.byKey(AppKeys.navToCatalog));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await tester.pump();

    await tester.tap(find.byKey(AppKeys.addProductButton));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.enterText(
      find.byKey(AppKeys.registerProductNameInput),
      'डेमो बिस्कुट',
    );
    await tester.enterText(
      find.byKey(AppKeys.registerProductBarcodeInput),
      '8800000000001',
    );
    await tester.enterText(
      find.byKey(AppKeys.registerProductPriceInput),
      '50',
    );
    await _dismissKeyboard(tester);
    await tester.tap(find.byKey(AppKeys.registerProductSaveButton));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump();

    // ---- Manual invoice ----
    await _openMenuAction(tester, 'createManualInvoice');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.enterText(
      find.byKey(AppKeys.manualInvoiceTotalInput),
      '1500',
    );
    // Total, name, phone, email, notes — name is second TextFormField.
    final formFields = find.byType(TextFormField);
    expect(formFields, findsAtLeastNWidgets(3));
    await tester.enterText(formFields.at(1), 'राम शर्मा');
    await tester.enterText(
      find.byKey(AppKeys.manualInvoicePhoneInput),
      '9841234567',
    );
    await _dismissKeyboard(tester);
    await tester.dragUntilVisible(
      find.byKey(AppKeys.manualInvoiceSendButton),
      find.byKey(AppKeys.manualInvoiceScreen),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(AppKeys.manualInvoiceSendButton),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump();

    // ---- Checkout / mark paid ----
    await tester.tap(find.byKey(AppKeys.navToScanner));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Re-add cart item if empty (checkout may have cleared earlier state).
    if (find.textContaining('Cart is empty').evaluate().isNotEmpty ||
        find.byKey(AppKeys.checkoutButton).evaluate().isEmpty) {
      await tester.enterText(
        find.byKey(AppKeys.productSearchInput),
        '9772785855724',
      );
      await tester.tap(find.byKey(AppKeys.addProductButton));
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    await tester.enterText(
      find.byKey(AppKeys.customerPhoneInput),
      '9841234567',
    );
    await _dismissKeyboard(tester);
    await tester.tap(find.byKey(AppKeys.checkoutButton));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    if (find.byKey(AppKeys.markPaidButton).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(AppKeys.markPaidButton));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump();

    // ---- Batch checkout coming soon (premium camera tools) ----
    await _openMenuAction(tester, 'cameraOptions');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    // Hold on premium camera / batch checkout messaging
    await Future<void>.delayed(const Duration(seconds: 4));
    await tester.pump();
    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.pump();
  });
}

Future<void> _dismissKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle(const Duration(milliseconds: 400));
  // Extra: tap app bar area if keyboard still open
  // Tap near top-left chrome to drop software keyboard if still open.
  await tester.tapAt(const Offset(24, 48));
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
}

Future<void> _openMenuAction(WidgetTester tester, String actionName) async {
  await tester.tap(find.byKey(AppKeys.profileMenuButton));
  await tester.pumpAndSettle(const Duration(seconds: 1));

  final item = find.byKey(AppKeys.menuAction(actionName));
  // Bottom sheet list may need scrolling for lower items.
  final scrollable = find.byType(Scrollable).last;
  for (var i = 0; i < 12; i++) {
    if (item.evaluate().isNotEmpty) {
      try {
        await tester.ensureVisible(item);
        break;
      } catch (_) {}
    }
    if (scrollable.evaluate().isEmpty) break;
    await tester.drag(scrollable, const Offset(0, -120));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
  }
  expect(item, findsOneWidget, reason: 'menu action $actionName not found');
  await tester.tap(item);
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

Future<void> _seedDemoSession() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await prefs.setString('appLanguageCode', 'ne');
  await prefs.setBool(SessionKeys.isLoggedIn, true);
  await prefs.setString(SessionKeys.role, 'storeOwner');
  await prefs.setString(SessionKeys.phone, '9800000000');
  await prefs.setString(SessionKeys.displayName, 'Demo Pasale');
  await prefs.setString(SessionKeys.authUid, 'demo_phone_9800000000');
  await prefs.setString(SessionKeys.authProvider, 'phone');
  await prefs.setBool(SessionKeys.trainingDone, true);
  await prefs.setString(SessionKeys.storeId, 'demo_store_1');
  await prefs.setString(SessionKeys.storeName, 'डेमो पसल');
  await prefs.setString(SessionKeys.businessId, 'demo_biz_1');
  await prefs.setString(SessionKeys.deviceId, 'demo_device_1');
  await prefs.setBool(SessionKeys.isActivated, true);
}
