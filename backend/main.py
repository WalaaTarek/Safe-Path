from fastapi import FastAPI, File, UploadFile
from ultralytics import YOLO
import numpy as np
import cv2

app = FastAPI()

model = YOLO("models/yolov8m.pt")

DANGEROUS_OBJECTS = {
    "high": [
        "car", "truck", "bus", "motorcycle", "bicycle",
        "train", "boat", "airplane"
    ],
    "medium": [
        "person", "dog", "cat", "horse", "cow",
        "sheep", "bear", "elephant"
    ],
    "low": [
        "chair", "bench", "potted plant", "fire hydrant",
        "stop sign", "parking meter", "suitcase", "backpack"
    ]
}


def get_direction(x1, x2, frame_width):
    center = (x1 + x2) / 2
    if center < frame_width / 3:
        return "on the left"
    elif center < 2 * frame_width / 3:
        return "in the center"
    else:
        return "on the right"


def get_distance(x1, y1, x2, y2, frame_area):
    box_area = (x2 - x1) * (y2 - y1)
    ratio = box_area / frame_area
    if ratio > 0.2:
        return "very close"
    elif ratio > 0.1:
        return "close"
    else:
        return "far"


def get_danger_level(name, distance):

    if distance == "very close":
        for level, objects in DANGEROUS_OBJECTS.items():
            if name in objects:
                return level
    return None


def generate_warning_message(name, direction, danger_level):
    if danger_level == "high":
        return f"Warning! {name} very close {direction}, move away immediately"
    elif danger_level == "medium":
        return f"Warning! {name} very close {direction}, be careful"
    return None


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
                "description": "No image detected",
                "response_type": "error",
                "has_high_danger": False
            }

        frame = cv2.convertScaleAbs(frame, alpha=1.1, beta=10)
        results = model(frame)[0]

        h, w, _ = frame.shape
        frame_area = w * h

        objects = []
        high_priority_warnings = []
        medium_priority_warnings = []
        seen_labels = set()

        for box in results.boxes:
            conf = float(box.conf[0])
            cls_id = int(box.cls[0])

            if conf > 0.3:
                name = model.names[cls_id]
                x1, y1, x2, y2 = box.xyxy[0]

                direction = get_direction(x1, x2, w)
                distance = get_distance(x1, y1, x2, y2, frame_area)

                label = f"{name} {direction} ({distance})"

                if label not in seen_labels:
                    seen_labels.add(label)
                    objects.append(label)

                    danger_level = get_danger_level(name, distance)
                    if danger_level:
                        warning_msg = generate_warning_message(
                            name, direction, danger_level
                        )
                        if warning_msg:
                            if danger_level == "high":
                                high_priority_warnings.append(warning_msg)
                            else:
                                medium_priority_warnings.append(warning_msg)

        description = generate_description(objects)

        all_warnings = (
            high_priority_warnings +
            medium_priority_warnings
        )

        if all_warnings:
            warnings_text = " Also, ".join(all_warnings)
            description = warnings_text + ". " + description
        response_type = "clear"
        if high_priority_warnings:
            response_type = "high_danger"
        elif medium_priority_warnings:
            response_type = "medium_danger"

        return {
            "description": description,
            "response_type": response_type,
            "has_high_danger": bool(high_priority_warnings)
        }

    except Exception as e:
        print("Error:", e)
        return {
            "description": "Error processing image",
            "response_type": "error",
            "has_high_danger": False
        }