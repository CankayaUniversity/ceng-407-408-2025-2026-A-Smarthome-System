import time
from app.config import POLL_INTERVAL_SECONDS, MOTION_COOLDOWN_SECONDS
from app.sensors.pir_sensor import PIRSensor
from app.camera.capture import CameraCapture
from app.vision.face_detector import FaceDetector
from app.logging_system.event_logger import EventLogger


def main():
    pir_sensor = PIRSensor()
    camera = CameraCapture()
    detector = FaceDetector()
    logger = EventLogger()

    print("System started. Waiting for motion...")

    try:
        while True:
            if pir_sensor.motion_detected():
                print("Motion detected. Capturing image...")

                image_path = camera.capture_frame()
                faces = detector.detect_faces(image_path)
                face_count = len(faces)
                face_detected = face_count > 0

                logger.log_event(
                    event_type="motion_detected",
                    image_path=image_path,
                    face_detected=face_detected,
                    face_count=face_count,
                    notes="Sprint 1 pipeline executed"
                )

                print(
                    f"Capture saved: {image_path} | "
                    f"face_detected={face_detected} | "
                    f"face_count={face_count}"
                )

                time.sleep(MOTION_COOLDOWN_SECONDS)

            time.sleep(POLL_INTERVAL_SECONDS)

    except KeyboardInterrupt:
        print("Stopping system...")

    finally:
        camera.close()


if __name__ == "__main__":
    main()