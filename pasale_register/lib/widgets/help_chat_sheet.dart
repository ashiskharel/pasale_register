import 'package:flutter/material.dart';

import '../constants/keys.dart';
import '../l10n/locale_controller.dart';
import '../services/app_help_agent_service.dart';
import '../services/service_locator.dart';
import '../services/voice_input_service.dart';
import '../services/voice_output_service.dart';
import '../theme/pasale_theme.dart';

class HelpChatSheet extends StatefulWidget {
  const HelpChatSheet({
    super.key,
    required this.contextInfo,
    this.agent,
    this.voiceIn,
    this.voiceOut,
  });

  final HelpChatContext contextInfo;
  final AppHelpAgentService? agent;
  final VoiceInputService? voiceIn;
  final VoiceOutputService? voiceOut;

  @override
  State<HelpChatSheet> createState() => _HelpChatSheetState();
}

class _HelpChatSheetState extends State<HelpChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <HelpChatMessage>[];

  late final AppHelpAgentService _agent;
  late final VoiceInputService _voiceIn;
  late final VoiceOutputService _voiceOut;

  bool _busy = false;
  bool _listening = false;
  bool _autoSpeak = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _agent = widget.agent ??
        (locator.isRegistered<AppHelpAgentService>()
            ? locator<AppHelpAgentService>()
            : LocalAppHelpAgentService());
    _voiceIn = widget.voiceIn ??
        (locator.isRegistered<VoiceInputService>()
            ? locator<VoiceInputService>()
            : VoiceInputService());
    _voiceOut = widget.voiceOut ??
        (locator.isRegistered<VoiceOutputService>()
            ? locator<VoiceOutputService>()
            : VoiceOutputService());

    final t = LocaleController.instance.strings.t;
    _messages.add(
      HelpChatMessage(role: 'assistant', content: t('helpChatWelcome')),
    );
  }

  @override
  void dispose() {
    _voiceIn.cancel();
    _voiceOut.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _input.text).trim();
    if (text.isEmpty || _busy) return;

    setState(() {
      _error = null;
      _busy = true;
      _messages.add(HelpChatMessage(role: 'user', content: text));
      _input.clear();
    });
    _scrollToEnd();

    try {
      final history = _messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .toList();
      // Exclude the just-added user message from history dup — service appends it.
      final prior = history.length > 1
          ? history.sublist(0, history.length - 1)
          : <HelpChatMessage>[];

      final answer = await _agent.reply(
        history: prior,
        userMessage: text,
        context: widget.contextInfo,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(HelpChatMessage(role: 'assistant', content: answer));
        _busy = false;
      });
      _scrollToEnd();

      if (_autoSpeak) {
        final code = LocaleController.instance.language.code;
        await _voiceOut.speak(answer, languageCode: code);
      }
    } catch (e) {
      if (!mounted) return;
      final t = LocaleController.instance.strings.t;
      setState(() {
        _busy = false;
        _error = t('helpChatError');
        _messages.add(
          HelpChatMessage(
            role: 'assistant',
            content: '${t('helpChatError')}: $e',
          ),
        );
      });
    }
  }

  Future<void> _toggleMic() async {
    final t = LocaleController.instance.strings.t;
    if (_listening) {
      await _voiceIn.stop();
      setState(() => _listening = false);
      return;
    }

    await _voiceOut.stop();
    setState(() {
      _error = null;
      _listening = true;
    });

    try {
      final localeId = VoiceInputService.localeIdForAppLanguage(
        LocaleController.instance.language.code,
      );
      await _voiceIn.start(
        localeId: localeId,
        onPartial: (text) {
          if (!mounted) return;
          _input.text = text;
          _input.selection = TextSelection.collapsed(offset: text.length);
        },
        onFinal: (text) async {
          if (!mounted) return;
          setState(() => _listening = false);
          _input.text = text;
          if (text.trim().isNotEmpty) {
            await _send(text);
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _error = t('helpChatVoiceUnavailable');
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleController.instance.strings.t;
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        key: AppKeys.helpChatSheet,
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: PasaleTheme.ink),
                      borderRadius: BorderRadius.circular(PasaleTheme.radiusSm),
                    ),
                    child: const Text(
                      '?',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('helpChatTitle'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          _agent.llmAvailable
                              ? t('helpChatOnlineHint')
                              : t('helpChatOffline'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: t('helpChatSpeak'),
                    onPressed: () {
                      setState(() => _autoSpeak = !_autoSpeak);
                      if (!_autoSpeak) _voiceOut.stop();
                    },
                    icon: Icon(
                      _autoSpeak
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_outlined,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                itemCount: _messages.length + (_busy ? 1 : 0),
                itemBuilder: (context, i) {
                  if (_busy && i == _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final m = _messages[i];
                  final isUser = m.role == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                      ),
                      decoration: BoxDecoration(
                        color: isUser
                            ? PasaleTheme.ink
                            : scheme.surfaceContainerHighest,
                        border: Border.all(color: PasaleTheme.ink, width: 1),
                        borderRadius: BorderRadius.circular(PasaleTheme.radiusMd),
                      ),
                      child: Text(
                        m.content,
                        style: TextStyle(
                          color: isUser ? Colors.white : PasaleTheme.ink,
                          height: 1.35,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  _error!,
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
              child: Row(
                children: [
                  IconButton(
                    key: AppKeys.helpChatMic,
                    tooltip: _listening
                        ? t('helpChatListening')
                        : t('helpChatMic'),
                    onPressed: _busy ? null : _toggleMic,
                    style: IconButton.styleFrom(
                      backgroundColor: _listening
                          ? scheme.errorContainer
                          : scheme.surfaceContainerHighest,
                    ),
                    icon: Icon(
                      _listening ? Icons.mic : Icons.mic_none_outlined,
                      color: _listening ? scheme.error : null,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      key: AppKeys.helpChatInput,
                      controller: _input,
                      enabled: !_busy && !_listening,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: t('helpChatHint'),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(PasaleTheme.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    key: AppKeys.helpChatSend,
                    onPressed: _busy || _listening ? null : () => _send(),
                    child: Text(t('helpChatSend')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
