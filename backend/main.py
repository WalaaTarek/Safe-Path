from fastapi import FastAPI, File, UploadFile, Form
from ultralytics import YOLO
import numpy as np
import cv2
import io
import speech_recognition as sr
from auth import router

from translations import (
    translate_object,
    translate_direction,
    translate_distance,
    translate_tab,
    OBJECTS_AR,
    OBJECTS_REVERSE_AR,
    VOICE_COMMANDS_AR
)

app = FastAPI()

app.include_router(router)


model = YOLO("models/bestlast.pt")

print(model.names)



DANGEROUS_OBJECTS = {

    "high": [
        "car",
        "truck",
        "bus",
        "pothole",
        "obstacle"
    ],

    "medium": [
        "person",
        "dog",
        "chair"
    ],

    "low": [
        "potted plant",
        "bench"
    ]

}

TAB_KEYWORDS_EN = {

    "camera": [
        "camera",
        "scan",
        "detect"
    ],

    "money": [
        "money",
        "cash",
        "currency"
    ],

    "person": [
        "person",
        "face",
        "people"
    ],

    "history": [
        "history",
        "past",
        "logs"
    ],

    "settings": [
        "settings",
        "options"
    ],

    "upload": [
        "upload",
        "file"
    ]

}





def transcribe_audio(audio_bytes: bytes, language):

    r = sr.Recognizer()

    try:

        audio_file = io.BytesIO(audio_bytes)


        with sr.AudioFile(audio_file) as source:

            audio_data = r.record(source)


            if language == "ar":

                text = r.recognize_google(
                    audio_data,
                    language="ar-EG"
                )

            else:

                text = r.recognize_google(
                    audio_data,
                    language="en-US"
                )


        return text.lower()


    except Exception as e:

        print("Audio error:", e)

        return ""





def get_direction(x1, x2, frame_width):

    center = (x1+x2)/2


    if center < frame_width/3:

        return "on the left"


    elif center < 2*frame_width/3:

        return "in the center"


    else:

        return "on the right"




def get_distance(x1,y1,x2,y2,frame_area):

    box_area = (x2-x1)*(y2-y1)

    ratio = box_area/frame_area

    if ratio > 0.15:
        return "very close"

    elif ratio > 0.07:
        return "close"

    else:
        return "far"



@app.post("/detect")
async def detect(
    file: UploadFile = File(...),
    language: str = Form("en")
):

    try:

        image_bytes = await file.read()

        nparr = np.frombuffer(
            image_bytes,
            np.uint8
        )

        frame = cv2.imdecode(
            nparr,
            cv2.IMREAD_COLOR
        )


        if frame is None:

            return {
                "description": "No image detected",
                "response_type": "error",
                "has_high_danger": False
            }



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



                direction = get_direction(
                    x1,
                    x2,
                    w
                )


                distance = get_distance(
                    x1,
                    y1,
                    x2,
                    y2,
                    frame_area
                )



                translated_name = translate_object(
                    name,
                    language
                )


                translated_direction = translate_direction(
                    direction,
                    language
                )


                translated_distance = translate_distance(
                    distance,
                    language
                )



                label = (
                    f"{translated_name} "
                    f"{translated_direction}"
                )



                if label not in seen_labels:

                    seen_labels.add(label)


                    if language == "ar":

                        objects.append(
                            f"{translated_name} "
                            f"{translated_direction} "
                            f"({translated_distance})"
                        )

                    else:

                        objects.append(
                            f"{name} "
                            f"{direction} "
                            f"({distance})"
                        )



                if name in DANGEROUS_OBJECTS["high"]:

                    has_high_danger = True

                    response_type = "high_danger"



                elif name in DANGEROUS_OBJECTS["medium"]:

                    if response_type == "clear":

                        response_type = "medium_danger"




        if not objects:

            if language == "ar":

                description = "الطريق أمامك واضح"

            else:

                description = "The path ahead seems clear."


        else:


            if language == "ar":

                description = (
                    "يوجد "
                    +
                    "، ".join(objects)
                )

            else:

                description = (
                    "There is "
                    +
                    ", ".join(objects)
                )



        return {

            "description": description,

            "response_type": response_type,

            "has_high_danger": has_high_danger

        }



    except Exception as e:

        print("Detect error:", e)


        return {

            "description": 
                "Error processing image",

            "response_type":
                "error",

            "has_high_danger":
                False

        }






@app.post("/command")
async def process_voice_command(

    image: UploadFile = File(...),

    audio: UploadFile = File(...),

    language: str = Form("en")

):

    try:


        audio_bytes = await audio.read()


        command_text = transcribe_audio(
            audio_bytes,
            language
        )



        if not command_text:

            return {

                "description":
                "لم أفهم الأمر" if language=="ar"
                else
                "Sorry, I couldn't understand the voice command.",

                "response_type":
                "clear"

            }

        # فتح الشاشات

        if (
            "go to" in command_text
            or "open" in command_text
            or "navigate" in command_text
            or "افتح" in command_text
        ):

            if language == "ar":

                for tab, words in VOICE_COMMANDS_AR.items():

                    if any(word in command_text for word in words):

                        return {
                            "target_tab": tab,
                            "message": f"جاري فتح {translate_tab(tab, 'ar')}"
                        }

            else:

                for tab, words in TAB_KEYWORDS_EN.items():

                    if any(word in command_text for word in words):

                        return {
                            "target_tab": tab,
                            "message": f"Opening {tab} screen"
                        }


        image_bytes = await image.read()

        nparr = np.frombuffer(
            image_bytes,
            np.uint8
        )


        frame = cv2.imdecode(
            nparr,
            cv2.IMREAD_COLOR
        )



        if frame is None:

            return {

                "description":
                "الصورة غير صالحة" if language=="ar"
                else
                "Invalid image.",

                "response_type":
                "error"

            }



        results = model(frame)[0]


        h, w, _ = frame.shape

        frame_area = w * h



        target_object = None



        # البحث عن اسم الشيء الذي طلبه المستخدم

        for key in model.names.values():

            if key.lower() in command_text:

                target_object = key

                break



        # البحث بالعربي

        if target_object is None and language == "ar":

            for eng, arabic in OBJECTS_AR.items():

                if arabic in command_text:

                    target_object = eng

                    break




        if not target_object:


            return {

                "description":

                (
                    f"قلت: {command_text} لكن لا أعرف هذا الشيء"
                    if language=="ar"
                    else
                    f"You said: '{command_text}', but I don't know this object."
                ),

                "response_type":
                "clear"

            }




        for box in results.boxes:


            if float(box.conf[0]) > 0.25:


                cls_id = int(box.cls[0])


                name = model.names[cls_id]



                if name == target_object:


                    x1,y1,x2,y2 = box.xyxy[0].tolist()



                    direction = get_direction(
                        x1,
                        x2,
                        w
                    )


                    distance = get_distance(
                        x1,
                        y1,
                        x2,
                        y2,
                        frame_area
                    )



                    translated_name = translate_object(
                        name,
                        language
                    )


                    translated_direction = translate_direction(
                        direction,
                        language
                    )


                    translated_distance = translate_distance(
                        distance,
                        language
                    )



                    response_type = "clear"



                    if name in DANGEROUS_OBJECTS["high"]:

                        response_type = "high_danger"



                    elif name in DANGEROUS_OBJECTS["medium"]:

                        response_type = "medium_danger"




                    if language == "ar":

                        description = (
                            f"نعم، وجدت {translated_name} "
                            f"{translated_direction} "
                            f"وهو {translated_distance}"
                        )


                    else:


                        description = (
                            f"Yes, I found a {name} "
                            f"{direction}, "
                            f"and it is {distance}."
                        )



                    return {

                        "description":
                        description,

                        "response_type":
                        response_type

                    }





        return {

            "description":

            (
                f"سمعت {command_text} "
                f"لكن لا أستطيع رؤية {translate_object(target_object, language)} الآن"
                if language=="ar"

                else

                f"I heard '{command_text}', but I cannot see any {target_object} right now."
            ),

            "response_type":
            "clear"

        }


    except Exception as e:


        print("Command Error:", e)


        return {

            "description":

            "حدث خطأ أثناء تنفيذ الأمر"
            if language=="ar"

            else

            "Error executing voice command.",


            "response_type":
            "error"

        }


if __name__ == "__main__":

    import uvicorn


    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000
    )