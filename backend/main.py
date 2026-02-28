from fastapi import FastAPI, File, UploadFile
import cv2
import numpy as np
from ultralytics import YOLO
from scene_builder import build_scene_structure, extract_objects
from description_generator import generate_description

app = FastAPI()
model = YOLO("yolov8s.pt")

@app.post("/analyze")
async def analyze_image(file: UploadFile = File(...)):
    contents = await file.read()
    np_array = np.frombuffer(contents, np.uint8)
    frame = cv2.imdecode(np_array, cv2.IMREAD_COLOR)

    results = model(frame)

    objects_list = extract_objects(results, frame)
    scene = build_scene_structure(objects_list)
    description = generate_description(scene)
    print(description)

    return {"description": description}