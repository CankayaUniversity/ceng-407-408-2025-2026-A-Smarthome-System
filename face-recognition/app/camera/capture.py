"""
Camera module wrapping Picamera2 for both live preview and burst capture.

Thread-safety:
  - _camera_lock protects the physical Picamera2 instance (hardware access).
  - _frame_lock protects the shared _latest_bgr frame buffer.

Color format:
  Conversion is controlled by CAMERA_COLOR_MODE env var (see color_utils.py).
  Default: rgb_to_bgr (Picamera2 RGB888 → OpenCV BGR).
"""

import logging
import threading
import time
from pathlib import Path

import cv2
import numpy as np
from picamera2 import Picamera2

from app.config import CAPTURE_DIR, IMAGE_WIDTH, IMAGE_HEIGHT
from app.camera.color_utils import normalize_frame

logger = logging.getLogger(__name__)


class CameraCapture:
    def __init__(self):
        CAPTURE_DIR.mkdir(parents=True, exist_ok=True)
        self.picam2 = Picamera2()
        config = self.picam2.create_preview_configuration(
            main={"size": (IMAGE_WIDTH, IMAGE_HEIGHT), "format": "RGB888"}
        )
        self.picam2.configure(config)
        self.picam2.start()
        # Allow AWB / AE to stabilize
        time.sleep(1.0)

        # Thread-safety locks
        self._camera_lock = threading.Lock()  # protects picam2 hardware calls
        self._frame_lock = threading.Lock()   # protects _latest_bgr buffer
        self._latest_bgr: np.ndarray | None = None

    # ── Thread-safe frame buffer ──────────────────────────────────

    @property
    def latest_frame_bgr(self) -> np.ndarray | None:
        """Return a copy of the most recent BGR frame (thread-safe)."""
        with self._frame_lock:
            return None if self._latest_bgr is None else self._latest_bgr.copy()

    def _update_latest(self, bgr: np.ndarray):
        """Store the frame in the shared buffer."""
        with self._frame_lock:
            self._latest_bgr = bgr

    # ── Capture methods ───────────────────────────────────────────

    def capture_array(self):
        """Return the current frame as a numpy array (BGR)."""
        with self._camera_lock:
            raw = self.picam2.capture_array()
        return normalize_frame(raw)

    def capture_array_bgr(self):
        """Return the current frame as a BGR numpy array (for OpenCV)."""
        with self._camera_lock:
            raw = self.picam2.capture_array()
        bgr = normalize_frame(raw)
        self._update_latest(bgr)
        return bgr

    def grab_relay_frame(self) -> np.ndarray | None:
        """Capture a fresh BGR frame for relay streaming (thread-safe)."""
        try:
            with self._camera_lock:
                raw = self.picam2.capture_array()
            bgr = normalize_frame(raw)
            self._update_latest(bgr)
            return bgr
        except Exception as exc:
            logger.warning("grab_relay_frame failed: %s", exc)
            return None

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
