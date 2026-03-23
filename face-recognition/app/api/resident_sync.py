"""
Resident sync module — periodically pulls face profiles from the website backend
and updates the local residents.json file used by FaceMatcher.

Runs as a daemon background thread so it never blocks the main detection loop.
"""

import json
import logging
import threading
import time
from datetime import datetime
from pathlib import Path

from app.config import RESIDENTS_FILE, SYNC_RESIDENTS_INTERVAL
from app.api.client import fetch_residents

logger = logging.getLogger(__name__)


def _build_local_residents(api_residents: list) -> dict:
    """
    Convert website API resident format to local residents.json format.

    Website format (from /api/residents/sync):
        { id, personId, name, imagePath, embedding, createdAt }

    Local format (used by FaceMatcher):
        {
          person_id, name, is_active, created_at,
          samples: [{ image_path, embedding }]
        }
    """
    local = []
    for r in api_residents:
        embedding = r.get("embedding")
        if not embedding:
            continue  # Skip profiles without embeddings — Pi can't use them

        local.append({
            "person_id": r.get("personId") or r["id"],  # Prefer Pi's original person_id
            "name": r["name"],
            "is_active": True,
            "created_at": r.get("createdAt", datetime.now().isoformat()),
            "samples": [
                {
                    "image_path": r.get("imagePath") or "",
                    "embedding": embedding,
                }
            ],
        })

    return {"residents": local}


def _sync_once():
    """Run a single sync cycle: fetch from API → update local file."""
    logger.info("Resident sync: fetching from backend…")
    api_residents = fetch_residents()

    if not api_residents:
        logger.info("Resident sync: no residents returned (backend may be offline)")
        return

    local_data = _build_local_residents(api_residents)

    RESIDENTS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(RESIDENTS_FILE, "w", encoding="utf-8") as f:
        json.dump(local_data, f, indent=2, ensure_ascii=False)

    logger.info(
        "Resident sync: updated %d resident(s) in %s",
        len(local_data["residents"]),
        RESIDENTS_FILE,
    )


def start_resident_sync_thread():
    """
    Start a daemon thread that syncs residents every SYNC_RESIDENTS_INTERVAL seconds.
    Call this once at startup from main.py.
    """

    def _loop():
        while True:
            try:
                _sync_once()
            except Exception as exc:
                logger.error("Resident sync error: %s", exc)
            time.sleep(SYNC_RESIDENTS_INTERVAL)

    thread = threading.Thread(target=_loop, name="ResidentSyncThread", daemon=True)
    thread.start()
    logger.info(
        "Resident sync thread started (interval: %ds)", SYNC_RESIDENTS_INTERVAL
    )
    return thread
