import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Device speech-to-text wrapper (offline-capable OS engines).
class VoiceInputService {
  VoiceInputService({stt.SpeechToText? speech})
      : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;
  bool _ready = false;

  bool get isAvailable => _ready;
  bool get isListening => _speech.isListening;

  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _speech.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  /// Start listening. [onPartial] may fire multiple times.
  Future<void> start({
    required String localeId,
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
  }) async {
    final ok = await init();
    if (!ok) {
      throw StateError('Speech recognition unavailable on this device');
    }
    await _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords;
        if (result.finalResult) {
          onFinal(text);
        } else {
          onPartial(text);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      ),
    );
  }

  Future<void> stop() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}
  }

  Future<void> cancel() async {
    try {
      if (_speech.isListening) {
        await _speech.cancel();
      }
    } catch (_) {}
  }

  /// Map app language code → common STT locale ids.
  static String localeIdForAppLanguage(String code) {
    switch (code) {
      case 'ne':
        return 'ne_NP';
      case 'bn':
        return 'bn_BD';
      case 'hi':
        return 'hi_IN';
      case 'ur':
        return 'ur_PK';
      case 'en':
      default:
        return 'en_US';
    }
  }
}

/// No-op voice for tests / desktop without plugins.
class FakeVoiceInputService extends VoiceInputService {
  FakeVoiceInputService() : super(speech: stt.SpeechToText());

  @override
  bool get isAvailable => false;

  @override
  bool get isListening => false;

  @override
  Future<bool> init() async => false;

  @override
  Future<void> start({
    required String localeId,
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
  }) async {
    throw StateError('Voice input disabled (fake)');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}
