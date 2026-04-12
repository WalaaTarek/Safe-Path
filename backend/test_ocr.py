from flask import Flask, request, jsonify
import os
import cv2
import numpy as np
from PIL import Image
import pytesseract
from pdf2image import convert_from_path
import easyocr
import re

# 🔗 Tesseract path
pytesseract.pytesseract.tesseract_cmd = r"F:\Tesseract_OCR\tesseract.exe"

# 🔥 EasyOCR (MAIN)
reader = easyocr.Reader(
    ['ar', 'en'],
    gpu=False,
    model_storage_directory="E:\\easyocr_models"
)

def preprocess_image(pil_image):
    img = np.array(pil_image)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    _, thresh = cv2.threshold(blur, 150, 255, cv2.THRESH_BINARY)
    return thresh

# ====== EasyOCR ======
def read_image_easy(path):
    result = reader.readtext(path, detail=0)
    return "\n".join(result)

# ====== Tesseract (Backup) ======
def read_image_tesseract(path):
    img = Image.open(path)
    processed = preprocess_image(img)
    return pytesseract.image_to_string(
        processed,
        lang='ara+eng',
        config='--oem 3 --psm 6'
    )

def clean_text(text):
    # حذف الرموز الغريبة
    text = re.sub(r'[^\u0600-\u06FFa-zA-Z0-9\s\n.,!?]', '', text)

    lines = text.split("\n")
    cleaned = []

    for line in lines:
        line = line.strip()

        if not line or line.isdigit() or len(line) < 3:
            continue

        if line not in cleaned:
            cleaned.append(line)

    return "\n".join(cleaned)

def smart_image_reader(path):
    easy_text = clean_text(read_image_easy(path))

    if len(easy_text) > 20:
        return easy_text

    tess_text = clean_text(read_image_tesseract(path))
    return tess_text

# ====== PDF ======
def read_pdf(path):
    pages = convert_from_path(
        path,
        poppler_path=r"E:\Downloads\Release-25.12.0-0\poppler-25.12.0\Library\bin"
    )

    full_text = ""

    for i, page in enumerate(pages):
        img = np.array(page)

        # EasyOCR 
        easy_result = reader.readtext(img, detail=0)
        easy_text = clean_text("\n".join(easy_result))

        # fallback
        if len(easy_text) < 20:
            tess_text = pytesseract.image_to_string(img, lang='ara+eng')
            best = clean_text(tess_text)
        else:
            best = easy_text

        full_text += f"\n--- Page {i+1} ---\n{best}"

    return full_text

# ====== Detect ======
def read_file(path):
    if path.lower().endswith((".png", ".jpg", ".jpeg")):
        return smart_image_reader(path)

    elif path.lower().endswith(".pdf"):
        return read_pdf(path)

    else:
        return "Unsupported file type"

# ====== API ======
app = Flask(__name__)

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

@app.route("/")
def home():
    return "OCR API is running 🚀"

@app.route("/ocr", methods=["POST"])
def ocr():
    if "file" not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files["file"]
    file_path = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(file_path)

    try:
        result = read_file(file_path)
        return jsonify({"text": result})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    finally:
        if os.path.exists(file_path):
            os.remove(file_path)

if __name__ == "__main__":
    app.run(debug=True)
