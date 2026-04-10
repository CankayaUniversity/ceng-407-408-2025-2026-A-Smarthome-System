import json
from datetime import datetime
from pathlib import Path

LOG_FILE = Path("app/storage/events.jsonl")


class EventLogger:
    def __init__(self):
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)

    def log_event(
        self,
        event_type,
        image_path,
        face_detected,
        face_count,
        recognized_name=None,
        person_id=None,
        match_score=None,
        status=None,
        faces_summary=None
    ):
        event = {
            "timestamp": datetime.now().isoformat(),
            "event_type": event_type,
            "image_path": image_path,
            "face_detected": face_detected,
            "face_count": face_count,
            "recognized_name": recognized_name,
            "person_id": person_id,
            "match_score": match_score,
            "status": status,
        }

        if faces_summary is not None:
            event["faces_summary"] = faces_summary

        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(json.dumps(event, ensure_ascii=False) + "\n")