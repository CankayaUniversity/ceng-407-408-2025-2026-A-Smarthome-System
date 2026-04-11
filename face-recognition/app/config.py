import os
from pathlib import Path

# ─── Base directories ─────────────────────────────────────────
BASE_DIR = Path(__file__).resolve().parent.parent  # face-recognition/
PROJECT_ROOT = BASE_DIR.parent                     # bitirmeProject/

# ─── Shared .env loader ──────────────────────────────────────
_ENV_PATH = PROJECT_ROOT / ".env"
if _ENV_PATH.exists():
    with open(_ENV_PATH, "r", encoding="utf-8") as _f:
        for _line in _f:
            _line = _line.strip()
            if not _line or _line.startswith("#"):
                continue
            if "=" in _line:
                _key, _, _val = _line.partition("=")
                _key = _key.strip()
                _val = _val.strip()
                if _key not in os.environ:
                    os.environ[_key] = _val

# ─── GPIO / Hardware ─────────────────────────────────────────
PIR_GPIO_PIN = 27

# ─── Timing ──────────────────────────────────────────────────
POLL_INTERVAL_SECONDS = 0.2
MOTION_COOLDOWN_SECONDS = 5
MOTION_CONFIRMATION_CHECKS = 3
MOTION_CONFIRMATION_INTERVAL = 0.2
MOTION_CONFIRMATION_REQUIRED = 2

# ─── Camera ──────────────────────────────────────────────────
CAPTURE_DIR = BASE_DIR / "data" / "captures"
IMAGE_WIDTH = 1280
IMAGE_HEIGHT = 720
BURST_COUNT = 3
BURST_DELAY_SECONDS = 0.3

# ─── Logging ─────────────────────────────────────────────────
EVENTS_LOG_PATH = BASE_DIR / "app" / "storage" / "events.jsonl"

# ─── Storage ─────────────────────────────────────────────────
RESIDENTS_FILE = BASE_DIR / "app" / "storage" / "residents.json"

# ─── FastAPI Gateway (the main.py running on same host or cloud) ─
API_BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8000")
DEVICE_API_KEY = os.environ.get("DEVICE_API_KEY", "")
DEVICE_ID = os.environ.get("DEVICE_ID", "")

# ─── Sensor intervals ────────────────────────────────────────
CLIMATE_INTERVAL_SECONDS = int(os.environ.get("CLIMATE_INTERVAL_SECONDS", "60"))
HEARTBEAT_INTERVAL_SECONDS = int(os.environ.get("HEARTBEAT_INTERVAL_SECONDS", "30"))
GAS_ALERT_COOLDOWN_SECONDS = int(os.environ.get("GAS_ALERT_COOLDOWN_SECONDS", "60"))
SOIL_ALERT_COOLDOWN_SECONDS = int(os.environ.get("SOIL_ALERT_COOLDOWN_SECONDS", "300"))
