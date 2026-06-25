import 'package:shared_preferences/shared_preferences.dart';

class LanguageManager {

  static String currentLanguage = "en";


  // حفظ اللغة
  static Future<void> saveLanguage(String language) async {

    currentLanguage = language;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      "language",
      language,
    );
  }



  // جلب اللغة المحفوظة
  static Future<String> getLanguage() async {

    final prefs = await SharedPreferences.getInstance();

    currentLanguage = prefs.getString(
      "language",
    ) ?? "en";

    return currentLanguage;
  }



  // تحميل اللغة عند بداية التطبيق
  static Future<void> loadLanguage() async {

    await getLanguage();

  }



  // هل اللغة عربية؟
  static bool get isArabic {

    return currentLanguage == "ar";

  }



  // هل اللغة إنجليزية؟
  static bool get isEnglish {

    return currentLanguage == "en";

  }

}