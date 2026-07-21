import 'package:flutter/material.dart';

import '../constants/keys.dart';
import '../l10n/locale_controller.dart';
import '../theme/pasale_theme.dart';

/// Menu entries used across role shells.
enum ProfileMenuAction {
  dashboard,
  viewInvoices,
  createManualInvoice,
  catalog,
  inventory,
  scanInvoice,
  cameraOptions,
  vendors,
  customers,
  profile,
  settings,
  chat,
  notifications,
  reloadApp,
  logout,
  callStores,
  premiumInvoices,
  premiumCamera,
  premiumAccounting,
}

class ProfileMenuItem {
  const ProfileMenuItem({
    required this.action,
    required this.label,
    required this.icon,
    this.premium = false,
    this.danger = false,
  });

  final ProfileMenuAction action;
  final String label;
  final IconData icon;
  final bool premium;
  final bool danger;
}

/// One row in the account menu: section header or tappable item.
sealed class ProfileMenuEntry {
  const ProfileMenuEntry();
}

class ProfileMenuSection extends ProfileMenuEntry {
  const ProfileMenuSection(this.title);
  final String title;
}

class ProfileMenuEntryItem extends ProfileMenuEntry {
  const ProfileMenuEntryItem(this.item);
  final ProfileMenuItem item;
}

/// Modern account control: opens a Material 3 bottom sheet instead of a
/// dated popup / drawer.
class ProfileMenuButton extends StatelessWidget {
  /// Prefer [entries] for sectioned menus; [items] for a flat list.
  const ProfileMenuButton({
    super.key,
    this.entries,
    this.items,
    required this.onSelected,
  }) : assert(
          entries != null || items != null,
          'Provide entries or items',
        );

  final List<ProfileMenuEntry>? entries;
  final List<ProfileMenuItem>? items;
  final ValueChanged<ProfileMenuAction> onSelected;

  List<ProfileMenuEntry> get _rows {
    if (entries != null) return entries!;
    return (items ?? [])
        .map((e) => ProfileMenuEntryItem(e))
        .toList(growable: false);
  }

  Future<void> _open(BuildContext context) async {
    final t = LocaleController.instance.strings.t;
    final rows = _rows;
    final action = await showModalBottomSheet<ProfileMenuAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.58,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(
                          Icons.person_rounded,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('account'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              t('profileSettingsMore'),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      if (row is ProfileMenuSection) {
                        return Padding(
                          padding: EdgeInsets.fromLTRB(8, i == 0 ? 4 : 14, 8, 6),
                          child: Text(
                            row.title.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      final item = (row as ProfileMenuEntryItem).item;
                      final isLogout =
                          item.action == ProfileMenuAction.logout;
                      if (isLogout && i > 0) {
                        return Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                            _MenuTile(
                              item: item,
                              onTap: () => Navigator.pop(ctx, item.action),
                            ),
                          ],
                        );
                      }
                      return _MenuTile(
                        item: item,
                        onTap: () => Navigator.pop(ctx, item.action),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (action != null) onSelected(action);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = LocaleController.instance.strings.t;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: IconButton(
        key: AppKeys.profileMenuButton,
        tooltip: t('accountMenu'),
        onPressed: () => _open(context),
        style: IconButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurface,
        ),
        icon: const Icon(Icons.menu_rounded),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item, required this.onTap});

  final ProfileMenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final danger = item.danger;
    final premium = item.premium;
    final color = danger
        ? scheme.error
        : (premium ? scheme.tertiary : scheme.onSurface);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        key: AppKeys.menuAction(item.action.name),
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: danger
                ? scheme.errorContainer.withValues(alpha: 0.65)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(PasaleTheme.radiusSm),
          ),
          child: Icon(item.icon, size: 20, color: color),
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: color,
            fontWeight: danger ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        trailing: premium
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: scheme.onTertiaryContainer,
                    letterSpacing: 0.4,
                  ),
                ),
              )
            : Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
      ),
    );
  }
}
