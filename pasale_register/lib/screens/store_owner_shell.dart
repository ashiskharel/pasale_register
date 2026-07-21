import 'package:flutter/material.dart';

import '../constants/keys.dart';
import '../l10n/locale_controller.dart';
import '../services/service_locator.dart';
import '../services/session_service.dart';
import '../widgets/help_chat_button.dart';
import '../widgets/idle_activity_scope.dart';
import '../widgets/pasale_brand.dart';
import '../widgets/profile_menu_button.dart';
import '../widgets/store_switcher.dart';
import 'camera_scope_screen.dart';
import 'catalog_screen.dart';
import 'checkout_screen.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'inventory_management_screen.dart';
import 'invoice_ingestor_screen.dart';
import 'invoices_list_screen.dart';
import 'manual_invoice_screen.dart';
import 'premium_features_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'vendors_manage_screen.dart';

enum _OwnerPage {
  scanner,
  catalog,
  inventory,
  dashboard,
  viewInvoices,
  createManualInvoice,
  scanInvoice,
  cameraOptions,
  vendors,
  customers,
  profile,
  settings,
  premium,
}

/// Store owner home: Scanner as default, full dropdown navigation.
class StoreOwnerShell extends StatefulWidget {
  const StoreOwnerShell({
    super.key,
    required this.onLogout,
    this.onReload,
  });

  final VoidCallback onLogout;
  final VoidCallback? onReload;

  @override
  State<StoreOwnerShell> createState() => _StoreOwnerShellState();
}

class _StoreOwnerShellState extends State<StoreOwnerShell> {
  _OwnerPage _page = _OwnerPage.scanner;
  PremiumFeature? _premiumFocus;
  bool _idleFlashing = false;
  String? _activeStoreKey;

  @override
  void initState() {
    super.initState();
    LocaleController.instance.addListener(_onLocale);
    _loadActiveStoreKey();
  }

  Future<void> _loadActiveStoreKey() async {
    final s = await SessionService().load();
    if (!mounted) return;
    setState(() {
      _activeStoreKey = '${s.storeId ?? ''}|${s.businessId ?? ''}';
    });
  }

  @override
  void dispose() {
    LocaleController.instance.removeListener(_onLocale);
    super.dispose();
  }

  void _onLocale() {
    if (mounted) setState(() {});
  }

  List<ProfileMenuEntry> get _menuEntries {
    final t = LocaleController.instance.strings.t;
    return [
      ProfileMenuSection('Stock & Vendors'),
      ProfileMenuEntryItem(
        ProfileMenuItem(
          action: ProfileMenuAction.inventory,
          label: 'Inventory Management',
          icon: Icons.assignment_outlined,
        ),
      ),
      ProfileMenuEntryItem(
        ProfileMenuItem(
          action: ProfileMenuAction.scanInvoice,
          label: t('scanVendorInvoice'),
          icon: Icons.document_scanner_outlined,
        ),
      ),
      ProfileMenuEntryItem(
        ProfileMenuItem(
          action: ProfileMenuAction.vendors,
          label: t('vendors'),
          icon: Icons.local_shipping_outlined,
        ),
      ),
      ProfileMenuSection('Billing & Invoices'),
      ProfileMenuEntryItem(
        ProfileMenuItem(
          action: ProfileMenuAction.viewInvoices,
          label: t('viewInvoices'),
          icon: Icons.receipt_outlined,
        ),
      ),
      ProfileMenuEntryItem(
        ProfileMenuItem(
          action: ProfileMenuAction.createManualInvoice,
          label: t('createManualInvoice'),
          icon: Icons.edit_note_outlined,
        ),
      ),
      ProfileMenuSection('Features & Tools'),
      ProfileMenuEntryItem(
        ProfileMenuItem(
          action: ProfileMenuAction.cameraOptions,
          label: t('cameraOptions'),
          icon: Icons.camera_enhance_outlined,
          premium: true,
        ),
      ),
      ProfileMenuEntryItem(
        ProfileMenuItem(
          action: ProfileMenuAction.chat,
          label: t('chat'),
          icon: Icons.chat_outlined,
        ),
      ),
      ProfileMenuEntryItem(
        ProfileMenuItem(
          action: ProfileMenuAction.notifications,
          label: t('notifications'),
          icon: Icons.notifications_outlined,
        ),
      ),
      ProfileMenuSection('Account & App'),
      ProfileMenuEntryItem(
        ProfileMenuItem(
          action: ProfileMenuAction.profile,
          label: t('profile'),
          icon: Icons.person_outline,
        ),
      ),
      ProfileMenuEntryItem(
        ProfileMenuItem(
          action: ProfileMenuAction.settings,
          label: t('settings'),
          icon: Icons.settings_outlined,
        ),
      ),
      ProfileMenuEntryItem(
        ProfileMenuItem(
          action: ProfileMenuAction.reloadApp,
          label: t('reloadAppShort'),
          icon: Icons.refresh,
        ),
      ),
      ProfileMenuEntryItem(
        ProfileMenuItem(
          action: ProfileMenuAction.logout,
          label: t('logOut'),
          icon: Icons.logout,
          danger: true,
        ),
      ),
    ];
  }

  void _onMenu(ProfileMenuAction action) {
    final t = LocaleController.instance.strings.t;
    switch (action) {
      case ProfileMenuAction.dashboard:
        setState(() => _page = _OwnerPage.dashboard);
        break;
      case ProfileMenuAction.viewInvoices:
        setState(() => _page = _OwnerPage.viewInvoices);
        break;
      case ProfileMenuAction.createManualInvoice:
        setState(() => _page = _OwnerPage.createManualInvoice);
        break;
      case ProfileMenuAction.catalog:
        setState(() => _page = _OwnerPage.catalog);
        break;
      case ProfileMenuAction.inventory:
        setState(() => _page = _OwnerPage.inventory);
        break;
      case ProfileMenuAction.scanInvoice:
        setState(() => _page = _OwnerPage.scanInvoice);
        break;
      case ProfileMenuAction.cameraOptions:
        setState(() {
          _page = _OwnerPage.premium;
          _premiumFocus = PremiumFeature.camera;
        });
        break;
      case ProfileMenuAction.vendors:
        setState(() => _page = _OwnerPage.vendors);
        break;
      case ProfileMenuAction.customers:
        setState(() => _page = _OwnerPage.customers);
        break;
      case ProfileMenuAction.profile:
        setState(() => _page = _OwnerPage.profile);
        break;
      case ProfileMenuAction.settings:
        setState(() => _page = _OwnerPage.settings);
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

  String get _title {
    final t = LocaleController.instance.strings.t;
    switch (_page) {
      case _OwnerPage.scanner:
        return t('scanner');
      case _OwnerPage.catalog:
        return t('catalog');
      case _OwnerPage.inventory:
        return 'Inventory Management';
      case _OwnerPage.dashboard:
        return t('dashboard');
      case _OwnerPage.viewInvoices:
        return t('viewInvoices');
      case _OwnerPage.createManualInvoice:
        return t('createManualInvoice');
      case _OwnerPage.scanInvoice:
        return t('scanVendorInvoice');
      case _OwnerPage.cameraOptions:
        return t('cameraOptions');
      case _OwnerPage.vendors:
        return t('vendors');
      case _OwnerPage.customers:
        return t('customers');
      case _OwnerPage.profile:
        return t('profile');
      case _OwnerPage.settings:
        return t('settings');
      case _OwnerPage.premium:
        return t('premium');
    }
  }

  Widget _body() {
    switch (_page) {
      case _OwnerPage.scanner:
        // CheckoutScreen has its own AppBar — embed without double bars
        return const CheckoutScreen(embedded: true);
      case _OwnerPage.catalog:
        return const CatalogScreen(embedded: true);
      case _OwnerPage.inventory:
        return const InventoryManagementScreen();
      case _OwnerPage.dashboard:
        return const DashboardScreen();
      case _OwnerPage.viewInvoices:
        return const InvoicesListScreen();
      case _OwnerPage.createManualInvoice:
        return const ManualInvoiceScreen();
      case _OwnerPage.scanInvoice:
        return const InvoiceIngestorScreen(embedded: true);
      case _OwnerPage.cameraOptions:
        return const CameraScopeScreen();
      case _OwnerPage.vendors:
        return const VendorsManageScreen();
      case _OwnerPage.customers:
        return const CustomersScreen();
      case _OwnerPage.profile:
        return const ProfileScreen();
      case _OwnerPage.settings:
        return SettingsScreen(
          onLogout: widget.onLogout,
          onReload: widget.onReload,
        );
      case _OwnerPage.premium:
        return PremiumFeaturesScreen(focus: _premiumFocus);
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
        key: AppKeys.storeOwnerShell,
        appBar: AppBar(
          title: Row(
            children: [
              const PasaleLogo(size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      t('storeOwner'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            StoreSwitcherButton(
              onStoreChanged: () {
                _loadActiveStoreKey();
              },
            ),
            HelpChatButton(
              flashing: _idleFlashing,
              roleLabel: t('storeOwner'),
              currentScreen: _title,
              backend: activeBackend.name,
              onOpened: () {
                if (_idleFlashing) setState(() => _idleFlashing = false);
              },
            ),
            if (_page != _OwnerPage.scanner)
              IconButton(
                key: AppKeys.navToScanner,
                tooltip: t('scanner'),
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                onPressed: () => setState(() => _page = _OwnerPage.scanner),
              ),
            ProfileMenuButton(entries: _menuEntries, onSelected: _onMenu),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            // Include store key so catalog/scanner reload after branch switch.
            key: ValueKey('${_page.name}_${_activeStoreKey ?? ''}'),
            child: _body(),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _navIndex,
          onDestinationSelected: (i) {
            setState(() {
              switch (i) {
                case 0:
                  _page = _OwnerPage.scanner;
                  break;
                case 1:
                  _page = _OwnerPage.catalog;
                  break;
                case 2:
                  _page = _OwnerPage.dashboard;
                  break;
                case 3:
                  _page = _OwnerPage.customers;
                  break;
              }
            });
          },
          destinations: [
            NavigationDestination(
              key: AppKeys.navToCheckout,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              selectedIcon: const Icon(Icons.qr_code_scanner_rounded),
              label: t('scan'),
            ),
            NavigationDestination(
              key: AppKeys.navToCatalog,
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2_rounded),
              label: t('catalog'),
            ),
            NavigationDestination(
              key: AppKeys.navToDashboard,
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights_rounded),
              label: t('dashboard'),
            ),
            NavigationDestination(
              key: AppKeys.navToCustomers,
              icon: const Icon(Icons.people_outline_rounded),
              selectedIcon: const Icon(Icons.people_rounded),
              label: t('customers'),
            ),
          ],
        ),
      ),
    );
  }

  int get _navIndex {
    switch (_page) {
      case _OwnerPage.scanner:
        return 0;
      case _OwnerPage.catalog:
        return 1;
      case _OwnerPage.dashboard:
        return 2;
      case _OwnerPage.customers:
        return 3;
      default:
        return 0;
    }
  }
}
