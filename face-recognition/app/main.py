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


def choose_best_result(frame_results: list[dict]) -> dict | None:
    """
    Burst içindeki tüm frame sonuçları arasından en iyi sonucu seçer.

    Öncelik:
    1. authorized sonuçlar -> en düşük score (distance)
    2. unauthorized sonuçlar -> en düşük score
    3. hiç geçerli sonuç yoksa None
    """
    if not frame_results:
        return None

    authorized = [
        item for item in frame_results
        if item["result"]["status"] == "authorized" and item["result"]["score"] is not None
    ]

    if authorized:
        return min(authorized, key=lambda item: item["result"]["score"])

    unauthorized = [
        item for item in frame_results
        if item["result"]["status"] == "unauthorized" and item["result"]["score"] is not None
    ]

    if unauthorized:
        return min(unauthorized, key=lambda item: item["result"]["score"])

    return None


def main():
    sensor = PIRSensor()
    camera = CameraCapture()
    detector = FaceDetector()
    embedder = FaceEmbedder()
    matcher = FaceMatcher()
    event_logger = EventLogger()
    auto_collector = AutoCollector()

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

                frame_results = []
                no_face_images = []

                for image_path in burst_images:
                    try:
                        faces = detector.detect_faces(image_path)
                        face_count = len(faces)

                        if face_count == 0:
                            no_face_images.append(image_path)
                            logger.info("No face detected in frame: %s", image_path)
                            continue

                        logger.info(
                            "%d face(s) detected in frame: %s",
                            face_count,
                            image_path,
                        )

                        try:
                            embedding = embedder.get_embedding(image_path)
                            result = matcher.find_best_match(embedding)

                            logger.info(
                                "Frame result: status=%s name=%s score=%s image=%s",
                                result["status"],
                                result.get("name"),
                                result.get("score"),
                                image_path,
                            )

                            frame_results.append(
                                {
                                    "image_path": image_path,
                                    "face_count": face_count,
                                    "result": result,
                                }
                            )

                        except Exception as recognition_error:
                            logger.warning(
                                "Recognition failed for frame %s: %s",
                                image_path,
                                recognition_error,
                            )

                    except Exception as detection_error:
                        logger.warning(
                            "Detection failed for frame %s: %s",
                            image_path,
                            detection_error,
                        )

                best = choose_best_result(frame_results)

                if best is None:
                    logger.info("No valid recognition result in burst frames")

                    fallback_image = no_face_images[0] if no_face_images else (
                        burst_images[0] if burst_images else None
                    )

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

                selected_image_path = best["image_path"]
                face_count = best["face_count"]
                result = best["result"]

                logger.info(
                    "Selected best frame: %s | status=%s | name=%s | score=%s",
                    selected_image_path,
                    result["status"],
                    result.get("name"),
                    result.get("score"),
                )

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

                send_camera_event(image_path=selected_image_path, result=result)

                if auto_collector.should_collect(result, face_count):
                    try:
                        saved_path = auto_collector.save_sample(
                            image_path=selected_image_path,
                            person_name=result["name"]
                        )
                        logger.info("Auto-collected sample saved: %s", saved_path)
                    except Exception as auto_error:
                        logger.warning("Auto-collection failed: %s", auto_error)

                time.sleep(5)

            time.sleep(0.2)

    except KeyboardInterrupt:
        logger.info("Stopping system...")

    finally:
        camera.close()


if __name__ == "__main__":
    main()