import 'package:flutter_tts/flutter_tts.dart';
import 'package:Safepath/services/language_manager.dart';


class TtsManager {

  final FlutterTts _tts = FlutterTts();

  String _lastText = "";

  bool _isSpeaking = false;



  TtsManager() {

    _initialize();

  }





  Future<void> _initialize() async {


    await _tts.setLanguage(

      LanguageManager.isArabic

          ? "ar-SA"

          : "en-US",

    );


    await _tts.setSpeechRate(0.5);


    await _tts.setVolume(1.0);




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







  Future<void> setLanguage(String languageCode) async {


    await _tts.setLanguage(

      languageCode,

    );


  }








  Future<void> speak(String text) async {


    if (text.isEmpty) return;



    // تحديث اللغة قبل كل نطق

    await _tts.setLanguage(

      LanguageManager.isArabic

          ? "ar-SA"

          : "en-US",

    );




    if (text == _lastText) return;



    _lastText = text;



    if (_isSpeaking) {

      await _tts.stop();

    }



    _isSpeaking = true;



    await _tts.speak(

      text,

    );


  }


  Future<void> speakAndWait(String text) async {


    if (text.isEmpty) return;



    // تحديث اللغة قبل النطق

    await _tts.setLanguage(

      LanguageManager.isArabic

          ? "ar-SA"

          : "en-US",

    );




    if (_isSpeaking) {

      await _tts.stop();

    }



    _isSpeaking = true;



    await _tts.speak(

      text,

    );


    while (_isSpeaking) {


      await Future.delayed(

        const Duration(milliseconds: 100),

      );


    }


  }







  Future<void> stop() async {


    await _tts.stop();


    _isSpeaking = false;


  }


}