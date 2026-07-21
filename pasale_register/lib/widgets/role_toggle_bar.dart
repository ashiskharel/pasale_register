import 'package:flutter/material.dart';

import '../constants/keys.dart';
import '../models/user_role.dart';
import '../theme/pasale_theme.dart';

/// Outlined segmented control: Store Owner | Vendor | Buyer
class RoleToggleBar extends StatelessWidget {
  const RoleToggleBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.labelFor,
  });

  final UserRole selected;
  final ValueChanged<UserRole> onChanged;
  /// Optional localized labels; falls back to [UserRole.label].
  final String Function(UserRole role)? labelFor;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: AppKeys.roleToggleBar,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: PasaleTheme.hairline),
        borderRadius: BorderRadius.circular(PasaleTheme.radiusLg),
      ),
      child: Row(
        children: UserRole.values.map((role) {
          final isSelected = role == selected;
          final label = labelFor?.call(role) ?? role.label;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: AppKeys.roleOption(role),
                borderRadius: BorderRadius.circular(PasaleTheme.radiusMd),
                onTap: () => onChanged(role),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? PasaleTheme.ink : Colors.transparent,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(PasaleTheme.radiusMd),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconFor(role),
                        size: 20,
                        color: isSelected ? PasaleTheme.ink : PasaleTheme.mute,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? PasaleTheme.ink : PasaleTheme.mute,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _iconFor(UserRole role) {
    switch (role) {
      case UserRole.storeOwner:
        return Icons.storefront_outlined;
      case UserRole.vendor:
        return Icons.local_shipping_outlined;
      case UserRole.buyer:
        return Icons.shopping_bag_outlined;
    }
  }
}
