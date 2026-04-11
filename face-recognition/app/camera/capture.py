"""
Camera module wrapping Picamera2 for both live preview and burst capture.
"""

import time
from datetime import datetime
from pathlib import Path

import cv2
from picamera2 import Picamera2

from app.config import CAPTURE_DIR, IMAGE_WIDTH, IMAGE_HEIGHT


class CameraCapture:
    def __init__(self):
        CAPTURE_DIR.mkdir(parents=True, exist_ok=True)
        self.picam2 = Picamera2()
        config = self.picam2.create_preview_configuration(
            main={"size": (IMAGE_WIDTH, IMAGE_HEIGHT)}
        )
        self.picam2.configure(config)
        self.picam2.start()

    def capture_array(self):
        """Return the current frame as a numpy array (RGB)."""
        return self.picam2.capture_array()

    def capture_array_bgr(self):
        """Return the current frame as a BGR numpy array (for OpenCV)."""
        frame = self.picam2.capture_array()
        return cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

    def capture_burst(self, count: int = 3, delay: float = 0.25) -> list[str]:
        """Capture a burst of images and save to disk. Returns file paths."""
        paths = []
        for i in range(count):
            frame_bgr = self.capture_array_bgr()
            timestamp = int(time.time() * 1000)
            path = str(CAPTURE_DIR / f"motion_{timestamp}_{i}.jpg")
            cv2.imwrite(path, frame_bgr)
            paths.append(path)
            if i < count - 1:
                time.sleep(delay)
        return paths

    def close(self):
        try:
            self.picam2.stop()
        except Exception:
            pass
