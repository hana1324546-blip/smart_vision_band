import 'package:flutter_tts/flutter_tts.dart';
class TtsService {
  final FlutterTts _tts = FlutterTts();
  final Map<String, DateTime> _spoken = {};
  String? _languageCode;

  Future<void> init({required String languageCode}) async {
    await setLanguage(languageCode);
    await _tts.setSpeechRate(.48);
  }

  Future<void> setLanguage(String languageCode) async {
    if (languageCode != 'ar' && languageCode != 'en') {
      throw ArgumentError.value(languageCode, 'languageCode');
    }
    if (_languageCode == languageCode) return;
    final locale = languageCode == 'ar' ? 'ar' : 'en-US';
    if (await _tts.isLanguageAvailable(locale) != true) {
      throw StateError('Install an offline ${languageCode == 'ar' ? 'Arabic' : 'English (US)'} TTS voice');
    }
    await _tts.stop();
    await _tts.setLanguage(locale);
    _languageCode = languageCode;
  }

  Future<void> speak(String text, {bool urgent = false}) async {
    if (text.isEmpty) return;
    final now = DateTime.now();
    if (_spoken[text] != null && now.difference(_spoken[text]!).inMilliseconds < 2500) return;
    _spoken[text] = now;
    if (urgent) await _tts.stop();
    await _tts.speak(text);
  }
  Future<void> stop() async { await _tts.stop(); }
}
