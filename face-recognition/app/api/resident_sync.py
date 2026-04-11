"""
Resident sync module — periodically pulls face profiles from the gateway
and updates the local residents.json file used by FaceMatcher.

Runs as a daemon background thread so it never blocks the main detection loop.

NOTE: Requires a /api/v1/residents endpoint on the FastAPI gateway.
Until that endpoint exists, sync will gracefully skip.
"""

import json
import logging
import threading
import time
from datetime import datetime
from typing import Optional

import requests

from app.config import RESIDENTS_FILE, API_BASE_URL, DEVICE_ID

logger = logging.getLogger(__name__)

SYNC_INTERVAL = 60
RESIDENTS_URL = f"{API_BASE_URL.rstrip('/')}/api/v1/residents"


def _fetch_residents() -> Optional[list]:
    """Returns None on transport/HTTP error; empty list means server has no embeddings."""
    try:
        response = requests.get(
            RESIDENTS_URL,
            params={"device_id": DEVICE_ID},
            timeout=10,
        )
        if response.status_code == 200:
            data = response.json()
            return data.get("residents", [])
        logger.warning("Resident fetch failed: %d", response.status_code)
        return None
    except requests.exceptions.ConnectionError:
        logger.warning("Gateway unreachable — resident sync skipped")
        return None
    except Exception as exc:
        logger.error("Resident sync fetch error: %s", exc)
        return None


def _build_local_residents(api_residents: list) -> dict:
    local = []
    for r in api_residents:
        embedding = r.get("embedding")
        if not embedding:
            continue
        local.append({
            "person_id": r.get("personId") or r.get("person_id") or r["id"],
            "name": r["name"],
            "is_active": True,
            "created_at": r.get("createdAt", datetime.now().isoformat()),
            "samples": [{
                "image_path": r.get("imagePath", ""),
                "embedding": embedding,
            }],
        })
    return {"residents": local}


def _sync_once():
    logger.info("Resident sync: fetching from gateway...")
    api_residents = _fetch_residents()
    if api_residents is None:
        return

    if not api_residents:
        local_data = {"residents": []}
        RESIDENTS_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(RESIDENTS_FILE, "w", encoding="utf-8") as f:
            json.dump(local_data, f, indent=2, ensure_ascii=False)
        logger.info("Resident sync: cleared local file (no residents with embeddings)")
        return

    local_data = _build_local_residents(api_residents)
    RESIDENTS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(RESIDENTS_FILE, "w", encoding="utf-8") as f:
        json.dump(local_data, f, indent=2, ensure_ascii=False)

    logger.info("Resident sync: updated %d resident(s)", len(local_data["residents"]))


def start_resident_sync_thread(interval: int = SYNC_INTERVAL):
    def _loop():
        while True:
            try:
                _sync_once()
            except Exception as exc:
                logger.error("Resident sync error: %s", exc)
            time.sleep(interval)

    thread = threading.Thread(target=_loop, name="ResidentSyncThread", daemon=True)
    thread.start()
    logger.info("Resident sync thread started (interval: %ds)", interval)
    return thread
