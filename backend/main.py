from fastapi import FastAPI, File, UploadFile
from ultralytics import YOLO
import numpy as np
import cv2

app = FastAPI()

model = YOLO("yolov8m.pt")



def get_direction(x1, x2, frame_width):
    center = (x1 + x2) / 2

    if center < frame_width / 3:
        return "on the left"
    elif center < 2 * frame_width / 3:
        return "in the center"
    else:
        return "on the right"



def generate_description(objects):
    if not objects:
        return "The path ahead seems clear."

    if len(objects) == 1:
        return f"There is a {objects[0]}."

    return "There are " + ", ".join(objects[:-1]) + " and " + objects[-1] + "."


@app.post("/detect")
async def detect(file: UploadFile = File(...)):
    try:
        image_bytes = await file.read()
        nparr = np.frombuffer(image_bytes, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if frame is None:
            return {
                "objects": [],
                "description": "No image detected"
            }

     
        frame = cv2.convertScaleAbs(frame, alpha=1.1, beta=10)

        results = model(frame)[0]

        h, w, _ = frame.shape  
        objects = []

        for box in results.boxes:
            conf = float(box.conf[0])
            cls_id = int(box.cls[0])

            if conf > 0.3: 
                name = model.names[cls_id]

                x1, y1, x2, y2 = box.xyxy[0]

                direction = get_direction(x1, x2, w)

                objects.append(f"{name} {direction}")

     
        objects = list(set(objects))

        description = generate_description(objects)

        return {
            "objects": objects,
            "description": description
        }

    except Exception as e:
        print("Error:", e)
        return {
            "objects": [],
            "description": "Error processing image"
        }