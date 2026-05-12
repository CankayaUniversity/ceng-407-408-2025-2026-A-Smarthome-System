"""
Camera color conversion utility.

Provides a single helper that normalises Picamera2 frames based on the
CAMERA_COLOR_MODE environment variable.  Run with different values to
visually determine the correct mode for your hardware:

    CAMERA_COLOR_MODE=rgb_to_bgr  python3 stream_camera.py   # default
    CAMERA_COLOR_MODE=no_convert  python3 stream_camera.py
    CAMERA_COLOR_MODE=bgr_to_rgb  python3 stream_camera.py
"""

import logging
import os

import cv2

logger = logging.getLogger(__name__)

CAMERA_COLOR_MODE = os.environ.get("CAMERA_COLOR_MODE", "no_convert").lower().strip()

# Log once at import time so it's obvious which mode is active
logger.info("CAMERA_COLOR_MODE = %s", CAMERA_COLOR_MODE)


def normalize_frame(frame):
    """
    Convert a raw Picamera2 capture_array() frame into the format expected
    by OpenCV (BGR) for imencode / imwrite / imshow.

    Modes:
      rgb_to_bgr  — Picamera2 outputs RGB888, convert to BGR (most common).
      no_convert  — Use the frame as-is (if camera already outputs BGR).
      bgr_to_rgb  — Picamera2 outputs BGR888, convert to RGB (unusual, for testing).
    """
    if CAMERA_COLOR_MODE == "no_convert":
        return frame
    if CAMERA_COLOR_MODE == "rgb_to_bgr":
        return cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
    if CAMERA_COLOR_MODE == "bgr_to_rgb":
        return cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    logger.warning("Unknown CAMERA_COLOR_MODE='%s', falling back to rgb_to_bgr", CAMERA_COLOR_MODE)
    return cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
