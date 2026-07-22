import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_role.dart';

/// Keys for persistent session state (always-on login until explicit logout).
class SessionKeys {
  static const role = 'userRole';
  static const phone = 'userPhone';
  static const isLoggedIn = 'isLoggedIn';
  static const trainingDone = 'trainingConsentDone';
  static const trainingConsentAt = 'trainingConsentAt';
  static const displayName = 'displayName';
  static const authProvider = 'authProvider';
  static const authUid = 'authUid';
  static const email = 'userEmail';
  static const premiumCamera = 'premiumCameraActive';
  static const premiumAccounting = 'premiumAccountingActive';
  static const premiumInvoices = 'premiumInvoicesActive';
  static const notificationsEnabled = 'notificationsEnabled';

  static const photoUrl = 'profilePhotoUrl';
  static const signupAt = 'signupAt';
  static const panPath = 'panDocumentPath';
  static const panUploadedAt = 'panUploadedAt';
  static const extraPhones = 'extraPhoneNumbers'; // JSON list

  static const storeId = 'storeId';
  static const storeName = 'storeName';
  static const businessId = 'businessId';
  static const deviceId = 'deviceId';
  static const isActivated = 'isActivated';
  static const deviceMetadata = 'deviceMetadata';
  static const lastLocation = 'lastLocation';
}

/// Snapshot of the current user session.
class AppSession {
  const AppSession({
    required this.isLoggedIn,
    this.role,
    this.phone,
    this.displayName,
    this.email,
    this.authProvider,
    this.uid,
    this.trainingDone = false,
    this.storeId,
    this.storeName,
    this.businessId,
    this.deviceId,
    this.isStoreActivated = false,
    this.premiumCamera = false,
    this.premiumAccounting = false,
    this.premiumInvoices = false,
    this.notificationsEnabled = true,
    this.photoUrl,
    this.signupAt,
    this.panPath,
    this.panUploadedAt,
    this.extraPhones = const [],
  });

  final bool isLoggedIn;
  final UserRole? role;
  final String? phone;
  final String? displayName;
  final String? email;
  final String? authProvider;
  final String? uid;
  final bool trainingDone;
  final String? storeId;
  final String? storeName;
  final String? businessId;
  final String? deviceId;
  final bool isStoreActivated;
  final bool premiumCamera;
  final bool premiumAccounting;
  final bool premiumInvoices;
  final bool notificationsEnabled;
  final String? photoUrl;
  final DateTime? signupAt;
  final String? panPath;
  final DateTime? panUploadedAt;
  final List<String> extraPhones;

  bool get needsTraining => isLoggedIn && !trainingDone;

  bool get needsStoreSetup =>
      isLoggedIn &&
      trainingDone &&
      role == UserRole.storeOwner &&
      !isStoreActivated;

  bool get isBusinessRole =>
      role == UserRole.storeOwner || role == UserRole.vendor;

  bool get panUploaded => panPath != null && panPath!.isNotEmpty;

  /// Days left to upload PAN (14 from signup). Null if not business / no signup.
  int? get panDaysRemaining {
    if (!isBusinessRole || signupAt == null) return null;
    if (panUploaded) return null;
    final deadline = signupAt!.add(const Duration(days: 14));
    final left = deadline.difference(DateTime.now()).inDays;
    return left < 0 ? 0 : left;
  }

  bool get panOverdue {
    final d = panDaysRemaining;
    return isBusinessRole && !panUploaded && d != null && d <= 0;
  }
}

/// Loads / persists login, role, training, profile, and premium flags.
class SessionService {
  Future<AppSession> load() async {
    final prefs = await SharedPreferences.getInstance();
    final role = UserRoleX.fromStorage(prefs.getString(SessionKeys.role));
    final storeId = prefs.getString(SessionKeys.storeId);
    final deviceId = prefs.getString(SessionKeys.deviceId);
    final isActivated = prefs.getBool(SessionKeys.isActivated) ?? false;

    List<String> extras = [];
    final rawExtras = prefs.getString(SessionKeys.extraPhones);
    if (rawExtras != null && rawExtras.isNotEmpty) {
      try {
        extras = (jsonDecode(rawExtras) as List).map((e) => '$e').toList();
      } catch (_) {}
    }

    DateTime? signup;
    final signupRaw = prefs.getString(SessionKeys.signupAt);
    if (signupRaw != null) signup = DateTime.tryParse(signupRaw);

    DateTime? panAt;
    final panAtRaw = prefs.getString(SessionKeys.panUploadedAt);
    if (panAtRaw != null) panAt = DateTime.tryParse(panAtRaw);

    return AppSession(
      isLoggedIn: prefs.getBool(SessionKeys.isLoggedIn) ?? false,
      role: role,
      phone: prefs.getString(SessionKeys.phone),
      displayName: prefs.getString(SessionKeys.displayName),
      email: prefs.getString(SessionKeys.email),
      authProvider: prefs.getString(SessionKeys.authProvider),
      uid: prefs.getString(SessionKeys.authUid),
      trainingDone: prefs.getBool(SessionKeys.trainingDone) ?? false,
      storeId: storeId,
      storeName: prefs.getString(SessionKeys.storeName),
      businessId: prefs.getString(SessionKeys.businessId),
      deviceId: deviceId,
      isStoreActivated: isActivated &&
          storeId != null &&
          storeId.isNotEmpty &&
          deviceId != null &&
          deviceId.isNotEmpty,
      premiumCamera: prefs.getBool(SessionKeys.premiumCamera) ?? false,
      premiumAccounting: prefs.getBool(SessionKeys.premiumAccounting) ?? false,
      premiumInvoices: prefs.getBool(SessionKeys.premiumInvoices) ?? false,
      notificationsEnabled:
          prefs.getBool(SessionKeys.notificationsEnabled) ?? true,
      photoUrl: prefs.getString(SessionKeys.photoUrl),
      signupAt: signup,
      panPath: prefs.getString(SessionKeys.panPath),
      panUploadedAt: panAt,
      extraPhones: extras,
    );
  }

  Future<void> selectRole(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SessionKeys.role, role.storageValue);
  }

  Future<void> completeLogin({
    required UserRole role,
    String? phone,
    String? displayName,
    String? uid,
    String? authProvider,
    String? email,
    String? photoUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SessionKeys.isLoggedIn, true);
    await prefs.setString(SessionKeys.role, role.storageValue);
    if (phone != null && phone.isNotEmpty) {
      await prefs.setString(SessionKeys.phone, phone);
    } else {
      await prefs.remove(SessionKeys.phone);
    }
    if (displayName != null && displayName.isNotEmpty) {
      await prefs.setString(SessionKeys.displayName, displayName);
    }
    if (uid != null && uid.isNotEmpty) {
      await prefs.setString(SessionKeys.authUid, uid);
    }
    if (authProvider != null && authProvider.isNotEmpty) {
      await prefs.setString(SessionKeys.authProvider, authProvider);
    }
    if (email != null && email.isNotEmpty) {
      await prefs.setString(SessionKeys.email, email);
    }
    if (photoUrl != null && photoUrl.isNotEmpty) {
      await prefs.setString(SessionKeys.photoUrl, photoUrl);
    }
    // First signup timestamp (PAN 14-day clock) — do not reset on re-login.
    if (prefs.getString(SessionKeys.signupAt) == null) {
      await prefs.setString(
        SessionKeys.signupAt,
        DateTime.now().toUtc().toIso8601String(),
      );
    }
  }

  Future<void> markTrainingConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SessionKeys.trainingDone, true);
    await prefs.setString(
      SessionKeys.trainingConsentAt,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> setPremium({
    bool? camera,
    bool? accounting,
    bool? invoices,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (camera != null) {
      await prefs.setBool(SessionKeys.premiumCamera, camera);
    }
    if (accounting != null) {
      await prefs.setBool(SessionKeys.premiumAccounting, accounting);
    }
    if (invoices != null) {
      await prefs.setBool(SessionKeys.premiumInvoices, invoices);
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SessionKeys.notificationsEnabled, enabled);
  }

  Future<void> setDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SessionKeys.displayName, name);
  }

  Future<void> setBusinessId(String? businessId) async {
    final prefs = await SharedPreferences.getInstance();
    if (businessId == null || businessId.isEmpty) {
      await prefs.remove(SessionKeys.businessId);
    } else {
      await prefs.setString(SessionKeys.businessId, businessId);
    }
  }

  Future<void> setActiveStore({
    required String storeId,
    String? storeName,
    String? businessId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SessionKeys.storeId, storeId);
    if (storeName != null && storeName.isNotEmpty) {
      await prefs.setString(SessionKeys.storeName, storeName);
    }
    if (businessId != null && businessId.isNotEmpty) {
      await prefs.setString(SessionKeys.businessId, businessId);
    }
  }

  Future<void> markStoreActivated({
    required String deviceId,
    Map<String, dynamic>? metadata,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SessionKeys.isActivated, true);
    await prefs.setString(SessionKeys.deviceId, deviceId);
    if (metadata != null) {
      await prefs.setString(SessionKeys.deviceMetadata, jsonEncode(metadata));
    }
  }

  Future<void> setPhotoUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.isEmpty) {
      await prefs.remove(SessionKeys.photoUrl);
    } else {
      await prefs.setString(SessionKeys.photoUrl, url);
    }
  }

  Future<void> setPrimaryPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SessionKeys.phone, phone);
  }

  Future<void> setExtraPhones(List<String> phones) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SessionKeys.extraPhones, jsonEncode(phones));
  }

  Future<void> setPanDocumentPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SessionKeys.panPath, path);
    await prefs.setString(
      SessionKeys.panUploadedAt,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SessionKeys.isLoggedIn, false);
    await prefs.remove(SessionKeys.phone);
    await prefs.remove(SessionKeys.email);
    await prefs.remove(SessionKeys.authUid);
    await prefs.remove(SessionKeys.authProvider);
    await prefs.remove(SessionKeys.displayName);
    await prefs.remove(SessionKeys.trainingDone);
    await prefs.remove(SessionKeys.trainingConsentAt);
    await prefs.remove(SessionKeys.storeId);
    await prefs.remove(SessionKeys.businessId);
    await prefs.remove(SessionKeys.storeName);
    await prefs.remove(SessionKeys.deviceId);
    await prefs.remove(SessionKeys.isActivated);
    // Keep signupAt / pan / photo for compliance continuity on re-login of same device
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
