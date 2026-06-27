import io
import os
import threading

import cv2
import numpy as np
import tensorflow as tf

from PIL import Image, ImageOps

from fastapi import APIRouter, UploadFile, File, Form
from fastapi.responses import JSONResponse
from starlette.concurrency import run_in_threadpool

import firebase_admin
from firebase_admin import credentials, firestore

BASE_DIR = os.path.dirname(
    os.path.abspath(__file__)
)

MODEL_PATH = os.path.join(
    BASE_DIR,
    "models",
    "face_recognition_model.tflite"
)

FIREBASE_CREDENTIALS = "firebase.json"

if not firebase_admin._apps:

    cred = credentials.Certificate(
        FIREBASE_CREDENTIALS
    )

    firebase_admin.initialize_app(cred)

db = firestore.client()

router = APIRouter()

interpreter = tf.lite.Interpreter(
    model_path=MODEL_PATH
)

interpreter.allocate_tensors()

input_details = interpreter.get_input_details()

output_details = interpreter.get_output_details()

model_lock = threading.Lock()

CASCADE_PATH = (
    cv2.data.haarcascades +
    "haarcascade_frontalface_default.xml"
)

face_detector = cv2.CascadeClassifier(
    CASCADE_PATH
)

INPUT_SIZE = 100

SIMILARITY_THRESHOLD = 0.51

MAX_EMBEDDINGS_PER_PERSON = 5

DUPLICATE_THRESHOLD = 0.15

def preprocess_image(image_bytes):

    image = Image.open(
        io.BytesIO(image_bytes)
    )

    image = ImageOps.exif_transpose(image)

    image = image.convert("RGB")

    image = np.array(image)

    gray = cv2.cvtColor(
        image,
        cv2.COLOR_RGB2GRAY
    )

    faces = face_detector.detectMultiScale(

        gray,

        scaleFactor=1.1,

        minNeighbors=5,

        minSize=(80, 80)

    )

    if len(faces) == 0:

        return None

    x, y, w, h = max(
        faces,
        key=lambda f: f[2] * f[3]
    )

    margin_x = int(0.20 * w)
    margin_y = int(0.20 * h)

    x1 = max(0, x - margin_x)
    y1 = max(0, y - margin_y)

    x2 = min(
        image.shape[1],
        x + w + margin_x
    )

    y2 = min(
        image.shape[0],
        y + h + margin_y
    )

    face = image[
        y1:y2,
        x1:x2
    ]

    face = cv2.resize(
        face,
        (
            INPUT_SIZE,
            INPUT_SIZE
        )
    )

    face = face.astype(
        np.float32
    )

    face /= 255.0

    face = np.expand_dims(
        face,
        axis=0
    )

    return face

def get_embedding(image_bytes):

    image = preprocess_image(
        image_bytes
    )

    if image is None:

        return None

    with model_lock:

        interpreter.set_tensor(
            input_details[0]["index"],
            image
        )

        interpreter.invoke()

        embedding = interpreter.get_tensor(
            output_details[0]["index"]
        )[0]

    embedding = embedding.astype(
        np.float32
    )

    embedding /= (
        np.linalg.norm(embedding) + 1e-10
    )

    return embedding.tolist()

def get_face_document(document_id):

    doc = (
        db.collection("known_faces")
        .document(document_id)
        .get()
    )

    if not doc.exists:
        return None

    return doc

def add_new_face(
    name,
    description,
    embedding
):

    doc_ref = db.collection(
        "known_faces"
    ).add({

        "name": name,

        "description": description,

        "embeddings": {

            "0": embedding

        }

    })

    return doc_ref[1].id

def update_face(
    document_id,
    new_name=None,
    new_description=None,
    new_embedding=None
):

    doc = get_face_document(document_id)

    if doc is None:
        return False

    data = doc.to_dict()

    update_data = {}

    if new_name:
        update_data["name"] = new_name

    if new_description:
        update_data["description"] = new_description

    if new_embedding is not None:

        embeddings = data.get(
            "embeddings",
            {}
        )

        duplicate = False

        for emb in embeddings.values():

            emb = np.array(
                emb,
                dtype=np.float32
            )

            dist = np.linalg.norm(
                np.array(
                    new_embedding,
                    dtype=np.float32
                ) - emb
            )

            if dist < DUPLICATE_THRESHOLD:

                duplicate = True
                break

        if not duplicate:

            index = len(embeddings)

            if index >= MAX_EMBEDDINGS_PER_PERSON:

                embeddings = {

                    str(i): embeddings[str(i + 1)]

                    for i in range(
                        MAX_EMBEDDINGS_PER_PERSON - 1
                    )

                }

                index = MAX_EMBEDDINGS_PER_PERSON - 1

            embeddings[str(index)] = new_embedding

        update_data["embeddings"] = embeddings

    doc.reference.update(update_data)

    return True

def delete_face(
    document_id
):

    doc = get_face_document(
        document_id
    )

    if doc is None:
        return False

    doc.reference.delete()

    return True

def find_matching_person(new_embedding):

    users = db.collection(
        "known_faces"
    ).stream()

    new_embedding = np.array(
        new_embedding,
        dtype=np.float32
    )

    best_distance = float("inf")
    best_doc = None

    for doc in users:

        data = doc.to_dict()

        embeddings = data.get(
            "embeddings",
            {}
        )

        if len(embeddings) == 0:
            continue

        person_best_distance = float("inf")

        for emb in embeddings.values():

            emb = np.array(
                emb,
                dtype=np.float32
            )

            distance = np.linalg.norm(
                new_embedding - emb
            )

            if distance < person_best_distance:

                person_best_distance = distance

        if person_best_distance < best_distance:

            best_distance = person_best_distance
            best_doc = doc

    if best_doc is None:

        return {

            "matched": False,

            "name": None,

            "distance": None

        }

    data = best_doc.to_dict()

    if best_distance <= SIMILARITY_THRESHOLD:

        return {

            "matched": True,

            "document_id": best_doc.id,

            "name": data.get("name"),

            "description": data.get(
                "description",
                ""
            ),

            "distance": float(best_distance)

        }

    return {

        "matched": False,

        "name": data.get("name"),

        "distance": float(best_distance)

    }

def face_exists(new_embedding):

    users = db.collection(
        "known_faces"
    ).stream()

    new_embedding = np.array(
        new_embedding,
        dtype=np.float32
    )

    for doc in users:

        data = doc.to_dict()

        embeddings = data.get(
            "embeddings",
            {}
        )

        for emb in embeddings.values():

            emb = np.array(
                emb,
                dtype=np.float32
            )

            distance = np.linalg.norm(
                new_embedding - emb
            )

            if distance <= SIMILARITY_THRESHOLD:

                return {

                    "exists": True,

                    "document_id": doc.id,

                    "name": data.get("name"),

                    "distance": float(distance)

                }

    return {

        "exists": False

    }

@router.post("/face-recognition/recognize-face")
async def recognize_face(
    file: UploadFile = File(...)
):

    try:

        image_bytes = await file.read()

        embedding = await run_in_threadpool(
            get_embedding,
            image_bytes
        )

        if embedding is None:

            return {

                "status": "no_face",

                "message": "No face detected"

            }

        result = await run_in_threadpool(
            find_matching_person,
            embedding
        )

        if result["matched"]:

            return {

                "status": "known",

                "document_id": result["document_id"],

                "name": result["name"],

                "description": result["description"],

                "distance": round(
                    result["distance"],
                    4
                )

            }

        return {

            "status": "unknown",

            "message": "Face not recognized",

            "closest_name": result["name"],

            "distance": (
                round(result["distance"], 4)
                if result["distance"] is not None
                else None
            )

        }

    except FileNotFoundError:

        return JSONResponse(

            status_code=404,

            content={

                "status": "error",

                "errorCode": "FILE_NOT_FOUND",

                "message": "Required file not found"

            }

        )

    except ValueError:

        return JSONResponse(

            status_code=400,

            content={

                "status": "error",

                "errorCode": "INVALID_IMAGE",

                "message": "Invalid image"

            }

        )

    except Exception as e:

        print(e)

        return JSONResponse(

            status_code=500,

            content={

                "status": "error",

                "errorCode": "INTERNAL_SERVER_ERROR",

                "message": str(e)

            }

        )

@router.post("/face-recognition/save-new-face")
async def save_new_face(
    name: str = Form(...),
    description: str = Form(...),
    file: UploadFile = File(...)
):

    try:

        image_bytes = await file.read()

        embedding = await run_in_threadpool(
            get_embedding,
            image_bytes
        )

        if embedding is None:

            return {

                "status": "no_face",

                "message": "No face detected"

            }

        existing_face = await run_in_threadpool(
            face_exists,
            embedding
        )

        if existing_face["exists"]:

            return JSONResponse(

                status_code=409,

                content={

                    "status": "already_exists",

                    "document_id": existing_face["document_id"],

                    "name": existing_face["name"],

                    "distance": round(
                        existing_face["distance"],
                        4
                    ),

                    "message": "Face already exists"

                }

            )

        document_id = await run_in_threadpool(

            add_new_face,

            name,

            description,

            embedding

        )

        return {

            "status": "saved",

            "document_id": document_id,

            "message": f"{name} registered successfully"

        }

    except FileNotFoundError:

        return JSONResponse(

            status_code=404,

            content={

                "status": "error",

                "errorCode": "FILE_NOT_FOUND",

                "message": "Required file not found"

            }

        )

    except ValueError:

        return JSONResponse(

            status_code=400,

            content={

                "status": "error",

                "errorCode": "INVALID_IMAGE",

                "message": "Invalid image"

            }

        )

    except Exception as e:

        print(e)

        return JSONResponse(

            status_code=500,

            content={

                "status": "error",

                "errorCode": "DATABASE_ERROR",

                "message": str(e)

            }

        )
    
@router.put("/face-recognition/update-face")
async def update_known_face(

    document_id: str = Form(...),

    new_name: str = Form(None),

    new_description: str = Form(None),

    file: UploadFile = File(None)

):

    try:

        new_embedding = None

        if file is not None:

            image_bytes = await file.read()

            new_embedding = await run_in_threadpool(

                get_embedding,

                image_bytes

            )

            if new_embedding is None:

                return {

                    "status": "no_face",

                    "message": "No face detected"

                }

        updated = await run_in_threadpool(

            update_face,

            document_id,

            new_name,

            new_description,

            new_embedding

        )

        if not updated:

            return {

                "status": "not_found",

                "message": "Person not found"

            }

        doc = await run_in_threadpool(

            get_face_document,

            document_id

        )

        data = doc.to_dict()

        return {

            "status": "updated",

            "document_id": document_id,

            "name": data.get("name"),

            "description": data.get("description"),

            "total_embeddings": len(

                data.get(

                    "embeddings", 
                    {}

                )

            ),

            "message": "Face updated successfully"

        }

    except Exception as e:

        print(e)

        return JSONResponse(

            status_code=500,

            content={

                "status": "error",

                "errorCode": "UPDATE_ERROR",

                "message": str(e)

            }

        )

@router.delete("/face-recognition/delete-face")
async def remove_face(
    document_id: str
):

    try:

        deleted = await run_in_threadpool(

            delete_face,

            document_id

        )

        if not deleted:

            return {

                "status": "not_found",

                "message": "Person not found"

            }

        return {

            "status": "deleted",

            "document_id": document_id,

            "message": "Person deleted successfully"

        }

    except Exception as e:

        print(e)

        return JSONResponse(

            status_code=500,

            content={

                "status": "error",

                "errorCode": "DELETE_ERROR",

                "message": str(e)

            }

        )