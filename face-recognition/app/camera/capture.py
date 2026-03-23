from datetime import datetime
from pathlib import Path
from picamera2 import Picamera2
from app.config import CAPTURE_DIR, IMAGE_WIDTH, IMAGE_HEIGHT


class CameraCapture:
    def __init__(self):
        CAPTURE_DIR.mkdir(parents=True, exist_ok=True)
        self.picam2 = Picamera2()

        config = self.picam2.create_still_configuration(
            main={"size": (IMAGE_WIDTH, IMAGE_HEIGHT)}
        )
        self.picam2.configure(config)
        self.picam2.start()

    def capture_frame(self) -> str:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        image_path = CAPTURE_DIR / f"capture_{timestamp}.jpg"
        self.picam2.capture_file(str(image_path))
        return str(image_path)

    def close(self):
        self.picam2.stop()