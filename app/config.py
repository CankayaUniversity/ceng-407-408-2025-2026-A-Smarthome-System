from pathlib import Path

# GPIO
PIR_GPIO_PIN = 17

# Timing
POLL_INTERVAL_SECONDS = 0.2
MOTION_COOLDOWN_SECONDS = 5

# Camera
CAPTURE_DIR = Path("data/captures")
IMAGE_WIDTH = 1280
IMAGE_HEIGHT = 720

# Logging
EVENTS_LOG_PATH = Path("app/storage/events.jsonl")

# Face detection
# OpenCV haarcascade dosyası otomatik bulunacak
MIN_FACE_SIZE = (60, 60)
SCALE_FACTOR = 1.1
MIN_NEIGHBORS = 5