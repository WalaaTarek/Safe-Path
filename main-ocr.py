import requests
import sys
import os

#  API URL
url = "http://127.0.0.1:5000/ocr"

# Get file path from command line argument or prompt user
if len(sys.argv) > 1:
    file_path = sys.argv[1]
else:
    file_path = input("Enter the path to the PDF file: ")

# Check if file exists
if not os.path.exists(file_path):
    print(f"Error: File not found: {file_path}")
    sys.exit(1)

print(f"Processing: {file_path}")
with open(file_path, "rb") as f:
    files = {"file": f}
    response = requests.post(url, files=files)

try:
    print("=== RESPONSE ===")
    print(response.json())
except Exception:
    print("Error:", response.text)
