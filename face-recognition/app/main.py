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
from app.storage.auto_collector import AutoCollector

from app.config import BURST_COUNT, BURST_DELAY_SECONDS

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
    auto_collector = AutoCollector()

    # Background resident sync from website
    start_resident_sync_thread()

    logger.info("Smart Home Face Recognition started on Raspberry Pi...")

    try:
        while True:
            if sensor.motion_detected():
                logger.info("Motion detected")

                burst_images = camera.capture_burst(
                    count=BURST_COUNT,
                    delay=BURST_DELAY_SECONDS
                )

                selected_image_path = None
                selected_faces = []

                for image_path in burst_images:
                    faces = detector.detect_faces(image_path)
                    if len(faces) > 0:
                        selected_image_path = image_path
                        selected_faces = faces
                        break

                if selected_image_path is None:
                    logger.info("No face detected in burst frames")

                    fallback_image = burst_images[0] if burst_images else None

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

                    send_camera_event(
                        image_path=fallback_image,
                        result={
                            "status": "unknown",
                            "matched": False,
                            "score": None,
                            "person_id": None,
                        },
                    )

                    time.sleep(2)
                    continue

                face_count = len(selected_faces)
                logger.info(
                    "%d face(s) detected — using frame: %s",
                    face_count,
                    selected_image_path,
                )

                try:
                    embedding = embedder.get_embedding(selected_image_path)
                    result = matcher.find_best_match(embedding)

                    logger.info(
                        "Match result: status=%s name=%s score=%s",
                        result["status"],
                        result.get("name"),
                        result.get("score"),
                    )

                    # Local event log
                    event_logger.log_event(
                        event_type="motion",
                        image_path=selected_image_path,
                        face_detected=True,
                        face_count=face_count,
                        recognized_name=result["name"],
                        person_id=result["person_id"],
                        match_score=result["score"],
                        status=result["status"],
                    )

                    # Send event to website backend
                    send_camera_event(image_path=selected_image_path, result=result)

                    # Save high-confidence authorized samples for future enrichment
                    if auto_collector.should_collect(result, face_count):
                        try:
                            saved_path = auto_collector.save_sample(
                                image_path=selected_image_path,
                                person_name=result["name"]
                            )
                            logger.info("Auto-collected sample saved: %s", saved_path)
                        except Exception as auto_error:
                            logger.warning("Auto-collection failed: %s", auto_error)

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