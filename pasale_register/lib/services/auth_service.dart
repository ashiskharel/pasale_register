import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/user_role.dart';
import 'device_context_service.dart';
import 'firestore_service.dart';
import 'service_locator.dart';
import 'session_service.dart';

/// How the last successful sign-in was performed.
enum AuthProviderKind {
  phone,
  facebook,
  demoPhone,
  demoFacebook,
}

/// Phone OTP + Facebook auth via Firebase Auth.
///
/// When Firebase is not initialized (tests / offline), falls back to:
/// - Demo OTP [demoOtpCode]
/// - Demo Facebook (local session, no network)
class AuthService {
  AuthService({
    SessionService? session,
    DeviceContextService? deviceContext,
    FirebaseAuth? firebaseAuth,
    bool forceDemo = false,
  })  : _session = session ?? SessionService(),
        _device = deviceContext ?? DeviceContextService(),
        _firebaseAuth = firebaseAuth,
        _forceDemo = forceDemo;

  final SessionService _session;
  final DeviceContextService _device;
  final FirebaseAuth? _firebaseAuth;
  final bool _forceDemo;

  String? _pendingPhone;
  String? _verificationId;
  int? _resendToken;
  bool _autoVerified = false;
  DeviceCaptureResult? lastCapture;
  AuthProviderKind? lastProvider;

  /// Demo / development OTP when Firebase Phone Auth is unavailable.
  static const demoOtpCode = DeviceContextService.demoOtp;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;

  /// True when we can call real Firebase Auth APIs.
  bool get firebaseAuthAvailable {
    if (_forceDemo) return false;
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// After login: create/update users/{uid} + default business (membership).
  Future<void> _syncMembershipProfile({
    required String? uid,
    String? phone,
    String? displayName,
    String? email,
    String? authProvider,
  }) async {
    if (uid == null || uid.isEmpty) return;
    if (!locator.isRegistered<FirestoreService>()) return;
    try {
      final profile = await locator<FirestoreService>().ensureMembershipProfile(
        uid: uid,
        phone: phone,
        displayName: displayName,
        email: email,
        authProvider: authProvider,
      );
      await _session.setBusinessId(profile.businessId);
      // Restore default store if session has none yet.
      final s = await _session.load();
      if ((s.storeId == null || s.storeId!.isEmpty) &&
          profile.defaultStoreId != null &&
          profile.defaultStoreId!.isNotEmpty) {
        await _session.setActiveStore(
          storeId: profile.defaultStoreId!,
          businessId: profile.businessId,
        );
      }
    } catch (e) {
      debugPrint('ensureMembershipProfile: $e');
    }
  }

  /// Synthetic local-only uids used when Firebase Auth is not available.
  static bool isSyntheticDemoUid(String? uid) {
    if (uid == null || uid.isEmpty) return true;
    return uid.startsWith('demo_phone_') || uid.startsWith('fb_demo_');
  }

  /// Demo OTP / offline path needs a real Firebase Auth session when talking
  /// to production Firestore (rules require `request.auth != null` and
  /// `request.auth.uid` to match ownerUid / memberUids).
  ///
  /// Uses **Anonymous** sign-in when Phone Auth is not configured.
  /// Enable Anonymous under Authentication → Sign-in method.
  Future<String> _firebaseUidForDemoLogin() async {
    if (!firebaseAuthAvailable) {
      throw StateError('Firebase Auth is not available');
    }
    final existing = _auth.currentUser;
    if (existing != null && existing.uid.isNotEmpty) {
      return existing.uid;
    }
    try {
      final cred = await _auth.signInAnonymously();
      final uid = cred.user?.uid;
      if (uid == null || uid.isEmpty) {
        throw ArgumentError(
          'Anonymous sign-in returned no user. '
          'Enable Anonymous in Firebase Console → Authentication → Sign-in method.',
        );
      }
      return uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed' ||
          e.code == 'admin-restricted-operation') {
        throw ArgumentError(
          'Demo OTP needs a Firebase Auth session for multi-branch / Firestore.\n\n'
          'Enable one of:\n'
          '• Authentication → Sign-in method → Anonymous → Enable\n'
          '• Or Phone → Enable (+ SHA fingerprints) and use real/test OTP\n\n'
          'See docs/AUTH_SETUP.md',
        );
      }
      throw ArgumentError(_mapFirebaseAuthError(e));
    }
  }

  /// Align session uid with Firebase Auth after cold start.
  ///
  /// Legacy demo logins stored `demo_phone_*` without signing into Firebase,
  /// so create-branch / catalog writes fail with permission-denied. Re-binds
  /// those sessions to an anonymous (or existing) Auth uid.
  ///
  /// Returns the Auth uid when aligned, or null if not applicable / failed.
  Future<String?> ensureFirestoreAuthAligned() async {
    if (!firebaseAuthAvailable) return null;
    final s = await _session.load();
    if (!s.isLoggedIn) return null;

    try {
      User? user = _auth.currentUser;
      if (user == null) {
        final cred = await _auth.signInAnonymously();
        user = cred.user;
      }
      if (user == null || user.uid.isEmpty) return null;

      final authUid = user.uid;
      final sessionUid = s.uid;
      if (sessionUid == authUid) return authUid;

      // Only rebind synthetic / missing session uids — never steal a real
      // phone/Facebook session onto a different Auth user.
      if (sessionUid != null &&
          sessionUid.isNotEmpty &&
          !isSyntheticDemoUid(sessionUid)) {
        debugPrint(
          'ensureFirestoreAuthAligned: session uid $sessionUid != auth $authUid '
          '(non-demo); leaving session as-is',
        );
        return sessionUid;
      }

      final role = s.role ?? UserRole.vendor;
      await _session.completeLogin(
        role: role,
        phone: s.phone,
        displayName: s.displayName,
        uid: authUid,
        authProvider: s.authProvider ?? AuthProviderKind.demoPhone.name,
        email: s.email,
        photoUrl: s.photoUrl,
      );
      // Drop business id owned by the old synthetic uid so membership recreates.
      await _session.setBusinessId(null);
      await _syncMembershipProfile(
        uid: authUid,
        phone: s.phone,
        displayName: s.displayName,
        email: s.email,
        authProvider: s.authProvider ?? AuthProviderKind.demoPhone.name,
      );
      debugPrint(
        'ensureFirestoreAuthAligned: rebound ${sessionUid ?? "(null)"} → $authUid',
      );
      return authUid;
    } catch (e) {
      debugPrint('ensureFirestoreAuthAligned: $e');
      return null;
    }
  }

  String? get pendingPhone => _pendingPhone;
  String? get verificationId => _verificationId;
  bool get otpAutoVerified => _autoVerified;

  /// Normalize Nepali mobiles to E.164 (`+97798xxxxxxxx`).
  String normalizePhone(String phone) {
    var cleaned = phone.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.isEmpty) {
      throw ArgumentError('Phone number required');
    }
    if (!RegExp(r'^\+?\d{10,15}$').hasMatch(cleaned)) {
      throw ArgumentError('Enter a valid phone number');
    }
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('977') && cleaned.length >= 12) {
      return '+$cleaned';
    }
    // Local 10-digit Nepal mobile
    if (RegExp(r'^9[78]\d{8}$').hasMatch(cleaned)) {
      return '+977$cleaned';
    }
    // Other international without +
    if (cleaned.length > 10) return '+$cleaned';
    return cleaned;
  }

  /// True when Firebase reports Phone Auth is not set up yet.
  /// Console "test numbers" also fail with this — they still need Phone enabled.
  bool _isPhoneConfigError(FirebaseAuthException e) {
    final msg = (e.message ?? '').toLowerCase();
    final code = e.code.toLowerCase();
    return msg.contains('configuration_not_found') ||
        msg.contains('configuration-not-found') ||
        code.contains('configuration') ||
        code == 'operation-not-allowed' ||
        code == 'project-not-found' ||
        msg.contains('operation is not allowed');
  }

  /// Demo OTP is allowed only in debug/profile or when [forceDemo] is set (tests).
  bool get _allowDemoAuth => _forceDemo || kDebugMode;

  OtpSendResult _demoOtpResult({required String reason}) {
    if (!_allowDemoAuth) {
      throw StateError(
        '$reason\n\n'
        'Demo OTP is disabled in release builds. '
        'Enable Phone Auth in Firebase Console or use a debug build.',
      );
    }
    _verificationId = 'demo_${DateTime.now().millisecondsSinceEpoch}';
    _autoVerified = false;
    return OtpSendResult(
      mode: OtpSendMode.demo,
      message:
          '$reason\n\n'
          'Using local demo OTP for now — enter: $demoOtpCode\n'
          '(Firebase console test numbers only work after Phone is Enabled.)',
    );
  }

  /// Request SMS OTP (Firebase) or mark demo OTP ready.
  ///
  /// If Firebase returns CONFIGURATION_NOT_FOUND (Phone not enabled yet),
  /// falls back to demo OTP so you can keep testing the app flow.
  Future<OtpSendResult> sendOtp(String phone) async {
    final e164 = normalizePhone(phone);
    _pendingPhone = e164;
    _autoVerified = false;
    lastCapture = await _device.captureAllSilently();

    if (!firebaseAuthAvailable) {
      return _demoOtpResult(
        reason: 'Firebase Auth is not active in this build.',
      );
    }

    final completer = Completer<OtpSendResult>();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: e164,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final cred = await _auth.signInWithCredential(credential);
            _autoVerified = true;
            _verificationId = credential.verificationId;
            if (!completer.isCompleted) {
              completer.complete(
                OtpSendResult(
                  mode: OtpSendMode.autoVerified,
                  message: 'Phone verified automatically.',
                  user: cred.user,
                ),
              );
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(
                ArgumentError('Auto-verify failed: $e'),
              );
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint(
            'Phone verificationFailed: code=${e.code} message=${e.message}',
          );
          if (completer.isCompleted) return;

          // Phone not enabled / project Auth incomplete — don't block the app.
          // Console test numbers fail the same way until Phone is Enabled.
          if (_isPhoneConfigError(e)) {
            completer.complete(
              _demoOtpResult(
                reason:
                    'Firebase Phone Auth not ready '
                    '(CONFIGURATION_NOT_FOUND / provider off).\n'
                    'Console test numbers also need Phone Enabled first.',
              ),
            );
            return;
          }

          completer.completeError(
            ArgumentError(_mapFirebaseAuthError(e)),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!completer.isCompleted) {
            completer.complete(
              OtpSendResult(
                mode: OtpSendMode.codeSent,
                message: 'OTP sent to $e164 (SMS or Firebase test number).',
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (e) {
      if (_isPhoneConfigError(e)) {
        return _demoOtpResult(
          reason: 'Firebase Phone Auth not ready (${e.code}).',
        );
      }
      throw ArgumentError(_mapFirebaseAuthError(e));
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('configuration_not_found') ||
          s.contains('configuration-not-found')) {
        return _demoOtpResult(
          reason: 'Firebase Phone Auth not ready (CONFIGURATION_NOT_FOUND).',
        );
      }
      rethrow;
    }

    return completer.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => throw ArgumentError(
        'Timed out waiting for OTP. Check network and Firebase Phone Auth setup.',
      ),
    );
  }

  /// Completes phone login after the user enters the SMS code.
  ///
  /// If Android auto-verified during [sendOtp], pass any code and [role] only.
  Future<void> verifyOtp({
    required String otp,
    required UserRole role,
  }) async {
    if (_pendingPhone == null) {
      throw StateError('Request OTP first');
    }
    lastCapture ??= await _device.captureAllSilently();

    // Auto-verify already signed in via Firebase
    if (_autoVerified && firebaseAuthAvailable) {
      final user = _auth.currentUser;
      await _finishPhoneLogin(role: role, user: user);
      return;
    }

    final code = otp.trim();
    if (code.isEmpty) {
      throw ArgumentError('OTP required');
    }

    final isDemoId = _verificationId == null ||
        _verificationId!.startsWith('demo_') ||
        !firebaseAuthAvailable;

    if (isDemoId) {
      if (code != demoOtpCode && code != '000000') {
        throw ArgumentError('Invalid OTP. Demo code: $demoOtpCode');
      }
      lastProvider = AuthProviderKind.demoPhone;
      // When Firebase is up (production backend), sign in anonymously so
      // Firestore rules see request.auth.uid matching membership ownerUid.
      // Without this, create-branch / catalog writes fail with permission-denied.
      final String demoUid;
      if (firebaseAuthAvailable) {
        demoUid = await _firebaseUidForDemoLogin();
      } else {
        demoUid = 'demo_phone_${_pendingPhone}';
      }
      await _session.completeLogin(
        role: role,
        phone: _pendingPhone,
        displayName: null,
        uid: demoUid,
        authProvider: AuthProviderKind.demoPhone.name,
      );
      await _syncMembershipProfile(
        uid: demoUid,
        phone: _pendingPhone,
        authProvider: AuthProviderKind.demoPhone.name,
      );
      return;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      final userCred = await _auth.signInWithCredential(credential);
      await _finishPhoneLogin(role: role, user: userCred.user);
    } on FirebaseAuthException catch (e) {
      throw ArgumentError(_mapFirebaseAuthError(e));
    }
  }

  Future<void> _finishPhoneLogin({
    required UserRole role,
    User? user,
  }) async {
    lastProvider = AuthProviderKind.phone;
    final phone = user?.phoneNumber ?? _pendingPhone;
    await _session.completeLogin(
      role: role,
      phone: phone,
      displayName: user?.displayName,
      uid: user?.uid,
      authProvider: AuthProviderKind.phone.name,
      email: user?.email,
    );
    await _syncMembershipProfile(
      uid: user?.uid,
      phone: phone,
      displayName: user?.displayName,
      email: user?.email,
      authProvider: AuthProviderKind.phone.name,
    );
  }

  /// Facebook Login → Firebase credential (or demo when Firebase is off).
  Future<void> signInWithFacebook({required UserRole role}) async {
    lastCapture = await _device.captureAllSilently();

    if (!firebaseAuthAvailable) {
      if (!_allowDemoAuth) {
        throw StateError(
          'Firebase Auth is required for Facebook sign-in in release builds.',
        );
      }
      lastProvider = AuthProviderKind.demoFacebook;
      final id = const Uuid().v4();
      final demoUid = 'fb_demo_$id';
      await _session.completeLogin(
        role: role,
        phone: null,
        displayName: 'Facebook User',
        uid: demoUid,
        authProvider: AuthProviderKind.demoFacebook.name,
        email: 'demo_$id@facebook.local',
        photoUrl: null,
      );
      await _syncMembershipProfile(
        uid: demoUid,
        displayName: 'Facebook User',
        email: 'demo_$id@facebook.local',
        authProvider: AuthProviderKind.demoFacebook.name,
      );
      return;
    }

    try {
      final result = await FacebookAuth.instance.login(
        permissions: const ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.cancelled) {
        throw ArgumentError('Facebook sign-in cancelled');
      }
      if (result.status != LoginStatus.success || result.accessToken == null) {
        final msg = result.message ?? result.status.name;
        throw ArgumentError('Facebook sign-in failed: $msg');
      }

      final token = result.accessToken!;
      // flutter_facebook_auth 7.x: tokenString on AccessToken
      final accessTokenString = token.tokenString;

      final credential = FacebookAuthProvider.credential(accessTokenString);
      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;

      // Pull profile name/email/photo from Facebook graph (default profile).
      String? name = user?.displayName;
      String? email = user?.email;
      String? photoUrl = user?.photoURL;
      try {
        final data = await FacebookAuth.instance.getUserData(
          fields: 'name,email,picture.width(400)',
        );
        name ??= data['name'] as String?;
        email ??= data['email'] as String?;
        final pic = data['picture'];
        if (pic is Map && pic['data'] is Map) {
          photoUrl ??= (pic['data'] as Map)['url'] as String?;
        }
      } catch (e) {
        debugPrint('Facebook getUserData: $e');
      }

      lastProvider = AuthProviderKind.facebook;
      await _session.completeLogin(
        role: role,
        phone: user?.phoneNumber,
        displayName: name,
        uid: user?.uid,
        authProvider: AuthProviderKind.facebook.name,
        email: email,
        photoUrl: photoUrl,
      );
      await _syncMembershipProfile(
        uid: user?.uid,
        phone: user?.phoneNumber,
        displayName: name,
        email: email,
        authProvider: AuthProviderKind.facebook.name,
      );
    } on FirebaseAuthException catch (e) {
      throw ArgumentError(_mapFirebaseAuthError(e));
    } on ArgumentError {
      rethrow;
    } catch (e) {
      throw ArgumentError('Facebook sign-in error: $e');
    }
  }

  Future<void> logout() async {
    try {
      if (!_forceDemo) {
        await FacebookAuth.instance.logOut();
      }
    } catch (e) {
      debugPrint('Facebook logout: $e');
    }
    try {
      if (firebaseAuthAvailable) {
        await _auth.signOut();
      }
    } catch (e) {
      debugPrint('Firebase signOut: $e');
    }
    await _session.logout();
    _pendingPhone = null;
    _verificationId = null;
    _resendToken = null;
    _autoVerified = false;
    lastProvider = null;
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    final msg = (e.message ?? '').toLowerCase();
    final code = e.code.toLowerCase();

    // CONFIGURATION_NOT_FOUND (status 17499) — Phone Auth not enabled / incomplete
    if (msg.contains('configuration_not_found') ||
        msg.contains('configuration-not-found') ||
        code.contains('configuration')) {
      return 'Firebase Phone Auth is not configured for project pasal-b84c5.\n\n'
          'Fix in Firebase Console:\n'
          '1. Authentication → Get started (if first time)\n'
          '2. Sign-in method → Phone → Enable\n'
          '3. Project settings → Your apps → Android → add SHA-1 & SHA-256\n'
          '4. Re-download google-services.json into android/app/\n'
          '5. Authentication → Settings → SMS region policy (allow Nepal)\n\n'
          'See docs/AUTH_SETUP.md';
    }

    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number. Use country code (e.g. +97798…).';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'invalid-verification-code':
        return 'Invalid OTP code. Check the SMS and try again.';
      case 'session-expired':
        return 'OTP session expired. Request a new code.';
      case 'quota-exceeded':
        return 'SMS quota exceeded for this project.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'operation-not-allowed':
        return 'Phone sign-in is disabled. Enable it in Firebase Console → Authentication → Sign-in method → Phone.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'missing-client-identifier':
      case 'app-not-authorized':
        return 'App not authorized for Phone Auth. Add debug SHA-1/SHA-256 in Firebase Project settings → Your Android app, then re-download google-services.json.';
      default:
        return e.message ?? e.code;
    }
  }
}

enum OtpSendMode { demo, codeSent, autoVerified }

class OtpSendResult {
  const OtpSendResult({
    required this.mode,
    required this.message,
    this.user,
  });

  final OtpSendMode mode;
  final String message;
  final User? user;
}
