import os
import cv2
import gdown
import numpy as np
from fastapi import APIRouter, File, UploadFile
from fastapi.responses import JSONResponse

from ultralytics import YOLO

router = APIRouter()


MODEL_PATH = "models/best.pt"
FILE_ID = "1y41vbrMYa1C_8-PcejRUxEpnGtlCo5LT"


def download_model():
    if not os.path.exists(MODEL_PATH):
        os.makedirs("models", exist_ok=True)
        print("Downloading model...")
        gdown.download(
            f"https://drive.google.com/uc?id={FILE_ID}",
            MODEL_PATH,
            quiet=False
        )
        print("Model downloaded!")

download_model()
model = YOLO(MODEL_PATH)

@router.post("/predict")
async def predict(image: UploadFile = File(...)):
    try:
        image_bytes = await image.read()

        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
            return JSONResponse(status_code=400, content={"error": "Invalid image format"})


        results = model(img)

        output = []
        for r in results:
            for box in r.boxes:
                output.append({
                    "class": model.names[int(box.cls[0])],
                    "confidence": float(box.conf[0])
                })

        return output

    except Exception as e:
        return JSONResponse(status_code=500, content={"error": f"Internal Server Error: {str(e)}"})
