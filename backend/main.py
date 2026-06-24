from fastapi import FastAPI, File, UploadFile
from ultralytics import YOLO
import numpy as np
import cv2
import io
import speech_recognition as sr

app = FastAPI()
model = YOLO("models/bestlast.pt")

DANGEROUS_OBJECTS = {
    "high": ["car", "truck", "bus", "pothole", "obstacle"],
    "medium": ["person", "dog", "chair"],
    "low": ["potted plant", "bench"]
}
TAB_KEYWORDS = {
    "camera": ["camera", "scan", "detect"],
    "money": ["money", "cash", "currency"],
    "person": ["person", "face", "people"],
    "history": ["history", "past", "logs"],
    "settings": ["settings", "options"],
    "upload": ["upload", "file"]
}

def transcribe_audio(audio_bytes: bytes) -> str:
    r = sr.Recognizer()
    try:
        audio_file = io.BytesIO(audio_bytes)
        with sr.AudioFile(audio_file) as source:
            audio_data = r.record(source)
            text = r.recognize_google(audio_data, language="en-US")
        return text.lower()
    except Exception as e:
        print("Audio error:", e)
        return ""

def get_direction(x1, x2, frame_width):
    center = (x1 + x2) / 2
    if center < frame_width / 3: return "on the left"
    elif center < 2 * frame_width / 3: return "in the center"
    else: return "on the right"

def get_distance(x1, y1, x2, y2, frame_area):
    box_area = (x2 - x1) * (y2 - y1)
    ratio = box_area / frame_area
    if ratio > 0.15: return "very close"
    elif ratio > 0.07: return "close"
    else: return "far"

@app.post("/detect")
async def detect(file: UploadFile = File(...)):
    try:
        image_bytes = await file.read()
        nparr = np.frombuffer(image_bytes, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if frame is None: return {"description": "No image detected", "response_type": "error", "has_high_danger": False}
        results = model(frame)[0]
        h, w, _ = frame.shape
        frame_area = w * h
        objects = []
        seen_labels = set()
        has_high_danger = False
        response_type = "clear"
        for box in results.boxes:
            if float(box.conf[0]) > 0.25:
                cls_id = int(box.cls[0])
                name = model.names[cls_id]
                x1, y1, x2, y2 = box.xyxy[0].tolist()
                direction = get_direction(x1, x2, w)
                distance = get_distance(x1, y1, x2, y2, frame_area)
                label = f"{name} {direction}"
                if label not in seen_labels:
                    seen_labels.add(label)
                    objects.append(f"{name} {direction} ({distance})")
                if name in DANGEROUS_OBJECTS["high"]:
                    has_high_danger = True
                    response_type = "high_danger"
        description = "The path ahead seems clear." if not objects else "There is " + ", ".join(objects)
        return {"description": description, "response_type": response_type, "has_high_danger": has_high_danger}
    except Exception as e:
        return {"description": "Error processing image", "response_type": "error", "has_high_danger": False}

@app.post("/command")
async def process_voice_command(image: UploadFile = File(...), audio: UploadFile = File(...)):
    try:
        audio_bytes = await audio.read()
        command_text = transcribe_audio(audio_bytes)

        if not command_text:
            return {"description": "Sorry, I couldn't understand the voice command.", "response_type": "clear"}

        if "go to" in command_text or "open" in command_text or "navigate" in command_text:
            for tab, keywords in TAB_KEYWORDS.items():
                if any(keyword in command_text for keyword in keywords):
                    return {
                        "target_tab": tab,
                        "message": f"Opening {tab} screen"
                    }

        image_bytes = await image.read()
        nparr = np.frombuffer(image_bytes, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if frame is None:
            return {"description": "Invalid image.", "response_type": "error"}

        results = model(frame)[0]
        h, w, _ = frame.shape
        frame_area = w * h
        target_object = None

        for key in model.names.values():
            if key.lower() in command_text:
                target_object = key
                break

        if not target_object:
            return {"description": f"You said: '{command_text}', but I don't know this object.", "response_type": "clear"}

        for box in results.boxes:
            if float(box.conf[0]) > 0.25:
                cls_id = int(box.cls[0])
                name = model.names[cls_id]
                if name == target_object:
                    x1, y1, x2, y2 = box.xyxy[0].tolist()
                    direction = get_direction(x1, x2, w)
                    distance = get_distance(x1, y1, x2, y2, frame_area)
                    response_type = "clear"
                    if name in DANGEROUS_OBJECTS["high"]: response_type = "high_danger"
                    elif name in DANGEROUS_OBJECTS["medium"]: response_type = "medium_danger"

                    return {
                        "description": f"Yes, I found a {name} {direction}, and it is {distance}.",
                        "response_type": response_type
                    }

        return {"description": f"I heard '{command_text}', but I cannot see any {target_object} right now.", "response_type": "clear"}

    except Exception as e:
        print("Command Error:", e)
        return {"description": "Error executing voice command.", "response_type": "error"}





if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=3000)