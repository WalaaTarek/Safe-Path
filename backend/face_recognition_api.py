import io
import os
import threading
import cv2
import firebase_admin
import mediapipe as mp
import numpy as np
import tensorflow as tf
from PIL import Image, ImageOps
from fastapi import (FastAPI, UploadFile, File, Form)
from fastapi.responses import (JSONResponse)
from firebase_admin import (credentials,firestore)
from starlette.concurrency import (run_in_threadpool)

BASE_DIR = os.path.dirname(
    os.path.abspath(__file__)
)

MODEL_PATH = os.path.join(
    BASE_DIR,
    "models",
    "mobilefacenet.tflite",
)

FIREBASE_CREDENTIALS = "firebase.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(FIREBASE_CREDENTIALS)
    firebase_admin.initialize_app(cred)

db = firestore.client()

app = FastAPI(title="Face Recognition Backend")

interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)

interpreter.allocate_tensors()

input_details = (interpreter.get_input_details())

output_details = (interpreter.get_output_details())

model_lock = threading.Lock()

INPUT_SIZE = 112
SIMILARITY_THRESHOLD = 0.95

mp_face_detection = (mp.solutions.face_detection)

face_detector = (mp_face_detection.FaceDetection(model_selection=0,min_detection_confidence=0.6,))

def preprocess_image(image_bytes):

    image = Image.open(io.BytesIO(image_bytes))
    image = (ImageOps.exif_transpose(image).convert("RGB"))
    img_np = np.array(image)

    h, w, _ = img_np.shape
    results = face_detector.process(img_np)

    if not results.detections:

        print(
            "⚠️ [MediaPipe] "
            "No face detected."
        )

        return None

    bbox = (
        results
        .detections[0]
        .location_data
        .relative_bounding_box
    )

    x1 = max(0,int(bbox.xmin * w))
    y1 = max(0,int(bbox.ymin * h))
    x2 = min(w,int((bbox.xmin +bbox.width) * w))
    y2 = min(h,int((bbox.ymin +bbox.height) * h))

    if x2 <= x1 or y2 <= y1:

        print("⚠️ [MediaPipe] "
            "Invalid face box."
        )

        return None

    print(
        f"ℹ️ [MediaPipe] "
        f"Face Size: "
        f"{x2-x1}x{y2-y1}"
    )

    face = img_np[y1:y2,x1:x2]

    face = cv2.resize(face,(INPUT_SIZE, INPUT_SIZE,),)

    face = face.astype(np.float32)

    face = (face - 127.5) / 128.0

    face = np.expand_dims(face,axis=0,)

    return face


def get_embedding(image_bytes):

    input_data = preprocess_image(image_bytes)

    if input_data is None:

        return None

    with model_lock:

        interpreter.set_tensor(input_details[0]["index"],input_data,)

        interpreter.invoke()

        embedding = (interpreter.get_tensor(output_details[0]["index"])[0])

    norm = np.linalg.norm(embedding)

    embedding = (embedding /(norm + 1e-7))

    return embedding.tolist()


def find_matching_person(new_embedding):

    users = db.collection("known_faces").stream()

    best_dist = float("inf")

    best_name = None

    best_description = None

    new_emb_np = np.array(new_embedding)

    for doc in users:

        data = doc.to_dict()

        known_emb = np.array(data.get("embedding"))

        dist = np.linalg.norm(new_emb_np - known_emb)

        if dist < best_dist:

            best_dist = dist

            best_name = data.get("name")

            best_description = data.get("description","No description", )

    print(
        f"🔬 [Matching] "
        f"Closest Name: "
        f"{best_name}, "
        f"Distance: "
        f"{best_dist:.4f}"
    )

    if (best_name and best_dist < SIMILARITY_THRESHOLD):

        return {
            "matched": True,
            "name":
                best_name,

            "description":
                best_description,

            "distance":
                float(best_dist),
        }

    return {

        "matched": False,

        "name":
            best_name
            if best_name
            else "None",

        "distance":
            float(best_dist)
            if best_dist != float("inf")
            else None,
    }


def check_name_exists(
    name: str
) -> bool:

    docs = (
        db.collection("known_faces")
        .where(
            "name",
            "==",
            name,
        )
        .limit(1)
        .get()
    )

    return len(docs) > 0


def add_new_face(name: str,description: str,embedding: list,):

    db.collection("known_faces").add({
        "name": name,

        "description":
            description,

        "embedding":
            embedding,
    })

@app.get("/face-recognition")
def home():

    return {"status": "online"}

@app.post(
    "/face-recognition/recognize-face"
)

async def recognize_face(
    file: UploadFile = File(...)
):

    try:

        image_bytes = await file.read()

        embedding = (await run_in_threadpool(get_embedding, image_bytes,))

        if embedding is None:

            return {

                "status":
                    "no_face",

                "message":
                    "No face detected",
            }

        result = (await run_in_threadpool(find_matching_person,embedding,))

        if result["matched"]:

            return {

                "status":
                    "known",

                "name":
                    result["name"],

                "description":
                    result[
                        "description"
                    ],

                "distance":
                    result[
                        "distance"
                    ],
            }

        return {

            "status":
                "unknown",

            "message":
                "Face not recognized",

            "closest_name":
                result["name"],

            "distance":
                result[
                    "distance"
                ],
        }

    except Exception as e:

        return JSONResponse(

            status_code=500,

            content={
                "error": str(e)
            },
        )

@app.post(
    "/face-recognition/save-new-face"
)

async def save_new_face(name: str = Form(...), description: str = Form(...), file: UploadFile = File(...),):

    try:

        image_bytes = await file.read()

        embedding = (await run_in_threadpool(get_embedding, image_bytes,))

        if embedding is None:

            return {

                "status":
                    "no_face",

                "message":
                    "No face detected",
            }

        name_exists = (await run_in_threadpool(check_name_exists,name,))

        if name_exists:

            return {

                "status":
                    "exists",

                "message":
                    f"{name} already exists",
            }

        await run_in_threadpool(
            add_new_face,
            name,
            description,
            embedding,
        )

        print(
            f"💾 [Database] "
            f"Saved: {name}"
        )

        print(
            f"📝 Description: "
            f"{description}"
        )

        return {

            "status":
                "saved",

            "message":
                f"{name} "
                f"registered successfully",
        }

    except Exception as e:

        return JSONResponse(

            status_code=500,

            content={
                "error": str(e)
            },
        )
