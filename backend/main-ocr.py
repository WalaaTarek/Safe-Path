<<<<<<< HEAD
import requests

#  API URL
url = "http://127.0.0.1:5000/ocr"

file_path = "Lab1 Main Concepts.pdf"

with open(file_path, "rb") as f:
    files = {"file": f}
    response = requests.post(url, files=files)

try:
    print("=== RESPONSE ===")
    print(response.json())
except Exception:
=======
import requests

#  API URL
url = "http://127.0.0.1:5000/ocr"

file_path = "Lab1 Main Concepts.pdf"

with open(file_path, "rb") as f:
    files = {"file": f}
    response = requests.post(url, files=files)

try:
    print("=== RESPONSE ===")
    print(response.json())
except Exception:
>>>>>>> 03f0c7425d272c5176bfeea8a1e166ab5170faaf
    print("Error:", response.text)