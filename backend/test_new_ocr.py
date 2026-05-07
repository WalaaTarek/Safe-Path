from flask import Flask, request, jsonify, render_template
import os
import cv2
import numpy as np
from PIL import Image
import pytesseract
from pdf2image import convert_from_path, pdfinfo_from_path
import easyocr
import fitz
import re
import gc
from translator import translate_text
from summarizer import summarize_if_large
from voice_assistant import VoiceAssistant
from assistant_brain import AssistantBrain


# ================== App Setup ==================
app = Flask(__name__, template_folder="templates")

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

speaker = VoiceAssistant()


# ================== OCR Setup ==================
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

reader = easyocr.Reader(
    ['ar', 'en'],
    gpu=False,
    model_storage_directory="E:\\easyocr_models"
)


# ================== Image Processing ==================
def preprocess_image(pil_image):
    img = np.array(pil_image)

    if len(img.shape) == 2:
        gray = img
    else:
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # تكبير
    gray = cv2.resize(gray, None, fx=2.5, fy=2.5, interpolation=cv2.INTER_CUBIC)

    # إزالة نويز
    gray = cv2.fastNlMeansDenoising(gray, None, 30, 7, 21)

    # Sharpen
    kernel = np.array([[0, -1, 0],
                       [-1, 5,-1],
                       [0, -1, 0]])
    gray = cv2.filter2D(gray, -1, kernel)

    # Adaptive threshold
    thresh = cv2.adaptiveThreshold(
        gray, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        31, 11
    )

    return thresh


def read_image_easy(path):
    result = reader.readtext(path, detail=0)
    return "\n".join(result)


def read_image_tesseract(path):
    img = Image.open(path)
    processed = preprocess_image(img)

    return pytesseract.image_to_string(
        processed,
        lang='ara+eng',
        config='--oem 3 --psm 6'
    )


# ================== Text Cleaning ==================
def clean_text(text):
    text = re.sub(r'[^\u0600-\u06FFa-zA-Z0-9\s\n.,!?():;/%-]', '', text)

    # إزالة تكرار الحروف
    text = re.sub(r'(.)\1{2,}', r'\1', text)

    # إزالة المسافات الكثيرة
    text = re.sub(r'\s+', ' ', text)

    # إعادة السطور
    text = text.replace(" .", ".").replace(" ،", "،")

    lines = text.split("\n")
    cleaned = []

    for line in lines:
        line = line.strip()
        if len(line) > 2:
            cleaned.append(line)

    return "\n".join(cleaned)

# ================== Smart Reader For Images ==================
def smart_image_reader(path):
    try:
        easy_text = clean_text(read_image_easy(path))
        if easy_text and len(easy_text.strip()) > 10:
            return easy_text
    except Exception as e:
        print("EasyOCR failed:", e)

    try:
        tess_text = clean_text(read_image_tesseract(path))
        return tess_text
    except Exception as e:
        print("Tesseract failed:", e)

    return "❌ Could not read text"


# ================== Smart PDF Reader ==================
import gc

def read_pdf(path):
    full_text = ""

    try:
        doc = fitz.open(path)
        extracted = ""

        for page in doc:
            extracted += page.get_text()

        extracted = clean_text(extracted)

        if len(extracted.strip()) > 50:
            print("PDF contains selectable text -> Direct extraction used")
            return extracted

    except Exception as e:
        print("Direct PDF text extraction failed:", e)

    print("Scanned PDF detected -> Using OCR")

    info = pdfinfo_from_path(
        path,
        poppler_path=r"E:\Release-25.12.0-0\poppler-25.12.0\Library\bin"
    )

    total_pages = info["Pages"]

    for i in range(1, total_pages + 1):
        print(f"Processing page {i}/{total_pages}...")

        try:
            page = convert_from_path(
                path,
                first_page=i,
                last_page=i,
                dpi=180,
                poppler_path=r"E:\Release-25.12.0-0\poppler-25.12.0\Library\bin"
            )[0]

            img = np.array(page)
            processed = preprocess_image(Image.fromarray(img))

          # Tesseract first for documents
            text_tess = pytesseract.image_to_string(
                processed,
                lang='ara+eng',
                config='--oem 3 --psm 3'
            )
            text_tess = clean_text(text_tess)

            # EasyOCR backup
            text_easy = "\n".join(reader.readtext(processed, detail=0))
            text_easy = clean_text(text_easy)

            # choose better result
            if len(text_tess) >= len(text_easy):
                final_text = text_tess
            else:
                final_text = text_easy
            full_text += f"\n--- Page {i} ---\n{final_text}\n"

            del img, processed, page
            gc.collect()

        except Exception as e:
            print(f"Error processing page {i}: ", e)
            full_text += f"\n--- Page {i} ---\n[Could not process this page]\n"
            full_text = summarize_if_large(
                full_text,
                total_pages
            )
    return full_text
    # -------- OCR Fallback --------
    print("Scanned PDF detected -> Using OCR")

    info = pdfinfo_from_path(
        path,
        poppler_path=r"E:\Release-25.12.0-0\poppler-25.12.0\Library\bin"
    )

    total_pages = info["Pages"]

    for i in range(1, total_pages + 1):
        print(f"Processing page {i}/{total_pages}...")

        page = convert_from_path(
            path,
            first_page=i,
            last_page=i,
            dpi=180,
            poppler_path=r"E:\Release-25.12.0-0\poppler-25.12.0\Library\bin"
        )[0]

        img = np.array(page)
        processed = preprocess_image(Image.fromarray(img))

        text_easy = "\n".join(reader.readtext(processed, detail=0))
        text_easy = clean_text(text_easy)

        if len(text_easy.strip()) < 20:
            text_tess = pytesseract.image_to_string(
                processed,
                lang='ara+eng',
                config='--oem 3 --psm 6'
            )
            text_easy = clean_text(text_tess)

        full_text += f"\n--- Page {i} ---\n{text_easy}\n"

        del img, processed, page
        gc.collect()
    return full_text


# ================== File Router ==================
def read_file(path):
    if path.lower().endswith((".png", ".jpg", ".jpeg")):
        return smart_image_reader(path)

    elif path.lower().endswith(".pdf"):
        return read_pdf(path)

    return "Unsupported file type"


# ================== Routes ==================
@app.route("/")
def home():
    return render_template("index.html")


@app.route("/voice_command", methods=["POST"])
def voice_command():
    data = request.get_json()
    command = data.get("command", "").lower()

    if "translate" in command:
        reply = "Translation mode activated"

    elif "read" in command:
        reply = "Please upload or capture image or pdf"

    elif "stop" in command:
        speaker.stop()
        reply = "Voice stopped"

    else:
        reply = "Command not understood"

    speaker.speak(reply)
    return jsonify({"reply": reply})


@app.route("/upload", methods=["POST"])
def upload():
    file = request.files["file"]
    translate_flag = request.form.get("translate") == "true"

    file_path = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(file_path)

    try:
        result = brain.handle(
            command="read image",
            file_path=file_path,
            translate=translate_flag
        )

        if translate_flag:
            result = translate_text(result)

        return render_template("index.html", text=result)

    finally:
        if os.path.exists(file_path):
            os.remove(file_path)


@app.route("/ocr", methods=["POST"])
def ocr():
    if "file" not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files["file"]
    translate_flag = request.form.get("translate") == "true"

    file_path = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(file_path)

    try:
        result = read_file(file_path)

        if translate_flag:
            result = translate_text(result)

        return jsonify({"text": result})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    finally:
        if os.path.exists(file_path):
            os.remove(file_path)


# ================== Assistant Brain ==================
brain = AssistantBrain(
    ocr_service=read_file,
    translator=translate_text,
    speaker=speaker
)


# ================== Run ==================
if __name__ == "__main__":
    app.run(debug=False, threaded=True)
