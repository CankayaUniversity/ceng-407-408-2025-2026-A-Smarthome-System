# -*- coding: utf-8 -*-
import sys
import os
import time
import threading
import logging
from pathlib import Path

# Path and display setup
BASE_DIR = Path(__file__).resolve().parent
sys.path.append(str(BASE_DIR))
os.environ["DISPLAY"] = ":0"

import cv2
import requests
import board
import adafruit_dht
from gpiozero import DigitalInputDevice
from picamera2 import Picamera2

try:
    from dotenv import load_dotenv
    load_dotenv(BASE_DIR / ".env")
except Exception:
    pass

# --- VISION IMPORTS ---
from app.vision.face_detector import FaceDetector
from app.vision.embedder import FaceEmbedder
from app.vision.matcher import FaceMatcher
from app.logging_system.event_logger import EventLogger

# --- LOGGING ---
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# --- CONFIG ---
API_BASE_URL = os.getenv("API_BASE_URL", "http://127.0.0.1:8000").rstrip("/")
API_URL = f"{API_BASE_URL}/api/v1"
DEVICE_ID = os.getenv("DEVICE_ID", "")
REQUEST_TIMEOUT_SECONDS = int(os.getenv("REQUEST_TIMEOUT_SECONDS", "10"))

CLIMATE_INTERVAL_SECONDS = int(os.getenv("CLIMATE_INTERVAL_SECONDS", "60"))
HEARTBEAT_INTERVAL_SECONDS = int(os.getenv("HEARTBEAT_INTERVAL_SECONDS", "30"))
SOIL_ALERT_COOLDOWN_SECONDS = int(os.getenv("SOIL_ALERT_COOLDOWN_SECONDS", "300"))
GAS_ALERT_COOLDOWN_SECONDS = int(os.getenv("GAS_ALERT_COOLDOWN_SECONDS", "60"))

BURST_COUNT = int(os.getenv("BURST_COUNT", "3"))
BURST_DELAY_SECONDS = float(os.getenv("BURST_DELAY_SECONDS", "0.25"))
MOTION_COOLDOWN_SECONDS = int(os.getenv("MOTION_COOLDOWN_SECONDS", "15"))

CAPTURE_DIR = BASE_DIR / "data" / "captures"
CAPTURE_DIR.mkdir(parents=True, exist_ok=True)

# --- SENSOR + CAMERA INIT ---
pir_sensor = DigitalInputDevice(27, pull_up=False)
mq2_sensor = DigitalInputDevice(17, pull_up=False)
soil_sensor = DigitalInputDevice(22)
dht_device = adafruit_dht.DHT11(board.D4, use_pulseio=False)

# --- AI MODULES ---
detector = FaceDetector()
embedder = FaceEmbedder()
matcher = FaceMatcher()
event_logger = EventLogger()

# --- GLOBAL STATE ---
current_temp = 0.0
current_hum = 0.0
current_gas = "NO GAS"
current_soil = "WET"
current_motion = "None"
dht_log = "Initializing..."

is_motion_active = False
motion_last_detected_time = 0.0
last_capture_time = 0.0

prev_gas_state = "NO GAS"
prev_soil_state = "WET"
last_climate_send_time = 0.0
last_gas_alert_time = 0.0
last_soil_alert_time = 0.0


# ----------------------------
# HTTP helpers
# ----------------------------
def _post_json(endpoint: str, payload: dict):
    url = f"{API_URL}{endpoint}"
    try:
        response = requests.post(url, json=payload, timeout=REQUEST_TIMEOUT_SECONDS)
        response.raise_for_status()
        logger.info("POST %s -> %s", endpoint, response.status_code)
        return response.json() if response.content else {}
    except Exception as exc:
        logger.warning("POST %s failed: %s", endpoint, exc)
        return None


def _post_file(endpoint: str, params: dict, file_path: str):
    url = f"{API_URL}{endpoint}"
    try:
        with open(file_path, "rb") as f:
            response = requests.post(
                url,
                params=params,
                files={"file": f},
                timeout=REQUEST_TIMEOUT_SECONDS,
            )
        response.raise_for_status()
        logger.info("UPLOAD %s -> %s", endpoint, response.status_code)
        return response.json() if response.content else {}
    except Exception as exc:
        logger.warning("UPLOAD %s failed: %s", endpoint, exc)
        return None


def send_sensor_telemetry():
    payload = {
        "device_id": DEVICE_ID,
        "temperature": current_temp,
        "humidity": current_hum,
        "gas_detected": current_gas == "ALERT",
        "soil_dry": current_soil == "DRY",
    }
    return _post_json("/telemetry/sensors", payload)


def create_security_event(event_type: str, message: str):
    payload = {
        "device_id": DEVICE_ID,
        "event_type": event_type,
        "message": message,
    }
    return _post_json("/events/security", payload)


def create_alert_event(event_type: str, message: str, priority: str = "warning"):
    payload = {
        "device_id": DEVICE_ID,
        "event_type": event_type,
        "message": message,
        "priority": priority,
    }
    return _post_json("/events/alert", payload)


def upload_intelligent_snapshot(event_id: str, is_resident: bool, image_path: str, resident_id=None):
    params = {
        "event_id": event_id,
        "is_resident": str(is_resident).lower(),
    }
    if resident_id:
        params["resident_id"] = resident_id
    return _post_file("/events/upload-intelligent", params, image_path)


def send_heartbeat():
    payload = {
        "device_id": DEVICE_ID,
        "status": "online",
        "timestamp": time.time(),
    }
    return _post_json("/heartbeat", payload)


# ----------------------------
# Background threads
# ----------------------------
def dht_reading_thread():
    global current_temp, current_hum, dht_log, last_climate_send_time

    while True:
        try:
            t = dht_device.temperature
            h = dht_device.humidity

            if t is not None and h is not None:
                current_temp = float(t)
                current_hum = float(h)
                dht_log = "READING_OK"

                now = time.time()
                if now - last_climate_send_time >= CLIMATE_INTERVAL_SECONDS:
                    last_climate_send_time = now
                    send_sensor_telemetry()

        except RuntimeError as error:
            dht_log = f"HARDWARE_ERROR: {error.args[0]}"
        except Exception as error:
            dht_log = f"CRITICAL_ERROR: {error}"
            try:
                dht_device.exit()
            except Exception:
                pass

        time.sleep(2)


def digital_sensor_thread():
    global current_gas, current_soil, current_motion
    global is_motion_active, motion_last_detected_time
    global prev_gas_state, prev_soil_state, last_gas_alert_time, last_soil_alert_time

    while True:
        gas_detected = (mq2_sensor.value == 0)
        soil_dry = bool(soil_sensor.value)

        # Motion state
        if pir_sensor.value == 1:
            motion_last_detected_time = time.time()
            is_motion_active = True
            current_motion = "DETECTED"
        else:
            if time.time() - motion_last_detected_time > 3.0:
                is_motion_active = False
                current_motion = "None"

        new_gas = "ALERT" if gas_detected else "NO GAS"
        new_soil = "DRY" if soil_dry else "WET"
        now = time.time()

        # Gas transition hook
        if new_gas != prev_gas_state:
            if now - last_gas_alert_time >= GAS_ALERT_COOLDOWN_SECONDS:
                last_gas_alert_time = now
                if new_gas == "ALERT":
                    create_alert_event(
                        event_type="fire_alert",
                        message="Gas/smoke detected by MQ2 sensor.",
                        priority="critical",
                    )
                else:
                    create_alert_event(
                        event_type="fire_alert_cleared",
                        message="Gas/smoke alert cleared.",
                        priority="info",
                    )
            prev_gas_state = new_gas

        # Soil transition hook
        if new_soil != prev_soil_state:
            if now - last_soil_alert_time >= SOIL_ALERT_COOLDOWN_SECONDS:
                last_soil_alert_time = now
                if new_soil == "DRY":
                    create_alert_event(
                        event_type="low_moisture",
                        message="Soil moisture is critically low.",
                        priority="warning",
                    )
                else:
                    create_alert_event(
                        event_type="moisture_restored",
                        message="Soil moisture restored.",
                        priority="info",
                    )
            prev_soil_state = new_soil

        current_gas = new_gas
        current_soil = new_soil

        logger.info(
            "STATUS | Temp: %.1fC | Hum: %.1f%% | Gas: %s | Motion: %s | Soil: %s | DHT: %s",
            current_temp, current_hum, current_gas, current_motion, current_soil, dht_log,
        )

        time.sleep(1)


def heartbeat_thread():
    while True:
        send_heartbeat()
        time.sleep(HEARTBEAT_INTERVAL_SECONDS)


# ----------------------------
# Face recognition helpers
# ----------------------------
def choose_best_result(frame_results: list[dict]):
    if not frame_results:
        return None

    def _frame_sort_key(frame):
        faces = frame.get("face_results", [])
        authorized_count = sum(1 for f in faces if f["status"] == "authorized")
        total_count = len(faces)
        scores = [f["confidence"] for f in faces if f["confidence"] is not None]
        avg_score = sum(scores) / len(scores) if scores else float("inf")
        return (-authorized_count, -total_count, avg_score)

    return min(frame_results, key=_frame_sort_key)


def _get_embedding_for_crop(crop, fallback_image_path):
    if hasattr(embedder, "get_embedding_from_crop"):
        return embedder.get_embedding_from_crop(crop)
    return embedder.get_embedding(fallback_image_path)


def analyze_burst_and_upload(image_paths: list[str]):
    try:
        frame_results = []
        no_face_images = []

        for image_path in image_paths:
            faces = detector.detect_faces(image_path)
            face_count = len(faces)

            if face_count == 0:
                no_face_images.append(image_path)
                logger.info("No face detected in frame: %s", image_path)
                continue

            logger.info("%d face(s) detected in frame: %s", face_count, image_path)

            image = cv2.imread(image_path)
            if image is None:
                logger.warning("Could not read image: %s", image_path)
                continue

            img_h, img_w = image.shape[:2]
            face_results_list = []

            for bbox in faces:
                x, y, w, h = bbox
                x1 = max(0, x)
                y1 = max(0, y)
                x2 = min(img_w, x + w)
                y2 = min(img_h, y + h)

                crop = image[y1:y2, x1:x2]
                if crop.size == 0:
                    continue

                try:
                    embedding = _get_embedding_for_crop(crop, image_path)
                    if embedding is None:
                        continue

                    result = matcher.find_best_match(embedding)

                    face_results_list.append({
                        "bbox": [x1, y1, x2, y2],
                        "label": result.get("name"),
                        "confidence": result.get("score"),
                        "status": result.get("status", "unknown"),
                        "person_id": result.get("person_id"),
                        "matched": result.get("matched", False),
                    })

                    logger.info(
                        "Face bbox=%s status=%s name=%s score=%s",
                        [x1, y1, x2, y2],
                        result.get("status"),
                        result.get("name"),
                        result.get("score"),
                    )

                except Exception as recognition_error:
                    logger.warning(
                        "Recognition failed for bbox %s in %s: %s",
                        bbox, image_path, recognition_error,
                    )

            if face_results_list:
                frame_results.append({
                    "image_path": image_path,
                    "face_count": face_count,
                    "face_results": face_results_list,
                })

        best = choose_best_result(frame_results)

        if best is None:
            fallback_image = no_face_images[0] if no_face_images else (image_paths[0] if image_paths else None)

            event_logger.log_event(
                event_type="motion",
                image_path=fallback_image,
                face_detected=False,
                face_count=0,
                recognized_name=None,
                person_id=None,
                match_score=None,
                status="no_face",
            )

            response = create_security_event(
                event_type="unknown_motion",
                message="Motion detected but no face identified.",
            )
            if response and fallback_image:
                upload_intelligent_snapshot(
                    event_id=response["event_id"],
                    is_resident=False,
                    image_path=fallback_image,
                )
            return

        selected_image_path = best["image_path"]
        face_count = best["face_count"]
        face_results = best["face_results"]

        primary = face_results[0]
        for fr in face_results:
            if fr["status"] == "authorized":
                primary = fr
                break

        faces_summary = [
            "{}({})".format(
                fr.get("label") or "Unknown",
                fr.get("confidence") if fr.get("confidence") is not None else "?",
            )
            for fr in face_results
        ]

        logger.info(
            "Selected best frame: %s | faces=%d | summary=%s",
            selected_image_path,
            face_count,
            faces_summary,
        )

        event_logger.log_event(
            event_type="motion",
            image_path=selected_image_path,
            face_detected=True,
            face_count=face_count,
            recognized_name=primary.get("label"),
            person_id=primary.get("person_id"),
            match_score=primary.get("confidence"),
            status=primary.get("status"),
            faces_summary=faces_summary,
        )

        is_resident = primary.get("status") == "authorized"
        event_type = "resident_entry" if is_resident else "stranger_detected"
        message = "Known resident identified." if is_resident else "Unauthorized visitor detected."

        response = create_security_event(event_type=event_type, message=message)
        if response:
            upload_intelligent_snapshot(
                event_id=response["event_id"],
                is_resident=is_resident,
                resident_id=primary.get("person_id"),
                image_path=selected_image_path,
            )

    except Exception as exc:
        logger.error("Surveillance pipeline failed: %s", exc)


# ----------------------------
# Main loop
# ----------------------------
def main():
    global last_capture_time

    logger.info("Initializing Smart Home Edge Core...")

    threading.Thread(target=dht_reading_thread, daemon=True).start()
    threading.Thread(target=digital_sensor_thread, daemon=True).start()
    threading.Thread(target=heartbeat_thread, daemon=True).start()

    try:
        picam2 = Picamera2()
        config = picam2.create_preview_configuration(main={"size": (1280, 720)})
        picam2.configure(config)
        picam2.start()
    except Exception as e:
        logger.error("Camera initialization failed: %s", e)
        return

    window_open = False

    try:
        while True:
            if is_motion_active:
                frame = picam2.capture_array()
                frame_bgr = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

                cv2.putText(frame_bgr, f"Temp: {current_temp:.1f}C Hum: {current_hum:.1f}%", (10, 30),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
                cv2.putText(frame_bgr, f"Gas: {current_gas}", (10, 60),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7,
                            (0, 0, 255) if current_gas == "ALERT" else (0, 255, 0), 2)
                cv2.putText(frame_bgr, f"Motion: {current_motion}", (10, 90),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                cv2.putText(frame_bgr, f"Soil: {current_soil}", (10, 120),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7,
                            (0, 165, 255) if current_soil == "DRY" else (255, 0, 0), 2)

                cv2.imshow("Smart Home Intelligent Feed", frame_bgr)
                window_open = True

                current_time = time.time()
                if current_time - last_capture_time > MOTION_COOLDOWN_SECONDS:
                    last_capture_time = current_time

                    burst_images = []
                    for i in range(BURST_COUNT):
                        burst_frame = picam2.capture_array()
                        burst_bgr = cv2.cvtColor(burst_frame, cv2.COLOR_RGB2BGR)
                        timestamp = int(time.time() * 1000)
                        image_path = str(CAPTURE_DIR / f"motion_{timestamp}_{i}.jpg")
                        cv2.imwrite(image_path, burst_bgr)
                        burst_images.append(image_path)
                        time.sleep(BURST_DELAY_SECONDS)

                    threading.Thread(
                        target=analyze_burst_and_upload,
                        args=(burst_images,),
                        daemon=True,
                    ).start()

                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break
            else:
                if window_open:
                    cv2.destroyAllWindows()
                    window_open = False
                time.sleep(0.2)

    except KeyboardInterrupt:
        logger.info("Stopping system...")

    finally:
        try:
            picam2.stop()
        except Exception:
            pass
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()