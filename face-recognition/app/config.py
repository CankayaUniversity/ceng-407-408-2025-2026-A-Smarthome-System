from pathlib import Path

# ─── GPIO / Hardware ──────────────────────────────────────────
PIR_GPIO_PIN = 17

# ─── Timing ───────────────────────────────────────────────────
POLL_INTERVAL_SECONDS = 0.2
MOTION_COOLDOWN_SECONDS = 5

# ─── Camera ───────────────────────────────────────────────────
CAPTURE_DIR = Path("data/captures")
IMAGE_WIDTH = 1280
IMAGE_HEIGHT = 720

# ─── Logging ──────────────────────────────────────────────────
EVENTS_LOG_PATH = Path("app/storage/events.jsonl")

# ─── Face Detection ───────────────────────────────────────────
# OpenCV haarcascade path resolved automatically
MIN_FACE_SIZE = (60, 60)
SCALE_FACTOR = 1.1
MIN_NEIGHBORS = 5

# ─── Website API Integration ──────────────────────────────────
# The URL of the running website backend (e.g. http://192.168.1.100:3001)
API_BASE_URL = "http://localhost:3001"

# The device API key from the website DB (Device.apiKey field)
# Run `docker exec smarthome_backend node -e "const{PrismaClient}=require('@prisma/client');const p=new PrismaClient();p.device.findFirst().then(d=>console.log(d.apiKey))"` to get it
API_KEY = "REPLACE_WITH_YOUR_DEVICE_API_KEY"

# How often (in seconds) the Pi syncs resident embeddings from the website
SYNC_RESIDENTS_INTERVAL = 60

# Local file where resident embeddings are cached (managed by resident_sync.py)
RESIDENTS_FILE = Path("app/storage/residents.json")