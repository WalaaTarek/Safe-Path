# Safe-Path

# Running the Server

## 1. Get Your Local IP Address

Before running the server, find your local IP address so other devices on the same network can access it.

- **Windows**:

```cmd
ipconfig
```

### Look for IPv4 Address under the network you are connected to.

## 2. Update the Server URL in the App

Open the file that contains the server URL (Safe-path/safepath/lib/services/api_service.dart) and edit the line:

```cmd
static const String serverUrl = "http://<YOUR_IP>:8000/analyze";
```

Replace <YOUR_IP> with the IP address you got in step 1.

## 3. Run the Server

Open the terminal, navigate to the server folder (backend) and run:

- **Windows**:

```cmd
cd backend
uvicorn main:app --host 0.0.0.0 --port 8000
```

## Requirements for ocr-project

### Install Python packages 

pip install pillow pytesseract pdf2image easyocr opencv-python-headless numpy flask requests

### Install Tesseract

Download from:
https://github.com/tesseract-ocr/tesseract

Then update path in code:
pytesseract.pytesseract.tesseract_cmd = "YOUR_PATH"

### Install Poppler (for PDF)

Download Poppler and update:
poppler_path="YOUR_PATH"

### Install sumy (for summerize)

pip install sumy

## Run project

python -m venv venv
venv\Scripts\activate

pip install -r requirements.txt
python test_ocr.py
##
## Requirements for money

## 2. Update the Server URL in the App

Open the file that contains the server URL (Safe-path/safepath/lib/services/api_service_coins.dart) and edit the line:

```cmd
static const String Url = "http://<YOUR_IP>:8000/analyze";
```

Replace <YOUR_IP> with your IP address
## 3. Run the Server
## Requirements for translation 
pip install deep-translator

Open the terminal, navigate to the server folder (backend) and run:

- **Windows**:

```cmd
cd backend
python app.py
```
