import 'package:flutter/material.dart';

import '../constants/keys.dart';
import '../l10n/locale_controller.dart';
import '../services/service_locator.dart';
import '../widgets/help_chat_button.dart';
import '../widgets/idle_activity_scope.dart';
import '../widgets/profile_menu_button.dart';
import 'premium_features_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'vendor_invoices_screen.dart';
import 'vendor_stores_screen.dart';

enum _VendorPage { stores, invoices, premium, profile, settings }

class VendorShell extends StatefulWidget {
  const VendorShell({
    super.key,
    required this.onLogout,
    this.onReload,
  });

  final VoidCallback onLogout;
  final VoidCallback? onReload;

  @override
  State<VendorShell> createState() => _VendorShellState();
}

class _VendorShellState extends State<VendorShell> {
  _VendorPage _page = _VendorPage.stores;
  PremiumFeature? _premiumFocus;
  bool _idleFlashing = false;

  @override
  void initState() {
    super.initState();
    LocaleController.instance.addListener(_onLocale);
  }

  @override
  void dispose() {
    LocaleController.instance.removeListener(_onLocale);
    super.dispose();
  }

  void _onLocale() {
    if (mounted) setState(() {});
  }

  List<ProfileMenuItem> get _menuItems {
    final t = LocaleController.instance.strings.t;
    return [
      ProfileMenuItem(
        action: ProfileMenuAction.chat,
        label: t('chat'),
        icon: Icons.chat_outlined,
      ),
      ProfileMenuItem(
        action: ProfileMenuAction.callStores,
        label: t('callStores'),
        icon: Icons.call_outlined,
      ),
      ProfileMenuItem(
        action: ProfileMenuAction.premiumInvoices,
        label: t('sendInvoices'),
        icon: Icons.send_outlined,
        premium: true,
      ),
      ProfileMenuItem(
        action: ProfileMenuAction.premiumCamera,
        label: t('cameraInventory'),
        icon: Icons.camera_enhance_outlined,
        premium: true,
      ),
      ProfileMenuItem(
        action: ProfileMenuAction.premiumAccounting,
        label: t('accounting'),
        icon: Icons.account_balance_outlined,
        premium: true,
      ),
      ProfileMenuItem(
        action: ProfileMenuAction.notifications,
        label: t('notifications'),
        icon: Icons.notifications_outlined,
      ),
      ProfileMenuItem(
        action: ProfileMenuAction.profile,
        label: t('profile'),
        icon: Icons.person_outline,
      ),
      ProfileMenuItem(
        action: ProfileMenuAction.settings,
        label: t('settings'),
        icon: Icons.settings_outlined,
      ),
      ProfileMenuItem(
        action: ProfileMenuAction.reloadApp,
        label: t('reloadAppShort'),
        icon: Icons.refresh,
      ),
      ProfileMenuItem(
        action: ProfileMenuAction.logout,
        label: t('logOut'),
        icon: Icons.logout,
        danger: true,
      ),
    ];
  }

  void _onMenu(ProfileMenuAction action) {
    final t = LocaleController.instance.strings.t;
    switch (action) {
      case ProfileMenuAction.premiumInvoices:
        setState(() {
          _page = _VendorPage.invoices;
        });
        break;
      case ProfileMenuAction.premiumCamera:
        setState(() {
          _page = _VendorPage.premium;
          _premiumFocus = PremiumFeature.camera;
        });
        break;
      case ProfileMenuAction.premiumAccounting:
        setState(() {
          _page = _VendorPage.premium;
          _premiumFocus = PremiumFeature.accounting;
        });
        break;
      case ProfileMenuAction.profile:
        setState(() => _page = _VendorPage.profile);
        break;
      case ProfileMenuAction.settings:
        setState(() => _page = _VendorPage.settings);
        break;
      case ProfileMenuAction.chat:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('vendorChatComingSoon'))),
        );
        break;
      case ProfileMenuAction.callStores:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('pickStoreToCall'))),
        );
        setState(() => _page = _VendorPage.stores);
        break;
      case ProfileMenuAction.notifications:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('notificationsComingSoon'))),
        );
        break;
      case ProfileMenuAction.reloadApp:
        widget.onReload?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('appReloaded'))),
        );
        break;
      case ProfileMenuAction.logout:
        widget.onLogout();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = LocaleController.instance.strings.t;
    return IdleActivityScope(
      onIdleChanged: (idle) {
        if (mounted) setState(() => _idleFlashing = idle);
      },
      child: Scaffold(
        key: AppKeys.vendorShell,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                t('vendor'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          actions: [
            HelpChatButton(
              flashing: _idleFlashing,
              roleLabel: t('vendor'),
              currentScreen: _title,
              backend: activeBackend.name,
              onOpened: () {
                if (_idleFlashing) setState(() => _idleFlashing = false);
              },
            ),
            ProfileMenuButton(items: _menuItems, onSelected: _onMenu),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(key: ValueKey(_page), child: _body()),
        ),
      ),
    );
  }

  String get _title {
    final t = LocaleController.instance.strings.t;
    switch (_page) {
      case _VendorPage.stores:
        return t('stores');
      case _VendorPage.invoices:
        return t('sendInvoices');
      case _VendorPage.premium:
        return t('premium');
      case _VendorPage.profile:
        return t('profile');
      case _VendorPage.settings:
        return t('settings');
    }
  }

  Widget _body() {
    switch (_page) {
      case _VendorPage.stores:
        return const VendorStoresScreen();
      case _VendorPage.invoices:
        return const VendorInvoicesScreen();
      case _VendorPage.premium:
        return PremiumFeaturesScreen(focus: _premiumFocus);
      case _VendorPage.profile:
        return const ProfileScreen();
      case _VendorPage.settings:
        return SettingsScreen(
          onLogout: widget.onLogout,
          onReload: widget.onReload,
        );
    }
  }
}
