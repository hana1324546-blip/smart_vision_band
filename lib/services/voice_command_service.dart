import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceCommandService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  Future<bool>? _initialization;

  Future<String?> listenForArabicCommand() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) throw StateError('Microphone permission is required for voice commands');
    final available = await (_initialization ??= _speech.initialize());
    if (!available) throw StateError('Arabic speech recognition is unavailable on this device');

    final result = Completer<String?>();
    await _speech.listen(
      localeId: 'ar_SA',
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 2),
      listenMode: stt.ListenMode.confirmation,
      partialResults: false,
      cancelOnError: true,
      onResult: (value) {
        if (value.finalResult && !result.isCompleted) {
          result.complete(value.recognizedWords);
        }
      },
    );

    try {
      return await result.future.timeout(const Duration(seconds: 10), onTimeout: () => null);
    } finally {
      if (_speech.isListening) await _speech.stop();
    }
  }

  Future<void> stop() async {
    if (_speech.isListening) await _speech.stop();
  }
}