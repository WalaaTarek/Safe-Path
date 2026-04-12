import 'package:flutter_tts/flutter_tts.dart';

class TtsManager {
  final FlutterTts flutterTts = FlutterTts();

  String _lastText = "";
  bool _isSpeaking = false;

  TtsManager() {
    flutterTts.setLanguage("en-US");
    flutterTts.setSpeechRate(0.5);

    flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    flutterTts.setCancelHandler(() {
      _isSpeaking = false;
    });

    flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
    });
  }

  Future<void> speak(String text) async {
    
    if (text == _lastText) return;

    _lastText = text;

    try {
    
      if (_isSpeaking) {
        await flutterTts.stop();
        _isSpeaking = false;
      }

      _isSpeaking = true;
      await flutterTts.speak(text);

    } catch (e) {
      _isSpeaking = false;
      print("TTS error: $e");
    }
  }
}