import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/keys.dart';
import '../l10n/locale_controller.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/service_locator.dart';
import '../theme/pasale_theme.dart';
import '../widgets/pasale_brand.dart';
import '../widgets/pasale_ui.dart';

/// Sign-in: Phone OTP + Facebook — modern card layout.
class OtpAuthScreen extends StatefulWidget {
  const OtpAuthScreen({
    super.key,
    required this.role,
    required this.onVerified,
    this.onBack,
    AuthService? authService,
  }) : _authService = authService;

  final UserRole role;
  final VoidCallback onVerified;
  final VoidCallback? onBack;
  final AuthService? _authService;

  @override
  State<OtpAuthScreen> createState() => _OtpAuthScreenState();
}

class _OtpAuthScreenState extends State<OtpAuthScreen> {
  late final AuthService _auth;
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _otpSent = false;
  bool _busy = false;
  String _status = '';
  bool _demoMode = true;

  @override
  void initState() {
    super.initState();
    LocaleController.instance.addListener(_onLocale);
    if (widget._authService != null) {
      _auth = widget._authService!;
    } else if (locator.isRegistered<AuthService>()) {
      _auth = locator<AuthService>();
    } else {
      _auth = AuthService();
    }
    _demoMode = !_auth.firebaseAuthAvailable;
  }

  @override
  void dispose() {
    LocaleController.instance.removeListener(_onLocale);
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _onLocale() {
    if (mounted) setState(() {});
  }

  bool get _statusIsError {
    final s = _status.toLowerCase();
    return s.contains('invalid') ||
        s.contains('error') ||
        s.contains('failed') ||
        s.contains('required') ||
        s.contains('cancelled') ||
        s.contains('timed out');
  }

  String _errorText(Object e) {
    if (e is ArgumentError) return e.message?.toString() ?? e.toString();
    if (e is StateError) return e.message;
    return 'Error: $e';
  }

  Future<void> _sendOtp() async {
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      final result = await _auth.sendOtp(_phoneController.text);
      if (!mounted) return;

      if (result.mode == OtpSendMode.autoVerified) {
        await _auth.verifyOtp(otp: '', role: widget.role);
        if (!mounted) return;
        setState(() => _busy = false);
        widget.onVerified();
        return;
      }

      setState(() {
        _otpSent = true;
        _status = result.message;
        _demoMode = result.mode == OtpSendMode.demo;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _errorText(e);
        _busy = false;
      });
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      await _auth.verifyOtp(otp: _otpController.text, role: widget.role);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onVerified();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _errorText(e);
        _busy = false;
      });
    }
  }

  Future<void> _facebook() async {
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      await _auth.signInWithFacebook(role: widget.role);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onVerified();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _errorText(e);
        _busy = false;
      });
    }
  }

  String _roleLabel(String Function(String) t) {
    switch (widget.role) {
      case UserRole.storeOwner:
        return t('roleStoreOwner');
      case UserRole.vendor:
        return t('roleVendor');
      case UserRole.buyer:
        return t('roleBuyer');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = LocaleController.instance.strings.t;

    return Scaffold(
      key: AppKeys.otpAuthScreen,
      appBar: AppBar(
        title: Row(
          children: [
            const PasaleLogo(size: 28),
            const SizedBox(width: 10),
            Text(t('signIn')),
          ],
        ),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _busy ? null : widget.onBack,
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _roleLabel(t),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t('welcomeBack'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _demoMode ? t('demoOtpHint') : t('signInHint'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              PasaleSurface(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Facebook
                    OutlinedButton(
                      key: AppKeys.facebookSignInButton,
                      onPressed: _busy ? null : _facebook,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1877F2),
                        side: const BorderSide(
                          color: Color(0xFF1877F2),
                          width: 1.4,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(PasaleTheme.radiusMd),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.facebook, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            _busy ? t('pleaseWait') : t('continueFacebook'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: scheme.outlineVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            t('orPhone'),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: scheme.outlineVariant)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      key: AppKeys.phoneInput,
                      controller: _phoneController,
                      enabled: !_otpSent && !_busy,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                        LengthLimitingTextInputFormatter(15),
                      ],
                      decoration: InputDecoration(
                        labelText: t('mobileNumber'),
                        hintText: t('phoneHint'),
                        prefixIcon: const Icon(Icons.phone_android_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (!_otpSent)
                      FilledButton(
                        key: AppKeys.sendOtpButton,
                        onPressed: _busy ? null : _sendOtp,
                        child: Text(_busy ? t('sending') : t('sendOtp')),
                      ),
                    if (_otpSent) ...[
                      TextField(
                        key: AppKeys.otpInput,
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          labelText: t('enterOtp'),
                          hintText: _demoMode
                              ? 'Demo: ${AuthService.demoOtpCode}'
                              : t('sixDigitCode'),
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                        ),
                        onSubmitted: (_) => _verify(),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        key: AppKeys.verifyOtpButton,
                        onPressed: _busy ? null : _verify,
                        child: Text(
                          _busy ? t('verifying') : t('verifyContinue'),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() {
                                  _otpSent = false;
                                  _otpController.clear();
                                  _status = '';
                                });
                              },
                        child: Text(t('changeNumber')),
                      ),
                    ],
                    if (_status.isNotEmpty)
                      PasaleStatusBanner(
                        key: AppKeys.statusText,
                        message: _status,
                        isError: _statusIsError,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
