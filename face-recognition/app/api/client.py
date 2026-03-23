"""
HTTP client for communicating with the Smart Home website backend.

This module handles:
- Sending camera face recognition events (POST /api/camera/events)
- Fetching resident profiles with embeddings for local sync (GET /api/residents/sync)
"""

import logging
import json
from pathlib import Path

import requests

from app.config import API_BASE_URL, API_KEY

logger = logging.getLogger(__name__)

HEADERS = {
    "X-API-Key": API_KEY,
}


def send_camera_event(image_path: str | None, result: dict) -> bool:
    """
    Send a face recognition event to the website backend.

    Args:
        image_path: Local path to captured image (or None if no image).
        result: Dict from FaceMatcher.find_best_match(), e.g.:
                {matched, person_id, name, score, status}

    Returns:
        True on success, False on failure.
    """
    url = f"{API_BASE_URL}/api/camera/events"

    data = {
        "result": result.get("status", "unknown"),   # "authorized" | "unauthorized"
        "match_score": str(result["score"]) if result.get("score") is not None else "",
    }

    # Include person_id only for authorized matches so backend can link to FaceProfile
    if result.get("matched") and result.get("person_id"):
        data["person_id"] = result["person_id"]

    files = None
    try:
        if image_path and Path(image_path).exists():
            files = {"image": ("capture.jpg", open(image_path, "rb"), "image/jpeg")}

        response = requests.post(
            url,
            headers=HEADERS,
            data=data,
            files=files,
            timeout=10,
        )

        if files:
            for f in files.values():
                f[1].close()

        if response.status_code == 201:
            logger.info("Camera event sent successfully: %s", result.get("status"))
            return True
        else:
            logger.warning("Camera event POST failed: %d %s", response.status_code, response.text)
            return False

    except requests.exceptions.ConnectionError:
        logger.warning("Backend unreachable — camera event not sent (offline mode)")
        return False
    except Exception as exc:
        logger.error("Unexpected error sending camera event: %s", exc)
        return False


def fetch_residents() -> list:
    """
    Fetch all face profiles with embeddings from the website backend.
    Used by resident_sync to keep local residents.json up to date.

    Returns:
        List of resident dicts (may be empty if fetch fails).
    """
    url = f"{API_BASE_URL}/api/residents/sync"

    try:
        response = requests.get(url, headers=HEADERS, timeout=10)

        if response.status_code == 200:
            data = response.json()
            return data.get("residents", [])
        else:
            logger.warning("Resident sync fetch failed: %d", response.status_code)
            return []

    except requests.exceptions.ConnectionError:
        logger.warning("Backend unreachable — resident sync skipped (offline mode)")
        return []
    except Exception as exc:
        logger.error("Unexpected error fetching residents: %s", exc)
        return []
