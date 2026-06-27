import 'package:Safepath/services/language_manager.dart';

class LanguageStrings {
  static Map<String, String> arabic = {
    "welcome":
        " مرحبا بك في تطبيق سيف باث اضغط مطولًا على أي مكان في الشاشة لسماع تعليمات الاستخدام.",
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
    "settings": "الإعدادات",
    "upload": "رفع ملف",

    "moneyDetectionStarted": "بدأ كشف العملات",
    "noDetection": "لا يوجد كشف حتى الآن",
    "money_5": "خمسة جنيه",
    "money_10": "عشرة جنيه",
    "money_10 new": "عشرة جنيه ",
    "money_20": "عشرون جنيه",
    "money_20 new": "عشرون جنيه ",
    "money_50": "خمسون جنيه",
    "money_100": "مائة جنيه",
    "money_200": "مئتان جنيه",

    "helpInstructions":
        "طريقة استخدام التطبيق: "
        "يمكنك الضغط مطولاً أو النقر مرتين على الشاشة لتسجيل أوامر صوتية. "
        "للتنقل بين الميزات، قل كلمة افتح متبوعة باسم الميزة. "
        "التطبيق لديه أربع ميزات رئيسية: "
        "1 وصف المسار واكتشاف العوائق. "
        "2 كشف الأموال والعملات. "
        "3 التعرف على الوجوه والأشخاص. "
        "4 قراءة المستندات والملفات الذكية.",

    "longPressHint": "اضغط مطولاً على الشاشة لمعرفة طريقة الاستخدام.",

    "ocrScanner": "ماسح المستندات ",
    "noImageSelected": "لم يتم اختيار صورة بعد",
    "pickImage": "اختر صورة من الاستوديو",
    "translateToArabic": "ترجمة النص إلى العربية",
    "processing": "جاري المعالجة وقراءة النص...",
    "uploadBtn": "رفع وتحليل الصورة",
    "result": "النتيجة",
    "extractedText": "النص المترجم",
    "readAloud": "استماع للنص",

    "scanningFace": "جاري فحص الوجه...",
    "active": "سيف باث نشط",
    "voiceActive": "المساعد الصوتي نشط...",
    "unknownFace": "شخص غير معروف",
    "askSaveFace":
        "لم أتعرف على هذا الشخص. هل تريد حفظ هذا الوجه؟ قل نعم أو لا.",
    "askName": "من فضلك قل اسم الشخص.",
    "errorHearName": "عذرًا، لم أسمع الاسم بوضوح. يرجى المحاولة مرة أخرى.",
    "askDescription": "من فضلك قل وصفًا قصيرًا لهذا الشخص.",
    "noDescription": "لا يوجد وصف",
    "notSaved": "لم يتم حفظ الشخص.",
    "recognized": "تم التعرف عليه.",
    "askAction": "هل تريد تعديل أو حذف هذا الشخص؟ قل تعديل، حذف، أو لا.",
    "askEditChoice": "هل تريد تعديل الاسم أم الوصف؟",
    "askNewName": "من فضلك قل الاسم الجديد.",
    "nameUpdated": "تم تحديث الاسم",
    "askNewDescription": "من فضلك قل الوصف الجديد.",
    "descriptionUpdated": "تم تحديث الوصف",
    "invalidOption": "اختيار غير صحيح.",
    "askDeleteConfirm": "هل أنت متأكد أنك تريد حذف هذا الشخص؟ قل نعم أو لا.",
    "deleted": "تم الحذف",
    "removed": "تم إزالة الشخص",
    "deleteCancelled": "تم إلغاء الحذف.",
    "okay": "حسناً.",
    "saveSuccess": "تم الحفظ بنجاح.",
    "saveFailed": "فشل حفظ الشخص على الخادم.",
    "noFaceFrame": "لم يتم رصد وجه في الإطار",
    "verified": "تم التحقق",
    "serverError": "خطأ في الخادم",
    "updateSuccess": "تم التحديث بنجاح",
    "updateFailed": "فشل التحديث",
    "deleteSuccess": "تم الحذف بنجاح",
  };

  static Map<String, String> english = {
    "welcome":
        "Welcome to SafePath Long press anywhere on the screen for help instructions",
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
    "settings": "Settings",
    "upload": "Upload",

    "moneyDetectionStarted": "Money detection started",
    "noDetection": "No detection yet",
    "money_5": "5 pounds",
    "money_10": "10 pounds",
    "money_10 new": "10 pounds ",
    "money_20": "20 pounds",
    "money_20 new": "20 pounds ",
    "money_50": "50 pounds",
    "money_100": "100 pounds",
    "money_200": "200 pounds",

    "helpInstructions":
        "How to use the application: "
        "You can press and hold, or double-tap on the screen to record voice commands. "
        "To navigate between features, you must say the word OPEN followed by the feature name. "
        "The application has four main features: "
        "1, path description and obstacle detection. "
        "2, money and currency detection. "
        "3, face and people recognition. "
        "4, smart document and file reading.",

    "longPressHint": "Long press on the screen to learn how to use the app.",

    "ocrScanner": "OCR Scanner",
    "noImageSelected": "No Image Selected",
    "pickImage": "Pick Image",
    "translateToArabic": "Translate to Arabic",
    "processing": "Processing...",
    "uploadBtn": "Upload & Scan",
    "result": "Result",
    "extractedText": "Extracted Text",
    "readAloud": "Read Aloud",

    "scanningFace": "Scanning Face...",
    "active": "Safe-Path Active",
    "voiceActive": "Voice prompt active...",
    "unknownFace": "Unknown Face",
    "askSaveFace":
        "I don't recognize this person. Would you like to save this face? Say yes or no.",
    "askName": "Please tell me the person's name.",
    "errorHearName":
        "Sorry, I couldn't hear the name clearly. Please try again.",
    "askDescription": "Please provide a short description for this person.",
    "noDescription": "No description",
    "notSaved": "Person not saved.",
    "recognized": "recognized.",
    "askAction":
        "Would you like to edit or delete this person? Say edit, delete, or no.",
    "askEditChoice": "Would you like to edit name or description?",
    "askNewName": "Please say the new name.",
    "nameUpdated": "Name Updated",
    "askNewDescription": "Please say the new description.",
    "descriptionUpdated": "Description Updated",
    "invalidOption": "Invalid option.",
    "askDeleteConfirm":
        "Are you sure you want to delete this person? Say yes or no.",
    "deleted": "Deleted",
    "removed": "removed",
    "deleteCancelled": "Delete cancelled.",
    "okay": "Okay.",
    "saveSuccess": "has been saved successfully.",
    "saveFailed": "Failed to save person on the server.",
    "noFaceFrame": "No face detected in frame",
    "verified": "Verified",
    "serverError": "Server Error",
    "updateSuccess": "Person updated successfully",
    "updateFailed": "Failed to update person",
    "deleteSuccess": "Person deleted successfully",
  };

  static String get(String key) {
    if (LanguageManager.isArabic) {
      return arabic[key] ?? key;
    } else {
      return english[key] ?? key;
    }
  }
}
