import sys
import os
import cv2
import time
import threading
import board
import adafruit_dht
import requests
from pathlib import Path
from gpiozero import DigitalInputDevice
from picamera2 import Picamera2

# I ensure the Python path and environment variables are correctly set for the Pi's VNC display.
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ["DISPLAY"] = ":0"

# --- SYSTEM CONFIGURATION ---
API_URL = "http://YOUR_LAPTOP_IP:8000/api/v1" 
DEVICE_ID = "YOUR_DEVICE_UUID" 

from app.vision.face_detector import FaceDetector
from app.vision.embedder import FaceEmbedder
from app.vision.matcher import FaceMatcher

current_temp, current_hum = 0.0, 0.0
is_motion_active = False
last_face_capture_time = 0

CAPTURE_DIR = Path("data/captures")
CAPTURE_DIR.mkdir(parents=True, exist_ok=True)

pir_sensor = DigitalInputDevice(27, pull_up=False) 
dht_device = adafruit_dht.DHT11(board.D4, use_pulseio=False)

def send_telemetry():
    """I send environment data to the cloud every 60 seconds using my FastAPI gateway."""
    while True:
        try:
            payload = {"device_id": DEVICE_ID, "temperature": current_temp, "humidity": current_hum}
            requests.post(f"{API_URL}/telemetry/climate", json=payload, timeout=5)
        except:
            pass
        time.sleep(60)

def main():
    threading.Thread(target=send_telemetry, daemon=True).start()
    
    picam2 = Picamera2()
    config = picam2.create_preview_configuration(main={"size": (1280, 720)})
    picam2.configure(config)
    picam2.start()

    print("[SYSTEM] Smart Home Core v2 (Cloud-Enabled) is running...")

    while True:
        if pir_sensor.value == 1:
            frame = picam2.capture_array()
            frame_bgr = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
            cv2.imshow("Smart Home Live", frame_bgr)
            
            # I trigger the security pipeline if motion is detected and the cooldown is over.
            if time.time() - last_face_capture_time > 10:
                # ... (Face processing and API calls go here as discussed) ...
                pass

            if cv2.waitKey(1) & 0xFF == ord('q'): break
        else:
            cv2.destroyAllWindows()
            time.sleep(0.5)

if __name__ == '__main__':
    main()