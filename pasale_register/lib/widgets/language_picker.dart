import 'package:flutter/material.dart';

import '../constants/keys.dart';
import '../l10n/locale_controller.dart';
import '../theme/pasale_theme.dart';

/// Compact language chips for landing (below role toggle).
class LanguagePickerBar extends StatelessWidget {
  const LanguagePickerBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AppLanguage selected;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = LocaleController.instance.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.t('language'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          key: AppKeys.languagePicker,
          spacing: 8,
          runSpacing: 8,
          children: AppLanguage.values.map((lang) {
            final on = lang == selected;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                key: AppKeys.languageOption(lang.code),
                onTap: () => onChanged(lang),
                borderRadius: BorderRadius.circular(PasaleTheme.radiusSm),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: on ? PasaleTheme.ink : PasaleTheme.hairline,
                      width: on ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(PasaleTheme.radiusSm),
                  ),
                  child: Text(
                    lang.nativeLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                      color: on ? PasaleTheme.ink : PasaleTheme.mute,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Settings-style language selector (list tiles / radio).
class LanguageSettingsTile extends StatelessWidget {
  const LanguageSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = LocaleController.instance;
    final s = ctrl.strings;
    return ListTile(
      key: AppKeys.languageSettingsTile,
      leading: const Icon(Icons.language_outlined),
      title: Text(s.t('appLanguage')),
      subtitle: Text(
        '${ctrl.language.nativeLabel} · ${ctrl.language.englishLabel}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openPicker(context),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final ctrl = LocaleController.instance;
    final s = ctrl.strings;
    final picked = await showModalBottomSheet<AppLanguage>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  s.t('chooseLanguage'),
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              ...AppLanguage.values.map((lang) {
                final on = lang == ctrl.language;
                return ListTile(
                  key: AppKeys.languageOption(lang.code),
                  title: Text(lang.nativeLabel),
                  subtitle: Text(lang.englishLabel),
                  trailing: on
                      ? const Icon(Icons.check, size: 20)
                      : null,
                  onTap: () => Navigator.pop(ctx, lang),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked != null) {
      await ctrl.setLanguage(picked);
    }
  }
}
