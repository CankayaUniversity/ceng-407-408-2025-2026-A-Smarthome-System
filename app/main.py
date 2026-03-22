import time

from app.camera.capture import CameraCapture
from app.sensors.pir_sensor import PIRSensor

from app.vision.face_detector import FaceDetector
from app.vision.embedder import FaceEmbedder
from app.vision.matcher import FaceMatcher

from app.logging_system.event_logger import EventLogger


def main():
    sensor = PIRSensor()
    camera = CameraCapture()
    detector = FaceDetector()
    embedder = FaceEmbedder()
    matcher = FaceMatcher()
    logger = EventLogger()

    print("System started on Raspberry Pi...")

    try:
        while True:
            if sensor.motion_detected():
                print("Motion detected")

                image_path = camera.capture_frame()
                faces = detector.detect_faces(image_path)
                face_count = len(faces)

                if face_count == 0:
                    print("No face detected")

                    logger.log_event(
                        event_type="motion",
                        image_path=image_path,
                        face_detected=False,
                        face_count=0,
                        recognized_name=None,
                        person_id=None,
                        match_score=None,
                        status="no_face"
                    )

                    time.sleep(2)
                    continue

                print(f"{face_count} face(s) detected")

                try:
                    embedding = embedder.get_embedding(image_path)
                    result = matcher.find_best_match(embedding)

                    print("Match result:", result)

                    logger.log_event(
                        event_type="motion",
                        image_path=image_path,
                        face_detected=True,
                        face_count=face_count,
                        recognized_name=result["name"],
                        person_id=result["person_id"],
                        match_score=result["score"],
                        status=result["status"]
                    )

                except Exception as error:
                    print("Recognition error:", error)

                time.sleep(5)

            time.sleep(0.2)

    except KeyboardInterrupt:
        print("Stopping system...")

    finally:
        camera.close()


if __name__ == "__main__":
    main()