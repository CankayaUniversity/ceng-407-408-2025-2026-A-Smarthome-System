"""
Cloud configuration loader.

Reads settings from a .env file (if present) with hardcoded fallbacks.
All cloud modules import their settings from here.
"""

import os
from pathlib import Path

# Try to load .env file from project root
_ENV_PATH = Path(__file__).resolve().parent.parent / ".env"
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
                # Only set if not already in environment (env vars take precedence)
                if _key not in os.environ:
                    os.environ[_key] = _val

# ─── Backend Connection ──────────────────────────────────────
API_BASE_URL = os.environ.get("API_BASE_URL", "http://172.20.10.2:3001")
DEVICE_API_KEY = os.environ.get("DEVICE_API_KEY", "299a842f-0dc9-467d-b5c6-8f30cc9e2410")

# ─── Sensor IDs (set after device registration on backend) ───
SENSOR_ID_TEMPERATURE = os.environ.get("SENSOR_ID_TEMPERATURE", "")
SENSOR_ID_HUMIDITY = os.environ.get("SENSOR_ID_HUMIDITY", "")
SENSOR_ID_GAS = os.environ.get("SENSOR_ID_GAS", "")
SENSOR_ID_SOIL = os.environ.get("SENSOR_ID_SOIL", "")

# ─── Local Buffer ────────────────────────────────────────────
LOCAL_BUFFER_DIR = Path(os.environ.get("LOCAL_BUFFER_DIR", "data"))
QUEUE_DB_PATH = LOCAL_BUFFER_DIR / "cloud_queue.db"

# ─── Intervals (seconds) ────────────────────────────────────
CLIMATE_INTERVAL_SECONDS = int(os.environ.get("CLIMATE_INTERVAL_SECONDS", "60"))
HEARTBEAT_INTERVAL_SECONDS = int(os.environ.get("HEARTBEAT_INTERVAL_SECONDS", "30"))
SYNC_RETRY_INTERVAL_SECONDS = int(os.environ.get("SYNC_RETRY_INTERVAL_SECONDS", "15"))

# ─── Cooldowns (seconds) ────────────────────────────────────
SOIL_ALERT_COOLDOWN_SECONDS = int(os.environ.get("SOIL_ALERT_COOLDOWN_SECONDS", "300"))
GAS_ALERT_COOLDOWN_SECONDS = int(os.environ.get("GAS_ALERT_COOLDOWN_SECONDS", "60"))

# ─── Request Settings ───────────────────────────────────────
REQUEST_TIMEOUT_SECONDS = int(os.environ.get("REQUEST_TIMEOUT_SECONDS", "10"))
MAX_RETRY_COUNT = int(os.environ.get("MAX_RETRY_COUNT", "10"))
