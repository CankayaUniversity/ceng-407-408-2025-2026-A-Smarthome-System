import logging
import time
import cv2

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
    Burst içindeki frame sonuçları arasından en iyi frame'i seçer.

    Her frame: {image_path, face_count, face_results: [...]}

    Seçim kriteri (score = euclidean distance, düşük = daha iyi):
    1. En çok authorized yüz sayısı olan frame
    2. Eşitse en çok toplam yüz sayısı olan frame
    3. Hâlâ eşitse en düşük ortalama confidence (distance) olan frame
    """
    if not frame_results:
        return None

    def _frame_sort_key(frame):
        faces = frame.get("face_results", [])
        authorized_count = sum(1 for f in faces if f["status"] == "authorized")
        total_count = len(faces)
        scores = [f["confidence"] for f in faces if f["confidence"] is not None]
        avg_score = sum(scores) / len(scores) if scores else float("inf")
        # Negate authorized_count and total_count so min() picks the highest
        return (-authorized_count, -total_count, avg_score)

    return min(frame_results, key=_frame_sort_key)


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
                                logger.debug("Empty crop for bbox %s, skipping", bbox)
                                continue

                            try:
                                embedding = embedder.get_embedding_from_crop(crop)
                                if embedding is None:
                                    logger.debug("No embedding from crop bbox %s", bbox)
                                    continue

                                result = matcher.find_best_match(embedding)

                                face_results_list.append({
                                    "bbox": [x1, y1, x2, y2],
                                    "label": result.get("name"),
                                    "confidence": result.get("score"),
                                    "status": result["status"],
                                    "person_id": result.get("person_id"),
                                    "matched": result.get("matched", False),
                                })

                                logger.info(
                                    "Face bbox=%s status=%s name=%s score=%s",
                                    [x1, y1, x2, y2],
                                    result["status"],
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
                                "face_count": len(faces),
                                "face_results": face_results_list,
                            })

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
                face_results = best["face_results"]

                # Pick primary face for legacy fields (first authorized or best score)
                primary = face_results[0]
                for fr in face_results:
                    if fr["status"] == "authorized":
                        primary = fr
                        break

                # Build compact summary for logging: ["Ahmet(0.32)", "Unknown(0.78)"]
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

                send_camera_event(
                    image_path=selected_image_path,
                    result={
                        "status": primary.get("status", "unknown"),
                        "matched": primary.get("matched", False),
                        "score": primary.get("confidence"),
                        "person_id": primary.get("person_id"),
                    },
                    face_results=face_results,
                )

                # AutoCollector: only runs when single face in frame
                if auto_collector.should_collect(
                    {"status": primary.get("status"), "name": primary.get("label"),
                     "score": primary.get("confidence")},
                    face_count,
                ):
                    try:
                        saved_path = auto_collector.save_sample(
                            image_path=selected_image_path,
                            person_name=primary["label"]
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