from flask import Flask, request, jsonify
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



# ================== App Setup ==================
app = Flask(__name__)

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)



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

    gray = cv2.resize(gray, None, fx=2.5, fy=2.5, interpolation=cv2.INTER_CUBIC)
    gray = cv2.fastNlMeansDenoising(gray, None, 30, 7, 21)

    kernel = np.array([[0, -1, 0],
                       [-1, 5, -1],
                       [0, -1, 0]])
    gray = cv2.filter2D(gray, -1, kernel)

    thresh = cv2.adaptiveThreshold(
        gray, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        31, 11
    )

    return thresh


# ================== OCR Functions ==================
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
    text = re.sub(r'(.)\1{2,}', r'\1', text)
    text = re.sub(r'\s+', ' ', text)

    lines = text.split("\n")
    cleaned = [line.strip() for line in lines if len(line.strip()) > 2]

    return "\n".join(cleaned)


# ================== Smart Image Reader ==================
def smart_image_reader(path):
    try:
        easy_text = clean_text(read_image_easy(path))
        if len(easy_text.strip()) > 10:
            return easy_text
    except:
        pass

    try:
        return clean_text(read_image_tesseract(path))
    except:
        return "❌ Could not read text"


# ================== PDF Reader ==================
def read_pdf(path):
    full_text = ""

    try:
        doc = fitz.open(path)
        extracted = ""

        for page in doc:
            extracted += page.get_text()

        extracted = clean_text(extracted)

        if len(extracted.strip()) > 50:
            return extracted

    except:
        pass

    info = pdfinfo_from_path(
        path,
        poppler_path=r"E:\Release-25.12.0-0\poppler-25.12.0\Library\bin"
    )

    total_pages = info["Pages"]

    for i in range(1, total_pages + 1):
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

            text_tess = pytesseract.image_to_string(
                processed,
                lang='ara+eng',
                config='--oem 3 --psm 3'
            )

            text_easy = "\n".join(reader.readtext(processed, detail=0))

            text_tess = clean_text(text_tess)
            text_easy = clean_text(text_easy)

            final_text = text_tess if len(text_tess) >= len(text_easy) else text_easy

            full_text += f"\n--- Page {i} ---\n{final_text}\n"

            del img, processed, page
            gc.collect()

        except:
            full_text += f"\n--- Page {i} ---\n[Error]\n"

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
    return "OCR Backend Running"


# ------------------ UPLOAD (FIXED) ------------------
@app.route("/upload", methods=["POST"])
def upload():
    file = request.files["file"]

    file_path = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(file_path)

    try:
        result = read_file(file_path)

        return jsonify({
            "text": result
        })

    except Exception as e:
        return jsonify({
            "error": str(e)
        }), 500

    finally:
        if os.path.exists(file_path):
            os.remove(file_path)


# ------------------ OCR API (BEST FOR FLUTTER) ------------------
@app.route("/ocr", methods=["POST"])
def ocr():
    file = request.files.get("file")
    translate_flag = request.form.get("translate") == "true"

    if not file:
        return jsonify({"error": "No file uploaded"}), 400

    file_path = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(file_path)

    try:
        # 1️⃣ OCR
        result = read_file(file_path)

        # 2️⃣ Clean safety check
        if not result:
            result = "No text detected"

        # 3️⃣ Translate 
        if translate_flag:
            result = translate_text(result)

        # 4️⃣ Summarize 
        try:
            result = summarize_if_large(result, len(result.split()))
        except:
            pass

        
        return jsonify({
            "text": result
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    finally:
        if os.path.exists(file_path):
            os.remove(file_path)



# ================== Run ==================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False, threaded=True)
