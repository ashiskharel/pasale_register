import 'package:flutter_test/flutter_test.dart';
import 'package:pasale_register/models/user_role.dart';
import 'package:pasale_register/services/auth_service.dart';
import 'package:pasale_register/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthService auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = AuthService(forceDemo: true);
  });

  group('Phone normalize', () {
    test('adds +977 for local Nepal mobile', () {
      expect(auth.normalizePhone('9801234567'), '+9779801234567');
      expect(auth.normalizePhone('9701234567'), '+9779701234567');
    });

    test('keeps E.164', () {
      expect(auth.normalizePhone('+9779801234567'), '+9779801234567');
    });

    test('rejects empty', () {
      expect(() => auth.normalizePhone(''), throwsArgumentError);
    });
  });

  group('Demo OTP', () {
    test('sendOtp then verify with demo code logs in', () async {
      final send = await auth.sendOtp('9801234567');
      expect(send.mode, OtpSendMode.demo);

      await auth.verifyOtp(otp: AuthService.demoOtpCode, role: UserRole.vendor);

      final session = await SessionService().load();
      expect(session.isLoggedIn, isTrue);
      expect(session.role, UserRole.vendor);
      expect(session.phone, '+9779801234567');
      expect(session.authProvider, 'demoPhone');
    });

    test('wrong OTP fails', () async {
      await auth.sendOtp('9801234567');
      expect(
        () => auth.verifyOtp(otp: '999999', role: UserRole.buyer),
        throwsArgumentError,
      );
    });
  });

  group('Demo Facebook', () {
    test('creates session without phone', () async {
      await auth.signInWithFacebook(role: UserRole.storeOwner);
      final session = await SessionService().load();
      expect(session.isLoggedIn, isTrue);
      expect(session.role, UserRole.storeOwner);
      expect(session.authProvider, 'demoFacebook');
      expect(session.displayName, 'Facebook User');
      expect(session.uid, isNotNull);
    });
  });

  group('Logout', () {
    test('clears session', () async {
      await auth.signInWithFacebook(role: UserRole.buyer);
      await auth.logout();
      final session = await SessionService().load();
      expect(session.isLoggedIn, isFalse);
    });
  });
}
