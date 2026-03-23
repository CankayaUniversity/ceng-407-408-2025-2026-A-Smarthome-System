import logging
import time

from app.camera.capture import CameraCapture
from app.sensors.pir_sensor import PIRSensor

from app.vision.face_detector import FaceDetector
from app.vision.embedder import FaceEmbedder
from app.vision.matcher import FaceMatcher

from app.logging_system.event_logger import EventLogger
from app.api.client import send_camera_event
from app.api.resident_sync import start_resident_sync_thread

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


def main():
    sensor = PIRSensor()
    camera = CameraCapture()
    detector = FaceDetector()
    embedder = FaceEmbedder()
    matcher = FaceMatcher()
    event_logger = EventLogger()

    # Start background thread that syncs resident embeddings from the website every 60s
    start_resident_sync_thread()

    logger.info("Smart Home Face Recognition started on Raspberry Pi...")

    try:
        while True:
            if sensor.motion_detected():
                logger.info("Motion detected")

                image_path = camera.capture_frame()
                faces = detector.detect_faces(image_path)
                face_count = len(faces)

                if face_count == 0:
                    logger.info("No face detected in captured frame")

                    event_logger.log_event(
                        event_type="motion",
                        image_path=image_path,
                        face_detected=False,
                        face_count=0,
                        recognized_name=None,
                        person_id=None,
                        match_score=None,
                        status="no_face",
                    )

                    # Send to website as "unknown" event (no face)
                    send_camera_event(
                        image_path=image_path,
                        result={"status": "unknown", "matched": False, "score": None, "person_id": None},
                    )

                    time.sleep(2)
                    continue

                logger.info("%d face(s) detected — running recognition", face_count)

                try:
                    embedding = embedder.get_embedding(image_path)
                    result = matcher.find_best_match(embedding)

                    logger.info(
                        "Match result: status=%s name=%s score=%s",
                        result["status"],
                        result.get("name"),
                        result.get("score"),
                    )

                    # Log locally
                    event_logger.log_event(
                        event_type="motion",
                        image_path=image_path,
                        face_detected=True,
                        face_count=face_count,
                        recognized_name=result["name"],
                        person_id=result["person_id"],
                        match_score=result["score"],
                        status=result["status"],
                    )

                    # Send to website backend (best-effort — offline graceful)
                    send_camera_event(image_path=image_path, result=result)

                except Exception as error:
                    logger.error("Recognition error: %s", error)

                time.sleep(5)

            time.sleep(0.2)

    except KeyboardInterrupt:
        logger.info("Stopping system...")

    finally:
        camera.close()


if __name__ == "__main__":
    main()