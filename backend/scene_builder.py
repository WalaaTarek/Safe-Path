import cv2
import numpy as np
from sklearn.cluster import KMeans


VEHICLES = {"car", "bus", "truck", "motorbike", "bicycle"}
COLOR_RANGES = {
    "red": [(0, 10), (160, 180)],
    "orange": [(11, 25)],
    "yellow": [(26, 35)],
    "green": [(36, 85)],
    "blue": [(86, 125)],
    "purple": [(126, 160)],
    "pink": [(161, 170)],
    "brown": [(10, 20)],
    "black": [(0, 180)],
    "white": [(0, 180)],
    "gray": [(0, 180)]
}

def get_dominant_color(crop_img, k=3):
    img = cv2.cvtColor(crop_img, cv2.COLOR_BGR2HSV)
    img = img.reshape((-1,3))
    img = np.float32(img)

    kmeans = KMeans(n_clusters=k, random_state=0).fit(img)
    counts = np.bincount(kmeans.labels_)
    dominant = kmeans.cluster_centers_[np.argmax(counts)]
    h, s, v = dominant

    if v < 50:
        return "black"
    if s < 50 and v > 200:
        return "white"
    if s < 50:
        return "gray"

    h = int(h)
    for color, ranges in COLOR_RANGES.items():
        for r in ranges:
            if r[0] <= h <= r[1]:
                return color
    return "mixed"

def extract_objects(results,frame):

    labels = []
    for box in results[0].boxes:
        cls_id = int(box.cls[0])
        label = results[0].names[cls_id]

        x1, y1, x2, y2 = map(int, box.xyxy[0])
        crop = frame[y1:y2, x1:x2]

        color = get_dominant_color(crop)
        labels.append({
            "label": label,
            "box": [x1, y1, x2, y2],
            "color": color
        })
    return labels

def build_scene_structure(objects_list):
    scene = {
        "people": 0,
        "objects": []
    }

    for obj in objects_list:
        if obj["label"] == "person":
            scene["people"] += 1
        else:
            scene["objects"].append(obj)

    return scene