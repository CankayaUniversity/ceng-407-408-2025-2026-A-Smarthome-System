import json
from datetime import datetime
from pathlib import Path
from app.config import EVENTS_LOG_PATH


class EventLogger:
    def __init__(self, log_path: Path = EVENTS_LOG_PATH):
        self.log_path = log_path
        self.log_path.parent.mkdir(parents=True, exist_ok=True)

    def log_event(
        self,
        event_type: str,
        image_path: str,
        face_detected: bool,
        face_count: int,
        notes: str = ""
    ) -> None:
        event = {
            "timestamp": datetime.now().isoformat(),
            "event_type": event_type,
            "image_path": image_path,
            "face_detected": face_detected,
            "face_count": face_count,
            "notes": notes
        }

        with open(self.log_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(event, ensure_ascii=False) + "\n")