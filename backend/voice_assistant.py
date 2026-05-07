import asyncio
import edge_tts
import tempfile
import os
from playsound import playsound
from langdetect import detect
import re
import threading


class VoiceAssistant:

    def __init__(self):

        self.is_speaking = False

        # أصوات احترافية
        self.ar_voice = "ar-EG-SalmaNeural"
        self.en_voice = "en-US-JennyNeural"

    # ====================================
    # Detect Language
    # ====================================
    def detect_language(self, text):

        try:
            lang = detect(text)

            if lang.startswith("ar"):
                return "ar"

            return "en"

        except:
            return "en"

    # ====================================
    # Clean Text
    # ====================================
    def clean_text(self, text):

        text = re.sub(r'\s+', ' ', text)

        return text.strip()

    # ====================================
    # Generate Speech
    # ====================================
    async def generate_speech(self, text, voice, output_file):

        communicate = edge_tts.Communicate(
            text=text,
            voice=voice,
            rate="+0%"
        )

        await communicate.save(output_file)

    # ====================================
    # Play Audio
    # ====================================
    def play_audio(self, path):

        try:
            playsound(path)

        finally:

            self.is_speaking = False

            if os.path.exists(path):
                os.remove(path)

    # ====================================
    # Speak
    # ====================================
    def speak(self, text):

        if not text.strip():
            return

        self.is_speaking = True

        text = self.clean_text(text)

        lang = self.detect_language(text)

        # اختيار الصوت
        if lang == "ar":
            voice = self.ar_voice
        else:
            voice = self.en_voice

        try:

            temp_file = tempfile.NamedTemporaryFile(
                delete=False,
                suffix=".mp3"
            )

            temp_path = temp_file.name
            temp_file.close()

            asyncio.run(
                self.generate_speech(
                    text,
                    voice,
                    temp_path
                )
            )

            threading.Thread(
                target=self.play_audio,
                args=(temp_path,),
                daemon=True
            ).start()

        except Exception as e:
            print("Speech Error:", e)

    # ====================================
    # Stop
    # ====================================
    def stop(self):

        self.is_speaking = False