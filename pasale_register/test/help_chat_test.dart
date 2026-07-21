import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasale_register/constants/keys.dart';
import 'package:pasale_register/l10n/app_help_knowledge.dart';
import 'package:pasale_register/l10n/locale_controller.dart';
import 'package:pasale_register/services/app_help_agent_service.dart';
import 'package:pasale_register/services/service_locator.dart';
import 'package:pasale_register/services/voice_input_service.dart';
import 'package:pasale_register/services/voice_output_service.dart';
import 'package:pasale_register/widgets/help_chat_button.dart';
import 'package:pasale_register/widgets/help_chat_sheet.dart';
import 'package:pasale_register/widgets/idle_activity_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocaleController.instance.load();
    setupLocator(backend: ServiceBackend.fakes);
  });

  group('AppHelpKnowledge', () {
    test('answers barcode scan questions', () {
      final a = AppHelpKnowledge.answerFromQuery('How do I scan a barcode?');
      expect(a.toLowerCase(), contains('barcode'));
    });

    test('answers offline questions', () {
      final a = AppHelpKnowledge.answerFromQuery('does scanner work offline?');
      expect(a.toLowerCase(), anyOf(contains('offline'), contains('without internet')));
    });
  });

  group('LocalAppHelpAgentService', () {
    test('returns local guide without API key', () async {
      final agent = LocalAppHelpAgentService();
      expect(agent.llmAvailable, isFalse);
      final reply = await agent.reply(
        history: const [],
        userMessage: 'How do I change language?',
        context: const HelpChatContext(
          roleLabel: 'Store owner',
          currentScreen: 'Settings',
          appLanguage: 'English',
        ),
      );
      expect(reply.toLowerCase(), contains('language'));
    });
  });

  testWidgets('idle scope fires after duration', (tester) async {
    var idle = false;
    await tester.pumpWidget(
      MaterialApp(
        home: IdleActivityScope(
          idleDuration: const Duration(milliseconds: 50),
          onIdleChanged: (v) => idle = v,
          child: const Scaffold(body: Text('hi')),
        ),
      ),
    );
    expect(idle, isFalse);
    await tester.pump(const Duration(milliseconds: 60));
    expect(idle, isTrue);
  });

  testWidgets('help button opens sheet and sends message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: const [
              HelpChatButton(
                flashing: false,
                roleLabel: 'Store owner',
                currentScreen: 'Scanner',
                backend: 'fakes',
              ),
            ],
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.tap(find.byKey(AppKeys.helpChatButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.helpChatSheet), findsOneWidget);
    expect(find.byKey(AppKeys.helpChatInput), findsOneWidget);

    await tester.enterText(find.byKey(AppKeys.helpChatInput), 'how to scan barcode');
    await tester.tap(find.byKey(AppKeys.helpChatSend));
    await tester.pumpAndSettle();

    expect(find.textContaining('Barcode'), findsWidgets);
  });

  testWidgets('help sheet works with injected agent', (tester) async {
    final agent = LocalAppHelpAgentService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HelpChatSheet(
            contextInfo: const HelpChatContext(
              roleLabel: 'Store owner',
              currentScreen: 'Catalog',
              appLanguage: 'English',
              backend: 'fakes',
            ),
            agent: agent,
            voiceIn: FakeVoiceInputService(),
            voiceOut: FakeVoiceOutputService(),
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(AppKeys.helpChatInput), 'catalog products');
    await tester.tap(find.byKey(AppKeys.helpChatSend));
    await tester.pumpAndSettle();

    expect(find.textContaining('Catalog'), findsWidgets);
  });
}
