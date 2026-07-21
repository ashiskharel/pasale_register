import 'package:flutter/material.dart';

import '../constants/keys.dart';
import '../l10n/locale_controller.dart';
import '../services/service_locator.dart';
import '../widgets/help_chat_button.dart';
import '../widgets/idle_activity_scope.dart';
import '../widgets/profile_menu_button.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

enum _BuyerPage { home, profile, settings }

class BuyerShell extends StatefulWidget {
  const BuyerShell({
    super.key,
    required this.onLogout,
    this.onReload,
  });

  final VoidCallback onLogout;
  final VoidCallback? onReload;

  @override
  State<BuyerShell> createState() => _BuyerShellState();
}

class _BuyerShellState extends State<BuyerShell> {
  _BuyerPage _page = _BuyerPage.home;
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
        action: ProfileMenuAction.notifications,
        label: t('notifications'),
        icon: Icons.notifications_outlined,
      ),
      ProfileMenuItem(
        action: ProfileMenuAction.chat,
        label: t('chat'),
        icon: Icons.chat_outlined,
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
      case ProfileMenuAction.profile:
        setState(() => _page = _BuyerPage.profile);
        break;
      case ProfileMenuAction.settings:
        setState(() => _page = _BuyerPage.settings);
        break;
      case ProfileMenuAction.chat:
      case ProfileMenuAction.notifications:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == ProfileMenuAction.chat
                  ? t('chatComingSoon')
                  : t('notificationsComingSoon'),
            ),
          ),
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
        key: AppKeys.buyerShell,
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
                t('buyer'),
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
              roleLabel: t('buyer'),
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
      case _BuyerPage.home:
        return t('shop');
      case _BuyerPage.profile:
        return t('profile');
      case _BuyerPage.settings:
        return t('settings');
    }
  }

  Widget _body() {
    final t = LocaleController.instance.strings.t;
    switch (_page) {
      case _BuyerPage.home:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront),
                title: Text(t('nearbyStores')),
                subtitle: Text(t('nearbyStoresSub')),
                onTap: () {},
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(t('creditsDeposits')),
                subtitle: Text(t('creditsDepositsSub')),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t('creditLedgerSoon'))),
                  );
                },
              ),
            ),
          ],
        );
      case _BuyerPage.profile:
        return const ProfileScreen();
      case _BuyerPage.settings:
        return SettingsScreen(
          onLogout: widget.onLogout,
          onReload: widget.onReload,
        );
    }
  }
}
