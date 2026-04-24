from flask import Flask, request, jsonify
from ultralytics import YOLO
import numpy as np
import cv2
import gdown
import os


app = Flask(__name__)
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

@app.route("/")
def home():
    return "YOLO API Running"

@app.route("/predict", methods=["POST"])
def predict():
    file = request.files["image"]

    img = cv2.imdecode(
        np.frombuffer(file.read(), np.uint8),
        cv2.IMREAD_COLOR
    )

    results = model(img)

    output = []

    for r in results:
        for box in r.boxes:
            output.append({
                "class": model.names[int(box.cls[0])],
                "confidence": float(box.conf[0])
            })

    return jsonify(output)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)