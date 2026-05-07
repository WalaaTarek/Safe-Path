from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import JSONResponse
import numpy as np
from PIL import Image
import tensorflow as tf
import firebase_admin
from firebase_admin import credentials, firestore
import io
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "models", "mobilefacenet.tflite")

print("MODEL PATH:", MODEL_PATH)
print("EXISTS:", os.path.exists(MODEL_PATH))

FIREBASE_CREDENTIALS = "firebase.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(FIREBASE_CREDENTIALS)
    firebase_admin.initialize_app(cred)

db = firestore.client()

app = FastAPI(title="Face Recognition Backend")

interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

INPUT_SIZE = 112

def preprocess_image(image_bytes):
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    image = image.resize((INPUT_SIZE, INPUT_SIZE))

    img = np.array(image).astype(np.float32)
    img = (img - 127.5) / 128.0

    return np.expand_dims(img, axis=0)

def get_embedding(image_bytes):
    input_data = preprocess_image(image_bytes)

    interpreter.set_tensor(input_details[0]["index"], input_data)
    interpreter.invoke()

    embedding = interpreter.get_tensor(output_details[0]["index"])[0]
    embedding = embedding / np.linalg.norm(embedding)

    return embedding.tolist()

def euclidean_distance(vec1, vec2):
    return np.linalg.norm(np.array(vec1) - np.array(vec2))

SIMILARITY_THRESHOLD = 1.0

def find_matching_person(new_embedding):
    users = db.collection("known_faces").stream()

    best = None
    best_dist = float("inf")

    for doc in users:
        data = doc.to_dict()
        emb = data.get("embedding")

        if not emb:
            continue

        dist = euclidean_distance(new_embedding, emb)

        if dist < best_dist:
            best_dist = dist
            best = data

    if best_dist < SIMILARITY_THRESHOLD:
        return {
            "matched": True,
            "name": best["name"],
            "distance": best_dist
        }

    return {
        "matched": False,
        "distance": best_dist
    }

@app.get("/face-recognition")
def home():
    return {"message": "Face Recognition API is running"}

@app.post("/face-recognition/recognize-face")
async def recognize_face(file: UploadFile = File(...)):
    try:
        image_bytes = await file.read()

        embedding = get_embedding(image_bytes)
        result = find_matching_person(embedding)

        if result["matched"]:
            return {
                "status": "known",
                "name": result["name"],
                "distance": result["distance"]
            }

        return {
            "status": "unknown",
            "message": "Face not recognized",
            "embedding": embedding
        }

    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})

@app.post("/face-recognition/save-new-face")
async def save_new_face(
    name: str = Form(...),
    file: UploadFile = File(...)
):
    try:
        image_bytes = await file.read()

        embedding = get_embedding(image_bytes)

        doc_data = {
            "name": name,
            "embedding": embedding
        }

        db.collection("known_faces").add(doc_data)

        return {
            "status": "saved",
            "message": f"{name} saved successfully"
        }

    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})