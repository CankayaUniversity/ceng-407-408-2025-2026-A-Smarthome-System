from pathlib import Path

# ─── GPIO / Hardware ──────────────────────────────────────────
PIR_GPIO_PIN = 17

# ─── Timing ───────────────────────────────────────────────────
POLL_INTERVAL_SECONDS = 0.2
MOTION_COOLDOWN_SECONDS = 5
MOTION_CONFIRMATION_CHECKS = 3
MOTION_CONFIRMATION_INTERVAL = 0.2
MOTION_CONFIRMATION_REQUIRED = 2

# ─── Camera ───────────────────────────────────────────────────
CAPTURE_DIR = Path("data/captures")
IMAGE_WIDTH = 1280
IMAGE_HEIGHT = 720
BURST_COUNT = 3
BURST_DELAY_SECONDS = 0.3

# ─── Logging ──────────────────────────────────────────────────
EVENTS_LOG_PATH = Path("app/storage/events.jsonl")

# ─── Adaptive Sample Collection ───────────────────────────────
AUTO_COLLECT_DIR = Path("data/auto_collected")
AUTO_COLLECT_ENABLED = True
AUTO_COLLECT_MAX_DISTANCE = 0.42
AUTO_COLLECT_ONLY_SINGLE_FACE = True
AUTO_COLLECT_COOLDOWN_SECONDS = 600

# ─── Website API Integration ──────────────────────────────────
API_BASE_URL = "http://172.20.10.2:3001"
API_KEY = "299a842f-0dc9-467d-b5c6-8f30cc9e2410"
SYNC_RESIDENTS_INTERVAL = 60
RESIDENTS_FILE = Path("app/storage/residents.json")