from fastapi import FastAPI

from object_detection_api import router as object_router
from auth_api import router as auth_router
from money_detection_api import router as money_router
from face_recognition_api import router as face_router
from ocr_api import router as ocr_router

app = FastAPI(
    title="Safe Path API"
)

app.include_router(auth_router)
app.include_router(object_router)
app.include_router(money_router)
app.include_router(face_router)
app.include_router(ocr_router)