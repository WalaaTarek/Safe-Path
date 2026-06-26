from fastapi import APIRouter, UploadFile, File, Form, HTTPException
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

router = APIRouter()
    

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

reader = easyocr.Reader(
    ['ar', 'en'],
    gpu=False,
    model_storage_directory="C:\easyocr_models"
)

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
    text = re.sub(r'[^\u0600-\u06FFa-zA-Z0-9\s\n.,!?():;/%-]', '', text)
    text = re.sub(r'(.)\1{2,}', r'\1', text)
    text = re.sub(r'\s+', ' ', text)

    lines = text.split("\n")
    cleaned = [line.strip() for line in lines if len(line.strip()) > 2]

    return "\n".join(cleaned)

def smart_image_reader(path):
    try:
        print("Trying EasyOCR...")
        easy_text = clean_text(read_image_easy(path))
        print("EasyOCR:", easy_text)

        if len(easy_text.strip()) > 10:
            return easy_text

    except Exception as e:
        print("EasyOCR Error:", e)

    try:
        print("Trying Tesseract...")
        tess_text = clean_text(read_image_tesseract(path))
        print("Tesseract:", tess_text)
        return tess_text

    except Exception as e:
        print("Tesseract Error:", e)

    return "Could not read text"

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
        poppler_path=r"C:\Release-25.12.0-0\poppler-25.12.0\Library\bin"
    )

    total_pages = info["Pages"]

    for i in range(1, total_pages + 1):
        try:
            page = convert_from_path(
                path,
                first_page=i,
                last_page=i,
                dpi=180,
                poppler_path=r"C:\Release-25.12.0-0\poppler-25.12.0\Library\bin"
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


def read_file(path):
    if path.lower().endswith((".png", ".jpg", ".jpeg")):
        return smart_image_reader(path)

    elif path.lower().endswith(".pdf"):
        return read_pdf(path)

    return "Unsupported file type"

@router.post("/upload")
async def upload(
    file: UploadFile = File(...)
):
    file_path = os.path.join(
        UPLOAD_FOLDER,
        file.filename
    )

    try:
        contents = await file.read()

        with open(file_path, "wb") as buffer:
            buffer.write(contents)

        result = read_file(file_path)

        return {
            "text": result
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )

    finally:
        if os.path.exists(file_path):
            os.remove(file_path)

@router.post("/ocr")
async def ocr(
    file: UploadFile = File(...),
    translate: bool = Form(False)
):
    file_path = os.path.join(
        UPLOAD_FOLDER,
        file.filename
    )

    try:
        contents = await file.read()

        with open(file_path, "wb") as buffer:
            buffer.write(contents)

        result = read_file(file_path)

        if not result:
            result = "No text detected"

        if translate:
            result = translate_text(result)

        try:
            result = summarize_if_large(
                result,
                len(result.split())
            )
        except Exception:
            pass

        return {
            "text": result
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )

    finally:
        if os.path.exists(file_path):
            os.remove(file_path)
