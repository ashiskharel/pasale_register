import 'package:flutter/material.dart';

import '../constants/keys.dart';
import '../l10n/locale_controller.dart';
import '../services/session_service.dart';
import '../services/sharing_service.dart';
import '../services/service_locator.dart';
import '../services/firestore_service.dart';
import '../widgets/language_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.onLogout,
    this.onReload,
  });

  final VoidCallback? onLogout;
  final VoidCallback? onReload;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _session = SessionService();
  bool _notifications = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LocaleController.instance.addListener(_onLocale);
    _load();
  }

  @override
  void dispose() {
    LocaleController.instance.removeListener(_onLocale);
    super.dispose();
  }

  void _onLocale() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final s = await _session.load();
    if (!mounted) return;
    setState(() {
      _notifications = s.notificationsEnabled;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleController.instance.strings.t;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      key: AppKeys.settingsScreen,
      children: [
        const LanguageSettingsTile(),
        const Divider(),
        SwitchListTile(
          title: Text(t('notifications')),
          subtitle: Text(t('notificationsSub')),
          value: _notifications,
          onChanged: (v) async {
            setState(() => _notifications = v);
            await _session.setNotificationsEnabled(v);
          },
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: Text(t('reloadApp')),
          subtitle: Text(t('reloadAppSub')),
          onTap: () {
            widget.onReload?.call();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('appDataReloaded'))),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.person_add_alt_1),
          title: const Text('Invite Store Staff'),
          subtitle: const Text('Send an SMS invite to a staff member'),
            onTap: () async {
              final s = await _session.load();
              final storeId = s.storeId ?? '';
              if (storeId.isEmpty) return;
              try {
                final passcode = await locator<FirestoreService>().getOrGeneratePasscode(storeId);
                final text = 'Join my store on Pasale Register!\nStore ID: $storeId\nPasscode: $passcode\nDownload the app at: https://pasale.app';
                await locator<SharingService>().shareReceipt(text, '');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate invite: $e')));
                }
              }
            },
        ),
        const Divider(),
        ListTile(
          leading: Icon(Icons.logout, color: Colors.red.shade400),
          title: Text(
            t('logOut'),
            key: AppKeys.logoutButton,
            style: TextStyle(
              color: Colors.red.shade400,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(t('logOutSub')),
          onTap: widget.onLogout,
        ),
      ],
    );
  }
}
