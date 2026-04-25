from flask import Flask, request, jsonify, render_template
import os
import cv2
import numpy as np
from PIL import Image
import pytesseract
from pdf2image import convert_from_path
import easyocr
import re

from translator import translate_text
from summarizer import summarize_if_large

# 🔗 Tesseract path
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

# 🔥 EasyOCR
reader = easyocr.Reader(
    ['ar', 'en'],
    gpu=False,
    model_storage_directory="E:\\easyocr_models"
)

# ================= IMAGE PREPROCESS =================
def preprocess_image(pil_image):
    img = np.array(pil_image)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    _, thresh = cv2.threshold(blur, 150, 255, cv2.THRESH_BINARY)
    return thresh

# ================= OCR =================
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

def clean_text(text):
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
    try:
        text = clean_text(read_image_easy(path))
        if len(text.strip()) > 10:
            return text
    except:
        pass

    try:
        text = clean_text(read_image_tesseract(path))
        return text
    except:
        return "❌ Could not read text"

# ================= PDF =================
def read_pdf(path):
    full_text = ""

    from pdf2image import pdfinfo_from_path

    info = pdfinfo_from_path(
        path,
        poppler_path=r"E:\Downloads\Release-25.12.0-0\poppler-25.12.0\Library\bin"
    )

    max_pages = info["Pages"]

    for i in range(1, max_pages + 1):
        page = convert_from_path(
            path,
            first_page=i,
            last_page=i,
            dpi=70,
            poppler_path=r"E:\Downloads\Release-25.12.0-0\poppler-25.12.0\Library\bin"
        )[0]

        img = np.array(page)
        img = cv2.resize(img, None, fx=0.5, fy=0.5)

        text = clean_text("\n".join(reader.readtext(img, detail=0)))

        full_text += f"\n--- Page {i} ---\n{text}"

    return full_text

# ================= FILE HANDLER =================
def read_file(path):
    if path.lower().endswith((".png", ".jpg", ".jpeg" ,".webp")):
        return smart_image_reader(path)

    elif path.lower().endswith(".pdf"):
        return read_pdf(path)

    return "Unsupported file type"

# ================= FLASK APP =================
app = Flask(__name__)

UPLOAD_FOLDER = "E:/uploads"
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

@app.route("/")
def home():
    return render_template("index.html")

# ================= UPLOAD =================
@app.route("/upload", methods=["POST"])
def upload():
    file = request.files["file"]
    translate_flag = request.form.get("translate")

    path = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(path)

    try:
        result = read_file(path)

        if translate_flag == "true":
            result = translate_text(result)

        return render_template("index.html", text=result)

    finally:
        if os.path.exists(path):
            os.remove(path)

# ================= OCR API =================
@app.route("/ocr", methods=["POST"])
def ocr():
    if "file" not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files["file"]
    translate_flag = request.form.get("translate")

    path = os.path.join(app.config['UPLOAD_FOLDER'], file.filename)
    file.save(path)

    try:
        result = read_file(path)

        pages_count = result.count("--- Page")

        result = summarize_if_large(result, pages_count)

        if translate_flag == "true":
            result = translate_text(result)

        return jsonify({"text": result})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    finally:
        if os.path.exists(path):   
            os.remove(path)

# ================= RUN =================
if __name__ == "__main__":
    app.run(debug=True)
