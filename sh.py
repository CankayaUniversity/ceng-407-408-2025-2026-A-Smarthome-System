import sys
import os

# I am explicitly adding the current directory to Python's path here. 
# This prevents Python from throwing a 'ModuleNotFoundError' when trying to import our 'app' folder.
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# I set this environment variable so that the live camera feed pops up directly on our main VNC screen.
os.environ["DISPLAY"] = ":0"

import cv2
import time
import threading
import board
import adafruit_dht
from pathlib import Path
from gpiozero import DigitalInputDevice
from picamera2 import Picamera2

# --- IMPORTING THE FACE RECOGNITION AND LOGGING SYSTEM ---
# Here, I am pulling in the vision modules and the event logger that handles our JSON outputs.
from app.vision.face_detector import FaceDetector
from app.vision.embedder import FaceEmbedder
from app.vision.matcher import FaceMatcher
from app.logging_system.event_logger import EventLogger

# --- GLOBAL VARIABLES FOR OSD & TERMINAL ---
# I use these global variables to share sensor states between the background reading threads and the main camera loop.
current_temp = "WAITING..."
current_hum = "WAITING..."
current_gas = "NO GAS"
current_motion = "None"
current_soil = "WET"
dht_log = "Initializing..."

is_motion_active = False
motion_last_detected_time = 0
last_face_capture_time = 0
MOTION_COOLDOWN_SECONDS = 5  # I set a 5-second cooldown so we don't spam the face recognition system with too many photos.

# I'm creating a directory to save the captured frames if it doesn't already exist.
CAPTURE_DIR = Path("data/captures")
CAPTURE_DIR.mkdir(parents=True, exist_ok=True)

# --- DIGITAL SENSOR CONFIGURATIONS ---
# I disabled the internal pull-up resistors (pull_up=False) for the MQ2 and PIR sensors 
# because the Pi's internal resistors were interfering with the actual sensor signals.
mq2_sensor = DigitalInputDevice(17, pull_up=False)
pir_sensor = DigitalInputDevice(27, pull_up=False) 
soil_sensor = DigitalInputDevice(22)

# Initializing the DHT11 temperature and humidity sensor using the standard Adafruit library.
dht_device = adafruit_dht.DHT11(board.D4, use_pulseio=False)

# --- INITIALIZING VISION MODULES ---
try:
    print("[INFO] Loading Face Recognition Modules...")
    face_detector = FaceDetector()
    face_embedder = FaceEmbedder()
    face_matcher = FaceMatcher()
    event_logger = EventLogger()
    print("[INFO] Vision Modules Loaded Successfully.")
except Exception as e:
    print(f"[ERROR] Failed to load vision modules: {e}")

def process_face_pipeline(image_path):
    """
    I created this function to run in a separate background thread. 
    It processes the captured image for face recognition without freezing our live camera feed.
    """
    print(f"[VISION] Analyzing captured image: {image_path}")
    
    try:
        # First, I detect if there are any faces in the frame.
        faces = face_detector.detect_faces(image_path)
        face_count = len(faces)
        
        if face_count == 0:
            print("[VISION] No face detected.")
            # Even if no face is found, I log the motion event.
            event_logger.log_event(
                event_type="motion",
                image_path=image_path,
                face_detected=False,
                face_count=0,
                recognized_name=None,
                person_id=None,
                match_score=None,
                status="no_face"
            )
            return

        print(f"[VISION] {face_count} face(s) detected. Extracting embeddings for identification...")
        # If faces are found, I extract their embeddings and try to match them against our database.
        embedding = face_embedder.get_embedding(image_path)
        result = face_matcher.find_best_match(embedding)
        
        print(f"[VISION] Match Result: {result}")
        
        # Finally, I log the complete event with the identification results.
        event_logger.log_event(
            event_type="motion",
            image_path=image_path,
            face_detected=True,
            face_count=face_count,
            recognized_name=result.get("name"),
            person_id=result.get("person_id"),
            match_score=result.get("score"),
            status=result.get("status")
        )
            
    except Exception as error:
        print(f"[VISION ERROR] Pipeline failed: {error}")

def read_dht11():
    """
    This thread continuously reads the DHT11 sensor. 
    I wrapped it in a try-except block because DHT sensors are notoriously unstable and fail often.
    """
    global current_temp, current_hum, dht_log, dht_device
    while True:
        try:
            t = dht_device.temperature
            h = dht_device.humidity
            if t is not None and h is not None:
                current_temp = f"{t:.1f}C"
                current_hum = f"{h:.1f}%"
                dht_log = "READING_OK"
        except RuntimeError as error:
            # This catches common hardware timeouts or checksum errors.
            dht_log = f"HARDWARE_ERROR: {error.args[0]}"
            time.sleep(2.0)
            continue
        except Exception as error:
            # If the sensor crashes completely, I re-initialize the object.
            dht_log = f"CRITICAL_ERROR: {error}"
            dht_device.exit()
            try:
                dht_device = adafruit_dht.DHT11(board.D4, use_pulseio=False)
            except:
                pass
        time.sleep(2.0)

def read_digital_sensors():
    """
    This thread monitors our digital sensors (Gas, Motion, Soil).
    I placed them in a single fast loop to ensure real-time responsiveness.
    """
    global current_gas, current_motion, current_soil
    global is_motion_active, motion_last_detected_time
    
    while True:
        # The MQ2 sensor outputs LOW (0) when it detects gas, so I check for '0'.
        gas_detected = (mq2_sensor.value == 0)
        soil_dry = soil_sensor.value 
        
        # --- MOTION LOGIC ---
        if pir_sensor.value == 1:
            motion_last_detected_time = time.time()
            is_motion_active = True
            current_motion = "DETECTED"
        else:
            # I added a 3-second buffer. The camera stays active for 3 seconds after motion stops.
            if time.time() - motion_last_detected_time > 3.0:
                is_motion_active = False
                current_motion = "None"
        
        current_gas = "ALERT" if gas_detected else "NO GAS"
        current_soil = "DRY" if soil_dry else "WET"
        
        # I print the live status to the terminal for debugging purposes.
        print(f"[STATUS] Temp: {current_temp} | Hum: {current_hum} | Gas: {current_gas} | Motion: {current_motion} | Soil: {current_soil} | DHT_LOG: {dht_log}")
        time.sleep(1.0) 

def main():
    global last_face_capture_time
    print("Initializing CENG 407 Smart Home & Vision Core System...")
    
    # I start the sensor reading functions as background daemon threads.
    threading.Thread(target=read_dht11, daemon=True).start()
    threading.Thread(target=read_digital_sensors, daemon=True).start()
    
    # Initializing the Raspberry Pi Camera.
    try:
        picam2 = Picamera2()
        config = picam2.create_preview_configuration(main={"size": (1280, 720)})
        picam2.configure(config)
        picam2.start()
    except Exception as e:
        print(f"[ERROR] Camera initialization failed: {e}")
        return

    window_open = False

    while True:
        try:
            # I only process and display the video feed if the motion sensor is currently active.
            if is_motion_active:
                frame = picam2.capture_array()
                frame_bgr = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
                
                # Here, I draw the live sensor data directly onto the camera frame (OSD).
                cv2.putText(frame_bgr, f"Temp: {current_temp} Hum: {current_hum}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
                cv2.putText(frame_bgr, f"Gas: {current_gas}", (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255) if current_gas == "ALERT" else (0, 255, 0), 2)
                cv2.putText(frame_bgr, f"Motion: {current_motion}", (10, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                cv2.putText(frame_bgr, f"Soil: {current_soil}", (10, 120), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 165, 255) if current_soil == "DRY" else (255, 0, 0), 2)
                
                cv2.imshow("Smart Home Live Feed", frame_bgr)
                window_open = True
                
                # --- ASYNCHRONOUS FACE RECOGNITION TRIGGER ---
                current_time = time.time()
                # I check if enough time has passed since the last photo was taken (cooldown mechanism).
                if current_time - last_face_capture_time > MOTION_COOLDOWN_SECONDS:
                    last_face_capture_time = current_time
                    timestamp = int(current_time)
                    image_path = str(CAPTURE_DIR / f"motion_{timestamp}.jpg")
                    
                    # I save the current frame to the disk so the vision pipeline can read it.
                    cv2.imwrite(image_path, frame_bgr)
                    
                    # I fire off the face recognition process in a new thread.
                    threading.Thread(target=process_face_pipeline, args=(image_path,), daemon=True).start()

                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break
            else:
                # If motion stops, I wait for the 3-second buffer and then close the camera window.
                if window_open:
                    cv2.destroyAllWindows()
                    window_open = False
                time.sleep(0.1)
                
        except Exception as e:
            print(f"[ERROR] GUI/Video error: {e}")
            break
            
    # Cleaning up resources before shutting down.
    picam2.stop()
    cv2.destroyAllWindows()
    print("System shut down securely.")

if __name__ == '__main__':
    main()