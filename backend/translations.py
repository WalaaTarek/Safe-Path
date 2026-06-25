# translations.py


# =========================
# Objects Translation
# =========================

OBJECTS_AR = {

    "person": "شخص",
    "bicycle": "دراجة",
    "car": "سيارة",
    "motorcycle": "دراجة نارية",
    "airplane": "طائرة",
    "bus": "أتوبيس",
    "train": "قطار",
    "truck": "شاحنة",
    "boat": "قارب",

    "traffic light": "إشارة مرور",
    "fire hydrant": "صنبور إطفاء",
    "stop sign": "علامة توقف",
    "parking meter": "عداد موقف",

    "bench": "مقعد",
    "bird": "طائر",
    "cat": "قطة",
    "dog": "كلب",
    "horse": "حصان",
    "sheep": "خروف",
    "cow": "بقرة",

    "backpack": "حقيبة ظهر",
    "umbrella": "مظلة",
    "handbag": "حقيبة يد",
    "suitcase": "حقيبة سفر",

    "bottle": "زجاجة",
    "cup": "كوب",
    "fork": "شوكة",
    "knife": "سكين",
    "spoon": "ملعقة",
    "bowl": "وعاء",

    "banana": "موز",
    "apple": "تفاح",
    "orange": "برتقال",
    "sandwich": "شطيرة",
    "pizza": "بيتزا",

    "chair": "كرسي",
    "couch": "أريكة",
    "potted plant": "نبات",
    "bed": "سرير",
    "dining table": "طاولة",

    "tv": "تلفاز",
    "laptop": "لابتوب",
    "cell phone": "هاتف",
    "keyboard": "لوحة مفاتيح",
    "mouse": "فأرة",

    "book": "كتاب",
    "clock": "ساعة",
    "vase": "مزهرية",

    # إضافات مهمة للمكفوفين
    "stairs": "سلم",
    "door": "باب",
    "window": "نافذة",
    "wall": "حائط",
    "pothole": "حفرة",
    "obstacle": "عائق"

}



# =========================
# Reverse Arabic Objects
# =========================

OBJECTS_REVERSE_AR = {

    arabic: english

    for english, arabic in OBJECTS_AR.items()

}



# =========================
# Direction Translation
# =========================

DIRECTION_AR = {

    "on the left": "على اليسار",

    "in the center": "أمامك مباشرة",

    "on the right": "على اليمين"

}



# =========================
# Distance Translation
# =========================

DISTANCE_AR = {

    "very close": "قريب جداً",

    "close": "قريب",

    "far": "بعيد"

}



# =========================
# Tabs Translation
# =========================

TAB_AR = {

    "camera": "الكاميرا",

    "money": "النقود",

    "person": "الأشخاص",

    "history": "السجل",

    "settings": "الإعدادات",

    "upload": "رفع الملفات"

}



# =========================
# General Messages
# =========================

MESSAGES_AR = {

    "clear":
        "الطريق أمامك واضح",

    "no_object":
        "لم يتم اكتشاف أي شيء",

    "error":
        "حدث خطأ أثناء المعالجة",

    "listening":
        "أنا أستمع الآن",

    "opening":
        "جاري الفتح"

}



# =========================
# Voice Commands Arabic
# =========================

VOICE_COMMANDS_AR = {

    "camera": [

        "كاميرا",
        "افتح الكاميرا",
        "شغل الكاميرا",
        "مسح",
        "كشف",
        "تصوير"

    ],


    "money": [

        "فلوس",
        "نقود",
        "عملة",
        "اقرأ الفلوس",
        "اعرف النقود"

    ],


    "person": [

        "شخص",
        "إنسان",
        "ناس",
        "حد",
        "مين قدامي"

    ],


    "history": [

        "السجل",
        "التاريخ",
        "العمليات السابقة"

    ],


    "settings": [

        "الإعدادات",
        "الضبط",
        "الخيارات"

    ],


    "upload": [

        "رفع",
        "تحميل ملف",
        "ارفع صورة"

    ]

}



# =========================
# Translation Functions
# =========================


def translate_object(name, language="en"):

    if language == "ar":

        return OBJECTS_AR.get(
            name,
            name
        )

    return name



def translate_direction(direction, language="en"):

    if language == "ar":

        return DIRECTION_AR.get(
            direction,
            direction
        )

    return direction



def translate_distance(distance, language="en"):

    if language == "ar":

        return DISTANCE_AR.get(
            distance,
            distance
        )

    return distance



def translate_tab(tab, language="en"):

    if language == "ar":

        return TAB_AR.get(
            tab,
            tab
        )

    return tab