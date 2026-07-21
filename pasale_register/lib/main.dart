import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mlkit_camera/mlkit_camera.dart';
import 'services/update_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'bootstrap.dart';
import 'l10n/locale_controller.dart';
import 'models/user_role.dart';
import 'screens/buyer_shell.dart';
import 'screens/landing_screen.dart';
import 'screens/otp_auth_screen.dart';
import 'screens/store_owner_shell.dart';
import 'screens/store_setup_screen.dart';
import 'screens/training_screen.dart';
import 'screens/vendor_shell.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/service_locator.dart';
import 'services/session_service.dart';
// firestore_service used for healStoreMembership on home entry
import 'theme/pasale_theme.dart';

void main() async {
  final result = await bootstrap();
  await LocaleController.instance.load();
  debugPrint('Pasale bootstrap: ${result.message}');
  runApp(MyApp(bootstrap: result));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.bootstrap});

  final BootstrapResult? bootstrap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        final localeCtrl = LocaleController.instance;
        return MaterialApp(
          title: 'Pasale Register',
          debugShowCheckedModeBanner: false,
          theme: PasaleTheme.light(),
          locale: localeCtrl.locale,
          supportedLocales: const [
            Locale('en'),
            Locale('ne'),
            Locale('bn'),
            Locale('hi'),
            Locale('ur'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: localeCtrl.isRtl
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: AppGate(bootstrap: bootstrap),
        );
      },
    );
  }
}

/// Gates: Landing → OTP → Training → (Store setup) → Role shell.
class AppGate extends StatefulWidget {
  const AppGate({super.key, this.bootstrap});

  final BootstrapResult? bootstrap;

  @override
  State<AppGate> createState() => _AppGateState();
}

enum _GateStep {
  loading,
  landing,
  otp,
  training,
  storeSetup,
  home,
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  final _session = SessionService();

  _GateStep _step = _GateStep.loading;
  AppSession? _sessionData;
  UserRole _pendingRole = UserRole.storeOwner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!locator.isRegistered<FirestoreService>()) {
      setupLocator(useFakes: true);
    }
    // Tests may skip bootstrap — ensure locale loaded.
    if (!LocaleController.instance.isLoaded) {
      LocaleController.instance.load().then((_) {
        if (mounted) setState(() {});
      });
    }
    
    // Check for OTA updates & Remote Config in the background
    if (locator.isRegistered<UpdateService>()) {
      locator<UpdateService>().initializeAndCheckForUpdates();
    }
    
    _refreshSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!locator.isRegistered<MlkitCameraController>()) return;
    final camera = locator<MlkitCameraController>();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      camera.stop();
    }
  }

  Future<void> _refreshSession() async {
    var s = await _session.load();
    if (!mounted) return;

    _GateStep next;
    if (!s.isLoggedIn || s.role == null) {
      next = _GateStep.landing;
      if (s.role != null) _pendingRole = s.role!;
    } else if (s.needsTraining) {
      next = _GateStep.training;
      _pendingRole = s.role!;
    } else if (s.needsStoreSetup) {
      next = _GateStep.storeSetup;
      _pendingRole = s.role!;
    } else {
      next = _GateStep.home;
      _pendingRole = s.role!;
      // Demo OTP used to store demo_phone_* without Firebase Auth — rebind so
      // create-branch and membership writes pass production Firestore rules.
      if (locator.isRegistered<AuthService>()) {
        try {
          await locator<AuthService>().ensureFirestoreAuthAligned();
          s = await _session.load();
        } catch (e) {
          debugPrint('ensureFirestoreAuthAligned: $e');
        }
      }
      if (s.isStoreActivated &&
          s.storeId != null &&
          s.storeId!.isNotEmpty) {
        // Heal legacy stores missing ownerUid/memberUids after rules rollout.
        final uid = s.uid;
        if (uid != null &&
            uid.isNotEmpty &&
            locator.isRegistered<FirestoreService>()) {
          try {
            await locator<FirestoreService>().healStoreMembership(
              storeId: s.storeId!,
              ownerUid: uid,
              businessId: s.businessId,
              ownerPhone: s.phone,
              storeName: s.storeName,
            );
            // Ensure businessId is in session for catalog sync.
            if (s.businessId == null || s.businessId!.isEmpty) {
              final profile =
                  await locator<FirestoreService>().ensureMembershipProfile(
                uid: uid,
                phone: s.phone,
                displayName: s.displayName,
              );
              await _session.setBusinessId(profile.businessId);
              s = await _session.load();
            }
          } catch (e) {
            debugPrint('healStoreMembership: $e');
          }
        }
        try {
          await loadAndApplyCameraScope(s.storeId!);
        } catch (e) {
          debugPrint('Camera scope load: $e');
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _sessionData = s;
      _step = next;
    });
  }

  Future<void> _onRoleSelected(UserRole role) async {
    await _session.selectRole(role);
    setState(() {
      _pendingRole = role;
      _step = _GateStep.otp;
    });
  }

  void _onOtpVerified() => _refreshSession();

  void _onTrainingFinished() => _refreshSession();

  Future<void> _onStoreActivated() async {
    final s = await _session.load();
    if (s.storeId != null && s.storeId!.isNotEmpty) {
      try {
        await loadAndApplyCameraScope(s.storeId!);
      } catch (e) {
        debugPrint('Camera scope load: $e');
      }
    }
    await _refreshSession();
  }

  Future<void> _logout() async {
    try {
      if (locator.isRegistered<AuthService>()) {
        await locator<AuthService>().logout();
      } else {
        await _session.logout();
      }
    } catch (_) {
      await _session.logout();
    }
    await _refreshSession();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (_step) {
      case _GateStep.loading:
        child = const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
        break;
      case _GateStep.landing:
        child = LandingScreen(
          initialRole: _pendingRole,
          onContinue: _onRoleSelected,
        );
        break;
      case _GateStep.otp:
        child = OtpAuthScreen(
          role: _pendingRole,
          onVerified: _onOtpVerified,
          onBack: () => setState(() => _step = _GateStep.landing),
        );
        break;
      case _GateStep.training:
        child = TrainingScreen(
          role: _sessionData?.role ?? _pendingRole,
          onFinished: _onTrainingFinished,
        );
        break;
      case _GateStep.storeSetup:
        child = StoreSetupScreen(onActivated: _onStoreActivated);
        break;
      case _GateStep.home:
        final role = _sessionData?.role ?? _pendingRole;
        switch (role) {
          case UserRole.storeOwner:
            child = StoreOwnerShell(
              onLogout: _logout,
              onReload: _refreshSession,
            );
            break;
          case UserRole.vendor:
            child = VendorShell(
              onLogout: _logout,
              onReload: _refreshSession,
            );
            break;
          case UserRole.buyer:
            child = BuyerShell(
              onLogout: _logout,
              onReload: _refreshSession,
            );
            break;
        }
        break;
    }

    final banner = widget.bootstrap;
    // Never show backend/debug strip in release — reduces info leak surface.
    if (banner == null ||
        _step == _GateStep.loading ||
        !kDebugMode) {
      return child;
    }

    final ready = banner.firebaseReady;
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: Colors.black,
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF3F3F46)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      ready
                          ? Icons.cloud_done_outlined
                          : Icons.camera_alt_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _backendLabel(banner),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  String _backendLabel(BootstrapResult b) {
    return switch (b.backend) {
      ServiceBackend.fakes => 'Fakes',
      ServiceBackend.realCamera => 'Real camera · local catalog',
      ServiceBackend.production => 'Firebase · real camera',
    };
  }
}
