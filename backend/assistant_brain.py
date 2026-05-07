class AssistantBrain:

    def __init__(self, ocr_service, translator, speaker):
        self.ocr = ocr_service
        self.translator = translator
        self.speaker = speaker

    def handle(self, command, file_path=None, translate=False):

        command = command.lower()

        # ================= OCR IMAGE =================
        if "image" in command or "read" in command:
            result = self.ocr(file_path)

        # ================= PDF =================
        elif "pdf" in command:
            result = self.ocr(file_path)

        # ================= TRANSLATE =================
        else:
            result = "Unknown command"

        if translate:
            result = self.translator(result)

        # 🔊 Voice Response
        self.speaker.speak(result)

        return result