from fastapi import FastAPI, File, UploadFile
from ultralytics import YOLO
import numpy as np
import cv2

app = FastAPI()

model = YOLO("yolov8m.pt")

@app.post("/detect")
async def detect(file: UploadFile = File(...)):
    try:
        image_bytes = await file.read()
        nparr = np.frombuffer(image_bytes, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if frame is None:
            return {"objects": []}

        frame = cv2.convertScaleAbs(frame, alpha=1.1, beta=10)

        results = model(frame)[0]

        objects = []

        for box in results.boxes:
            conf = float(box.conf[0])
            cls_id = int(box.cls[0])

            if conf > 0.5:
                name = model.names[cls_id]
                objects.append(name)

        return {"objects": list(set(objects))}

    except Exception as e:
        print("Error:", e)
        return {"objects": []}