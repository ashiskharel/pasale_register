import 'package:flutter/material.dart';
// Video player removed for lightweight app

import '../constants/keys.dart';
import '../l10n/locale_controller.dart';
import '../models/user_role.dart';
import '../theme/pasale_theme.dart';
import '../widgets/language_picker.dart';
import '../widgets/pasale_brand.dart';
import '../widgets/role_toggle_bar.dart';

/// Wireframe landing: role + language selection + brand hero video.
class LandingScreen extends StatefulWidget {
  const LandingScreen({
    super.key,
    required this.onContinue,
    this.initialRole = UserRole.storeOwner,
  });

  final void Function(UserRole role) onContinue;
  final UserRole initialRole;

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  late UserRole _role;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
    LocaleController.instance.addListener(_onLocale);
    _initHeroVideo();
  }

  Future<void> _initHeroVideo() async {
    // Video player removed to keep app lightweight.
    if (mounted) setState(() => _videoReady = false);
  }

  @override
  void dispose() {
    LocaleController.instance.removeListener(_onLocale);
    super.dispose();
  }

  void _onLocale() {
    if (mounted) setState(() {});
  }

  String _roleLabel(UserRole role, String Function(String) t) {
    switch (role) {
      case UserRole.storeOwner:
        return t('roleStoreOwner');
      case UserRole.vendor:
        return t('roleVendor');
      case UserRole.buyer:
        return t('roleBuyer');
    }
  }

  Widget _heroBlock() {
    return Container(
      key: const Key('landingHeroImage'),
      height: 168,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: PasaleTheme.ink, width: 1),
        borderRadius: BorderRadius.circular(PasaleTheme.radiusLg),
        color: PasaleTheme.paper,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Poster always underneath.
          Image.asset(
            PasaleBrand.heroPosterAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Color(0xFFF4F4F5),
              child: Center(
                child: Icon(Icons.storefront_outlined, size: 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = LocaleController.instance.strings;
    final t = s.t;

    return Scaffold(
      key: AppKeys.landingScreen,
      backgroundColor: PasaleTheme.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const PasaleLogo(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t('appName').toUpperCase(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        letterSpacing: 4,
                        fontWeight: FontWeight.w800,
                        color: PasaleTheme.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _heroBlock(),
              const SizedBox(height: 24),
              Text(
                t('tagline'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t('taglineSub'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: PasaleTheme.mute,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                t('iAmA'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              RoleToggleBar(
                selected: _role,
                onChanged: (r) => setState(() => _role = r),
                labelFor: (role) => _roleLabel(role, t),
              ),
              const SizedBox(height: 20),
              LanguagePickerBar(
                selected: LocaleController.instance.language,
                onChanged: (lang) async {
                  await LocaleController.instance.setLanguage(lang);
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 22),
              FilledButton(
                key: AppKeys.continueAsRoleButton,
                onPressed: () => widget.onContinue(_role),
                child: Text(
                  s.tr('continueAs', {'role': _roleLabel(_role, t)}),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t('switchRolesHint'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: PasaleTheme.mute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
