from deep_translator import GoogleTranslator

def translate_text(text, target="ar"):
    try:
        translated = GoogleTranslator(source='auto', target=target).translate(text)
        return translated
    except Exception as e:
        return f"Translation Error: {str(e)}"