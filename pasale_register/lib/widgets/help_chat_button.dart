import 'package:flutter/material.dart';

import '../constants/keys.dart';
import '../l10n/locale_controller.dart';
import '../services/app_help_agent_service.dart';
import '../theme/pasale_theme.dart';
import 'help_chat_sheet.dart';

/// Top-right "?" that pulses when the screen is idle.
class HelpChatButton extends StatefulWidget {
  const HelpChatButton({
    super.key,
    required this.flashing,
    required this.roleLabel,
    required this.currentScreen,
    this.backend = 'fakes',
    this.onOpened,
  });

  final bool flashing;
  final String roleLabel;
  final String currentScreen;
  final String backend;
  final VoidCallback? onOpened;

  @override
  State<HelpChatButton> createState() => _HelpChatButtonState();
}

class _HelpChatButtonState extends State<HelpChatButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncFlash();
  }

  @override
  void didUpdateWidget(covariant HelpChatButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flashing != widget.flashing) {
      _syncFlash();
    }
  }

  void _syncFlash() {
    if (widget.flashing) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    widget.onOpened?.call();
    final lang = LocaleController.instance.language;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return HelpChatSheet(
          contextInfo: HelpChatContext(
            roleLabel: widget.roleLabel,
            currentScreen: widget.currentScreen,
            appLanguage: lang.englishLabel,
            backend: widget.backend,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = LocaleController.instance.strings.t;

    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: FadeTransition(
        opacity: widget.flashing
            ? Tween<double>(begin: 0.35, end: 1).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              )
            : const AlwaysStoppedAnimation(1),
        child: ScaleTransition(
          scale: widget.flashing
              ? Tween<double>(begin: 0.92, end: 1.08).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                )
              : const AlwaysStoppedAnimation(1),
          child: IconButton(
            key: AppKeys.helpChatButton,
            tooltip: t('helpChatTitle'),
            onPressed: _open,
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: PasaleTheme.ink,
              side: BorderSide(
                color: widget.flashing ? PasaleTheme.ink : Colors.transparent,
                width: widget.flashing ? 1.5 : 0,
              ),
            ),
            icon: const Text(
              '?',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
