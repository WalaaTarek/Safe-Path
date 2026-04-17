from flask import Flask, request, jsonify
import os
import cv2
import numpy as np
from PIL import Image
import pytesseract
from pdf2image import convert_from_path
import easyocr
import re
from flask import render_template
# 🔗 Tesseract path
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
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
    full_text = ""

    from pdf2image import pdfinfo_from_path

    info = pdfinfo_from_path(
        path,
        poppler_path=r"E:\Release-25.12.0-0\poppler-25.12.0\Library\bin"
    )

    max_pages = info["Pages"]

    for i in range(1, max_pages + 1):
        print(f"Processing page {i}...")

        page = convert_from_path(
            path,
            first_page=i,
            last_page=i,
            dpi=70,
            poppler_path=r"E:\Release-25.12.0-0\poppler-25.12.0\Library\bin"
        )[0]

        img = np.array(page)
        img = cv2.resize(img, None, fx=0.5, fy=0.5)
        easy_result = reader.readtext(img, detail=0)
        easy_text = clean_text("\n".join(easy_result))

        full_text += f"\n--- Page {i} ---\n{easy_text}"

        del img, page

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
    return render_template("index.html")
@app.route("/upload", methods=["POST"])
def upload():
    file = request.files["file"]
    file_path = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(file_path)

    try:
        result = read_file(file_path)
        return render_template("index.html", text=result)

    finally:
        if os.path.exists(file_path):
            os.remove(file_path)
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
