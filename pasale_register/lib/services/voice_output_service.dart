import 'package:flutter_tts/flutter_tts.dart';

/// Device text-to-speech for assistant replies.
class VoiceOutputService {
  VoiceOutputService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> speak(String text, {String languageCode = 'en'}) async {
    if (text.trim().isEmpty) return;
    await init();
    if (!_ready) return;
    try {
      await _tts.setLanguage(_ttsLanguage(languageCode));
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Ignore TTS failures (missing voice packs, etc.)
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  static String _ttsLanguage(String code) {
    switch (code) {
      case 'ne':
        return 'ne-NP';
      case 'bn':
        return 'bn-BD';
      case 'hi':
        return 'hi-IN';
      case 'ur':
        return 'ur-PK';
      case 'en':
      default:
        return 'en-US';
    }
  }
}

/// Records speak calls; never hits platform channels if [init]/[speak] stay overridden.
class FakeVoiceOutputService extends VoiceOutputService {
  FakeVoiceOutputService() : super();

  final List<String> spoken = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> speak(String text, {String languageCode = 'en'}) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}
