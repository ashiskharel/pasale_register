import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pasale_register/models/store.dart';
import 'package:pasale_register/models/device.dart';
import 'package:pasale_register/services/service_locator.dart';
import 'package:pasale_register/services/session_service.dart';
import 'package:pasale_register/constants/keys.dart';
import 'package:pasale_register/main.dart';
import 'package:pasale_register/models/user_role.dart';

void main() {
  setUp(() {
    setupLocator(useFakes: true);
  });

  group('Store and Device Models Tests', () {
    test('Store serialization & deserialization', () {
      final now = DateTime.now();
      final store = Store(
        storeId: 'store_123',
        name: 'Super Pasale',
        activationDate: now,
      );

      final map = store.toMap();
      expect(map['storeId'], 'store_123');
      expect(map['name'], 'Super Pasale');
      expect(map['activationDate'], now.toIso8601String());

      final deserialized = Store.fromMap(map, 'store_123');
      expect(deserialized.storeId, 'store_123');
      expect(deserialized.name, 'Super Pasale');
      expect(
        deserialized.activationDate.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
    });

    test('Device serialization & deserialization', () {
      final now = DateTime.now();
      final device = Device(
        deviceId: 'device_abc',
        model: 'Pixel 6',
        osVersion: 'Android 13',
        lastActive: now,
      );

      final map = device.toMap();
      expect(map['deviceId'], 'device_abc');
      expect(map['model'], 'Pixel 6');
      expect(map['osVersion'], 'Android 13');
      expect(map['lastActive'], now.toIso8601String());

      final deserialized = Device.fromMap(map, 'device_abc');
      expect(deserialized.deviceId, 'device_abc');
      expect(deserialized.model, 'Pixel 6');
      expect(deserialized.osVersion, 'Android 13');
      expect(
        deserialized.lastActive.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
    });
  });

  group('App gate flow', () {
    testWidgets('Cold start shows Landing with role toggle', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.landingScreen), findsOneWidget);
      expect(find.byKey(AppKeys.roleToggleBar), findsOneWidget);
      expect(find.text('Continue as Store Owner'), findsOneWidget);
    });

    testWidgets('Logged-in store owner with store open shows shell/scanner',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        SessionKeys.isLoggedIn: true,
        SessionKeys.role: UserRole.storeOwner.name,
        SessionKeys.phone: '9801112233',
        SessionKeys.trainingDone: true,
        SessionKeys.storeId: 'store_ok',
        SessionKeys.storeName: 'OK Shop',
        SessionKeys.deviceId: 'device_ok',
        SessionKeys.isActivated: true,
      });

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.storeOwnerShell), findsOneWidget);
      expect(find.byKey(AppKeys.profileMenuButton), findsOneWidget);
      // Scanner / checkout idle UI
      expect(find.byKey(AppKeys.scanBarcodeButton), findsOneWidget);
    });

    testWidgets('OTP + store setup activation flow', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const MyApp());
      await tester.pump(); // loading → landing
      await tester.pump(const Duration(milliseconds: 100));

      // Landing → continue as store owner (scroll if hero video tall)
      final continueBtn = find.byKey(AppKeys.continueAsRoleButton);
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(AppKeys.otpAuthScreen), findsOneWidget);

      // Facebook button is present on auth screen
      expect(find.byKey(AppKeys.facebookSignInButton), findsOneWidget);

      await tester.enterText(find.byKey(AppKeys.phoneInput), '9801234567');
      await tester.tap(find.byKey(AppKeys.sendOtpButton));
      // Avoid pumpAndSettle — progress / async frames
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(AppKeys.otpInput), findsOneWidget);
      await tester.enterText(find.byKey(AppKeys.otpInput), '123456');
      await tester.tap(find.byKey(AppKeys.verifyOtpButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Training consent
      expect(find.byKey(AppKeys.trainingScreen), findsOneWidget);
      await tester.tap(find.byKey(AppKeys.trainingConsentCheckbox));
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.skipTrainingButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Store setup
      expect(find.byKey(AppKeys.storeIdInput), findsOneWidget);
      await tester.enterText(find.byKey(AppKeys.storeIdInput), 'mystore123');
      await tester.enterText(
        find.byKey(AppKeys.storeNameInput),
        'My Awesome Store',
      );
      await tester.tap(find.byKey(AppKeys.activateStoreButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SessionKeys.storeId), 'mystore123');
      expect(prefs.getBool(SessionKeys.isActivated), true);
      expect(prefs.getBool(SessionKeys.isLoggedIn), true);

      expect(find.byKey(AppKeys.storeOwnerShell), findsOneWidget);
      // AnimatedSwitcher may briefly keep outgoing page; accept ≥1.
      expect(find.byKey(AppKeys.scanBarcodeButton), findsWidgets);
    });

    testWidgets('Vendor role reaches vendor shell after training',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        SessionKeys.isLoggedIn: true,
        SessionKeys.role: UserRole.vendor.name,
        SessionKeys.phone: '9801112233',
        SessionKeys.trainingDone: true,
      });

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.vendorShell), findsOneWidget);
    });

    testWidgets('Facebook demo sign-in reaches training', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const MyApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final continueBtn = find.byKey(AppKeys.continueAsRoleButton);
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(AppKeys.facebookSignInButton), findsOneWidget);
      await tester.tap(find.byKey(AppKeys.facebookSignInButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(AppKeys.trainingScreen), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SessionKeys.isLoggedIn), true);
      expect(prefs.getString(SessionKeys.authProvider), 'demoFacebook');
    });
  });
}
