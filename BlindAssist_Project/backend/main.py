from ultralytics import YOLO
import cv2
import pyttsx3
import threading
import queue
import time

engine = pyttsx3.init()
engine.setProperty('rate', 150)

speech_queue = queue.Queue()

def speech_worker():
    while True:
        text = speech_queue.get()
        if text is None:
            break
        engine.say(text)
        engine.runAndWait()
        speech_queue.task_done()

threading.Thread(target=speech_worker, daemon=True).start()

model = YOLO("yolov8m.pt")

cap = cv2.VideoCapture(0)

last_spoken = ""
last_time = 0

while True:
    ret, frame = cap.read()
    if not ret:
        break

    frame = cv2.convertScaleAbs(frame, alpha=1.1, beta=10)

    results = model(frame)[0]

    objects = {}

    for box in results.boxes:
        conf = float(box.conf[0])
        cls_id = int(box.cls[0])
        name = model.names[cls_id]

        if conf > 0.5:
            if name not in objects or conf > objects[name]["conf"]:
                objects[name] = {
                    "conf": conf,
                    "bbox": box.xyxy[0].tolist()
                }

    h, w = frame.shape[:2]

    for name, obj in objects.items():
        x1, y1, x2, y2 = map(int, obj["bbox"])

        cx, cy = (x1+x2)//2, (y1+y2)//2

        horiz = "left" if cx < w/3 else "right" if cx > 2*w/3 else "center"
        vert = "top" if cy < h/3 else "bottom" if cy > 2*h/3 else "center"

        area = (x2-x1)*(y2-y1)
        size = "large" if area > (w*h)/6 else "small"

        description = f"{size} {name} {horiz} {vert}"

        cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
        cv2.putText(frame, description, (x1, y1-10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

        now = time.time()
        if description != last_spoken and (now - last_time > 4):
            speech_queue.put(description)
            last_spoken = description
            last_time = now

    cv2.imshow("BlindAssist Detection", frame)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()