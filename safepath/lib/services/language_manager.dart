import 'package:shared_preferences/shared_preferences.dart';

class LanguageManager {
  static String currentLanguage = "en";

  static Future<void> saveLanguage(String language) async {
    currentLanguage = language;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("language", language);
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();

    currentLanguage = prefs.getString("language") ?? "en";

    return currentLanguage;
  }

  static Future<void> loadLanguage() async {
    await getLanguage();
  }

  static bool get isArabic {
    return currentLanguage == "ar";
  }

  static bool get isEnglish {
    return currentLanguage == "en";
  }
}
