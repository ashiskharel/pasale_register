import 'dart:convert';

import 'package:http/http.dart' as http;

import '../l10n/app_help_knowledge.dart';

/// Compile-time SpaceXAI / xAI key. Never hardcode secrets in source.
const String kXaiApiKey = String.fromEnvironment('XAI_API_KEY', defaultValue: '');

class HelpChatMessage {
  const HelpChatMessage({required this.role, required this.content});

  /// `user` | `assistant` | `system`
  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class HelpChatContext {
  const HelpChatContext({
    required this.roleLabel,
    required this.currentScreen,
    required this.appLanguage,
    this.backend = 'fakes',
  });

  final String roleLabel;
  final String currentScreen;
  final String appLanguage;
  final String backend;
}

/// In-app Pasale guide: SpaceXAI when keyed, local knowledge otherwise.
abstract class AppHelpAgentService {
  bool get llmAvailable;

  Future<String> reply({
    required List<HelpChatMessage> history,
    required String userMessage,
    required HelpChatContext context,
  });
}

class SpaceXaiAppHelpAgentService implements AppHelpAgentService {
  SpaceXaiAppHelpAgentService({
    http.Client? client,
    this.apiKey = kXaiApiKey,
    this.model = 'grok-4.5',
    this.baseUrl = 'https://api.x.ai/v1',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String apiKey;
  final String model;
  final String baseUrl;

  @override
  bool get llmAvailable => apiKey.trim().isNotEmpty;

  @override
  Future<String> reply({
    required List<HelpChatMessage> history,
    required String userMessage,
    required HelpChatContext context,
  }) async {
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      return AppHelpKnowledge.answerFromQuery('');
    }

    if (!llmAvailable) {
      return AppHelpKnowledge.answerFromQuery(trimmed);
    }

    try {
      return await _chatCompletions(
        history: history,
        userMessage: trimmed,
        context: context,
      );
    } catch (_) {
      // Network / API failure → offline guide
      final local = AppHelpKnowledge.answerFromQuery(trimmed);
      return '$local\n\n_(Live assistant unavailable — answered from on-device guide.)_';
    }
  }

  Future<String> _chatCompletions({
    required List<HelpChatMessage> history,
    required String userMessage,
    required HelpChatContext context,
  }) async {
    final system = _systemPrompt(context);
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': system},
      ...history
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => m.toJson()),
      {'role': 'user', 'content': userMessage},
    ];

    // Light agentic tool pass: attach guide when user asks how-to.
    final tools = [
      {
        'type': 'function',
        'function': {
          'name': 'get_app_guide',
          'description': 'Fetch Pasale app help knowledge for a topic id or free query.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'User question or topic keywords',
              },
            },
            'required': ['query'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'list_screens_for_role',
          'description': 'List screens and menu items for the current role.',
          'parameters': {
            'type': 'object',
            'properties': {
              'role': {'type': 'string'},
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'get_capability_status',
          'description':
              'What works offline vs needs network for the current backend.',
          'parameters': {
            'type': 'object',
            'properties': {
              'backend': {'type': 'string'},
            },
          },
        },
      },
    ];

    var body = {
      'model': model,
      'messages': messages,
      'tools': tools,
      'tool_choice': 'auto',
      'temperature': 0.4,
    };

    var response = await _postChat(body);
    var data = jsonDecode(response.body) as Map<String, dynamic>;
    _ensureOk(response, data);

    // Up to 2 tool rounds
    for (var turn = 0; turn < 2; turn++) {
      final choices = data['choices'] as List?;
      final choice = (choices != null && choices.isNotEmpty)
          ? choices.first as Map<String, dynamic>
          : null;
      final message = choice?['message'] as Map<String, dynamic>?;
      if (message == null) break;

      final toolCalls = message['tool_calls'] as List?;
      if (toolCalls == null || toolCalls.isEmpty) {
        final content = message['content'] as String?;
        if (content != null && content.trim().isNotEmpty) {
          return content.trim();
        }
        break;
      }

      final follow = List<Map<String, dynamic>>.from(messages);
      follow.add({
        'role': 'assistant',
        'content': message['content'],
        'tool_calls': toolCalls,
      });

      for (final raw in toolCalls) {
        final tc = raw as Map<String, dynamic>;
        final id = tc['id'] as String? ?? 'call_$turn';
        final fn = tc['function'] as Map<String, dynamic>? ?? {};
        final name = fn['name'] as String? ?? '';
        Map<String, dynamic> args = {};
        final argsRaw = fn['arguments'];
        if (argsRaw is String && argsRaw.isNotEmpty) {
          try {
            args = jsonDecode(argsRaw) as Map<String, dynamic>;
          } catch (_) {}
        }
        final result = _runTool(name, args, context);
        follow.add({
          'role': 'tool',
          'tool_call_id': id,
          'content': result,
        });
      }

      body = {
        'model': model,
        'messages': follow,
        'tools': tools,
        'tool_choice': 'auto',
        'temperature': 0.4,
      };
      response = await _postChat(body);
      data = jsonDecode(response.body) as Map<String, dynamic>;
      _ensureOk(response, data);
      messages
        ..clear()
        ..addAll(follow);
    }

    final choices = data['choices'] as List?;
    final choice = (choices != null && choices.isNotEmpty)
        ? choices.first as Map<String, dynamic>
        : null;
    final content = choice?['message']?['content'] as String?;
    if (content != null && content.trim().isNotEmpty) {
      return content.trim();
    }
    return AppHelpKnowledge.answerFromQuery(userMessage);
  }

  String _runTool(
    String name,
    Map<String, dynamic> args,
    HelpChatContext context,
  ) {
    switch (name) {
      case 'get_app_guide':
        final q = (args['query'] as String?) ?? '';
        return AppHelpKnowledge.answerFromQuery(q);
      case 'list_screens_for_role':
        final role = (args['role'] as String?) ?? context.roleLabel;
        return AppHelpKnowledge.screensForRole(role);
      case 'get_capability_status':
        final backend = (args['backend'] as String?) ?? context.backend;
        return AppHelpKnowledge.capabilityStatus(backend: backend);
      default:
        return 'Unknown tool: $name';
    }
  }

  Future<http.Response> _postChat(Map<String, dynamic> body) {
    return _client
        .post(
          Uri.parse('$baseUrl/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));
  }

  void _ensureOk(http.Response response, Map<String, dynamic> data) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final err = data['error']?.toString() ?? response.body;
    throw StateError('SpaceXAI error ${response.statusCode}: $err');
  }

  String _systemPrompt(HelpChatContext context) {
    return '''
You are Pasale's in-app help assistant for a Nepal-focused store POS (Pasale Register).
Answer only about using this app. Be concise, step-by-step, friendly.
Match the user's language when possible (English, Nepali, Bengali, Hindi, Urdu).

Current context:
- Role: ${context.roleLabel}
- Screen: ${context.currentScreen}
- App language: ${context.appLanguage}
- Backend: ${context.backend}

Offline-aware facts:
- Barcode, price-tag OCR, invoice OCR, cart, and local catalog can work without internet (on-device ML).
- Real Firebase phone/Facebook auth and cloud multi-device sync need network.
- Live AI needs network; if tools return local guide, prefer those facts.
- Demo OTP works when Firebase Phone is unavailable.

Use tools when you need accurate feature lists or offline capability details.
Do not invent menus that do not exist. Do not claim peer vendor chat is live (it is coming soon).
''';
  }
}

/// Always local FAQ — used in tests and when fakes are forced.
class LocalAppHelpAgentService implements AppHelpAgentService {
  @override
  bool get llmAvailable => false;

  @override
  Future<String> reply({
    required List<HelpChatMessage> history,
    required String userMessage,
    required HelpChatContext context,
  }) async {
    return AppHelpKnowledge.answerFromQuery(userMessage);
  }
}
