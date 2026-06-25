import 'package:Safepath/services/language_manager.dart';

class LanguageStrings {

  static Map<String, String> arabic = {

    "welcome": "مرحبا بك في تطبيق سيف باث",
    "login": "تسجيل الدخول",
    "signup": "إنشاء حساب",
    "email": "البريد الإلكتروني",
    "password": "كلمة المرور",
    "signIn": "دخول",
    "createAccount": "إنشاء حساب",
    "or": "أو",

    
    "joinToday": "انضم إلى SafePath اليوم",
    "fullName": "الاسم الكامل",
    "yourName": "اسمك",

    "loginSuccess": "تم تسجيل الدخول بنجاح",
    "loginFailed": "فشل تسجيل الدخول",
    "connectionError": "خطأ في الاتصال",
    "listening": "جاري الاستماع... قل اسم الخاصية",
"navigating": "جاري الانتقال",
"commandNotRecognized": "لم يتم التعرف على الأمر",

"camera": "الكاميرا",
"money": "العملات",
"person": "الأشخاص",
"history": "السجل",
"settings": "الإعدادات",
"upload": "رفع ملف",

  
  };


  static Map<String, String> english = {

    "welcome": "Welcome to SafePath",
    "login": "Login",
    "signup": "Sign Up",
    "email": "Email",
    "password": "Password",
    "signIn": "Sign In",
    "createAccount": "Create Account",
    "or": "or",

    "joinToday": "Join SafePath today",
    "fullName": "FULL NAME",
    "yourName": "Your name",

    "loginSuccess": "Login successful.",
    "loginFailed": "Login failed.",
    "connectionError": "Connection error.",
    "listening": "Listening... Say tab name",
"navigating": "Navigating",
"commandNotRecognized": "Command not recognized",

"camera": "Camera",
"money": "Money",
"person": "Person",
"history": "History",
"settings": "Settings",
"upload": "Upload",

  };



  static String get(String key){

    if(LanguageManager.isArabic){

      return arabic[key] ?? key;

    }else{

      return english[key] ?? key;

    }

  }

}