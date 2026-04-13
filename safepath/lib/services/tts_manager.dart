import 'package:flutter_tts/flutter_tts.dart';

class TtsManager {
  final FlutterTts _tts = FlutterTts();

  String _lastText = "";
  bool _isSpeaking = false;

  TtsManager() {
    _tts.setLanguage("en-US");
    _tts.setSpeechRate(0.5);
    _tts.setVolume(1.0);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

   
    if (text == _lastText) return;
    _lastText = text;

    if (_isSpeaking) return;

    _isSpeaking = true;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }
}