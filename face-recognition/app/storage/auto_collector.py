import shutil
import time
from datetime import datetime
from pathlib import Path

from app.config import (
    AUTO_COLLECT_DIR,
    AUTO_COLLECT_ENABLED,
    AUTO_COLLECT_MAX_DISTANCE,
    AUTO_COLLECT_ONLY_SINGLE_FACE,
    AUTO_COLLECT_COOLDOWN_SECONDS,
)


class AutoCollector:
    def __init__(self):
        self.last_saved_times = {}
        AUTO_COLLECT_DIR.mkdir(parents=True, exist_ok=True)

    def should_collect(self, result: dict, face_count: int) -> bool:
        if not AUTO_COLLECT_ENABLED:
            return False

        if result.get("status") != "authorized":
            return False

        if result.get("name") is None:
            return False

        score = result.get("score")
        if score is None:
            return False

        if score > AUTO_COLLECT_MAX_DISTANCE:
            return False

        if AUTO_COLLECT_ONLY_SINGLE_FACE and face_count != 1:
            return False

        person_name = result["name"]
        now = time.time()
        last_time = self.last_saved_times.get(person_name, 0)

        if now - last_time < AUTO_COLLECT_COOLDOWN_SECONDS:
            return False

        return True

    def save_sample(self, image_path: str, person_name: str) -> str:
        person_dir = AUTO_COLLECT_DIR / person_name
        person_dir.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        target_path = person_dir / f"auto_{timestamp}.jpg"

        shutil.copy(image_path, target_path)
        self.last_saved_times[person_name] = time.time()

        return str(target_path)