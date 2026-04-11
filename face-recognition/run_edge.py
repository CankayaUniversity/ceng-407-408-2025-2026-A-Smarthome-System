# -*- coding: utf-8 -*-
"""
Smart Home Edge Controller — Raspberry Pi entry point.

Orchestrates sensor reading, camera capture, face recognition,
and communication with the FastAPI gateway (main.py → Supabase).
"""

import sys
import os
import time
import threading
import logging
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))
os.environ.setdefault("DISPLAY", ":0")

import cv2
import board
import adafruit_dht
from gpiozero import DigitalInputDevice

from app.config import (
    PIR_GPIO_PIN,
    CLIMATE_INTERVAL_SECONDS,
    HEARTBEAT_INTERVAL_SECONDS,
    GAS_ALERT_COOLDOWN_SECONDS,
    SOIL_ALERT_COOLDOWN_SECONDS,
    BURST_COUNT,
    BURST_DELAY_SECONDS,
    MOTION_COOLDOWN_SECONDS,
)
from app.camera.capture import CameraCapture
from app.vision.face_detector import FaceDetector
from app.vision.embedder import FaceEmbedder
from app.vision.matcher import FaceMatcher
from app.logging_system.event_logger import EventLogger
from app.api.gateway_client import (
    send_sensor_telemetry,
    create_alert_event,
    create_security_event,
    upload_intelligent_snapshot,
    send_heartbeat,
)
from app.api.resident_sync import start_resident_sync_thread

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("edge")

# ── Hardware init ──────────────────────────────────────────────
pir_sensor = DigitalInputDevice(PIR_GPIO_PIN, pull_up=False)
mq2_sensor = DigitalInputDevice(17, pull_up=False)
soil_sensor = DigitalInputDevice(22)
dht_device = adafruit_dht.DHT11(board.D4, use_pulseio=False)

# ── AI modules ─────────────────────────────────────────────────
detector = FaceDetector()
embedder = FaceEmbedder()
matcher = FaceMatcher()
event_logger = EventLogger()

# ── Shared state ───────────────────────────────────────────────
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


# ── Background threads ────────────────────────────────────────
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
                    send_sensor_telemetry(
                        current_temp, current_hum,
                        current_gas == "ALERT", current_soil == "DRY",
                    )
        except RuntimeError as err:
            dht_log = f"HARDWARE_ERROR: {err.args[0]}"
        except Exception as err:
            dht_log = f"CRITICAL_ERROR: {err}"
            try:
                dht_device.exit()
            except Exception:
                pass
        time.sleep(2)


def digital_sensor_thread():
    global current_gas, current_soil, current_motion
    global is_motion_active, motion_last_detected_time
    global prev_gas_state, prev_soil_state
    global last_gas_alert_time, last_soil_alert_time

    while True:
        gas_detected = mq2_sensor.value == 0
        soil_dry = bool(soil_sensor.value)

        if pir_sensor.value == 1:
            motion_last_detected_time = time.time()
            is_motion_active = True
            current_motion = "DETECTED"
        elif time.time() - motion_last_detected_time > 3.0:
            is_motion_active = False
            current_motion = "None"

        new_gas = "ALERT" if gas_detected else "NO GAS"
        new_soil = "DRY" if soil_dry else "WET"
        now = time.time()

        if new_gas != prev_gas_state:
            if now - last_gas_alert_time >= GAS_ALERT_COOLDOWN_SECONDS:
                last_gas_alert_time = now
                if new_gas == "ALERT":
                    create_alert_event("fire_alert",
                                       "Gas/smoke detected by MQ2 sensor.",
                                       "critical")
                else:
                    create_alert_event("fire_alert_cleared",
                                       "Gas/smoke alert cleared.", "info")
            prev_gas_state = new_gas

        if new_soil != prev_soil_state:
            if now - last_soil_alert_time >= SOIL_ALERT_COOLDOWN_SECONDS:
                last_soil_alert_time = now
                if new_soil == "DRY":
                    create_alert_event("low_moisture",
                                       "Soil moisture is critically low.",
                                       "warning")
                else:
                    create_alert_event("moisture_restored",
                                       "Soil moisture restored.", "info")
            prev_soil_state = new_soil

        current_gas = new_gas
        current_soil = new_soil

        logger.info(
            "STATUS | Temp: %.1fC | Hum: %.1f%% | Gas: %s | Motion: %s | Soil: %s | DHT: %s",
            current_temp, current_hum, current_gas, current_motion,
            current_soil, dht_log,
        )
        time.sleep(1)


def heartbeat_loop():
    while True:
        send_heartbeat()
        time.sleep(HEARTBEAT_INTERVAL_SECONDS)


# ── Face recognition pipeline ─────────────────────────────────
def _get_embedding_for_crop(crop, fallback_path):
    if hasattr(embedder, "get_embedding_from_crop"):
        return embedder.get_embedding_from_crop(crop)
    return embedder.get_embedding(fallback_path)


def _choose_best_result(frame_results):
    if not frame_results:
        return None

    def _key(frame):
        faces = frame.get("face_results", [])
        auth = sum(1 for f in faces if f["status"] == "authorized")
        total = len(faces)
        scores = [f["confidence"] for f in faces if f["confidence"] is not None]
        avg = sum(scores) / len(scores) if scores else float("inf")
        return (-auth, -total, avg)

    return min(frame_results, key=_key)


def analyze_burst_and_upload(image_paths: list[str]):
    try:
        frame_results = []
        no_face_images = []

        for image_path in image_paths:
            faces = detector.detect_faces(image_path)
            if not faces:
                no_face_images.append(image_path)
                logger.info("No face in frame: %s", image_path)
                continue

            logger.info("%d face(s) in frame: %s", len(faces), image_path)
            image = cv2.imread(image_path)
            if image is None:
                continue

            img_h, img_w = image.shape[:2]
            face_results_list = []

            for bbox in faces:
                x, y, w, h = bbox
                x1, y1 = max(0, x), max(0, y)
                x2, y2 = min(img_w, x + w), min(img_h, y + h)
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
                except Exception as e:
                    logger.warning("Recognition failed for bbox %s: %s", bbox, e)

            if face_results_list:
                frame_results.append({
                    "image_path": image_path,
                    "face_count": len(faces),
                    "face_results": face_results_list,
                })

        best = _choose_best_result(frame_results)

        if best is None:
            fallback = (no_face_images or image_paths or [None])[0]
            event_logger.log_event(
                event_type="motion", image_path=fallback,
                face_detected=False, face_count=0, status="no_face",
            )
            logger.info("No face in burst — skipping cloud upload.")
            return

        selected_path = best["image_path"]
        face_results = best["face_results"]
        face_count = best["face_count"]

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

        event_logger.log_event(
            event_type="motion", image_path=selected_path,
            face_detected=True, face_count=face_count,
            recognized_name=primary.get("label"),
            person_id=primary.get("person_id"),
            match_score=primary.get("confidence"),
            status=primary.get("status"),
            faces_summary=faces_summary,
        )

        is_resident = primary.get("status") == "authorized"
        evt_type = "resident_entry" if is_resident else "stranger_detected"
        msg = ("Known resident identified." if is_resident
               else "Unauthorized visitor detected.")

        response = create_security_event(event_type=evt_type, message=msg)
        if response:
            upload_intelligent_snapshot(
                event_id=response["event_id"],
                is_resident=is_resident,
                resident_id=primary.get("person_id"),
                image_path=selected_path,
            )

    except Exception as exc:
        logger.error("Surveillance pipeline failed: %s", exc)


# ── Main loop ─────────────────────────────────────────────────
_recognition_busy = threading.Event()


def _safe_analyze(image_paths):
    """Run recognition then clear the busy flag."""
    try:
        analyze_burst_and_upload(image_paths)
    finally:
        _recognition_busy.clear()


def main():
    global last_capture_time

    logger.info("Initializing Smart Home Edge Core...")

    sync_interval = int(os.environ.get("SYNC_RESIDENTS_INTERVAL", "60"))
    start_resident_sync_thread(interval=sync_interval)

    threading.Thread(target=dht_reading_thread, daemon=True).start()
    threading.Thread(target=digital_sensor_thread, daemon=True).start()
    threading.Thread(target=heartbeat_loop, daemon=True).start()

    try:
        camera = CameraCapture()
    except Exception as e:
        logger.error("Camera init failed: %s", e)
        return

    window_open = False
    PREVIEW_FPS = 10

    try:
        while True:
            if is_motion_active:
                frame_bgr = camera.capture_array_bgr()

                cv2.putText(frame_bgr,
                            f"Temp: {current_temp:.1f}C  Hum: {current_hum:.1f}%",
                            (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7,
                            (0, 255, 255), 2)
                cv2.putText(frame_bgr, f"Gas: {current_gas}", (10, 60),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7,
                            (0, 0, 255) if current_gas == "ALERT"
                            else (0, 255, 0), 2)
                cv2.putText(frame_bgr, f"Motion: {current_motion}", (10, 90),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                cv2.putText(frame_bgr, f"Soil: {current_soil}", (10, 120),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7,
                            (0, 165, 255) if current_soil == "DRY"
                            else (255, 0, 0), 2)

                cv2.imshow("Smart Home Intelligent Feed", frame_bgr)
                window_open = True

                now = time.time()
                if (now - last_capture_time > MOTION_COOLDOWN_SECONDS
                        and not _recognition_busy.is_set()):
                    last_capture_time = now
                    _recognition_busy.set()
                    burst_images = camera.capture_burst(BURST_COUNT,
                                                       BURST_DELAY_SECONDS)
                    threading.Thread(
                        target=_safe_analyze,
                        args=(burst_images,),
                        daemon=True,
                    ).start()

                wait_ms = max(1, int(1000 / PREVIEW_FPS))
                if cv2.waitKey(wait_ms) & 0xFF == ord("q"):
                    break
            else:
                if window_open:
                    cv2.destroyAllWindows()
                    window_open = False
                time.sleep(0.5)

    except KeyboardInterrupt:
        logger.info("Stopping system...")
    finally:
        camera.close()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
