"""
HTTP client for Pi → Backend communication.

All outgoing requests go through this module.
On failure, the caller should enqueue the request via cloud.queue.
"""

import logging
import json
from pathlib import Path

import requests

from cloud.config_loader import (
    API_BASE_URL,
    DEVICE_API_KEY,
    REQUEST_TIMEOUT_SECONDS,
)

logger = logging.getLogger(__name__)


class NonRetryableError(Exception):
    """Raised when the backend returns a 4xx error that will never succeed on retry."""
    def __init__(self, status_code: int, detail: str):
        self.status_code = status_code
        self.detail = detail
        super().__init__(f"HTTP {status_code} (non-retryable): {detail}")


_HEADERS = {
    "X-API-Key": DEVICE_API_KEY,
}


def _url(path: str) -> str:
    return f"{API_BASE_URL}{path}"


# ─── Sensor Readings ────────────────────────────────────────

def send_sensor_reading(sensor_id: str, value: float) -> dict | None:
    """
    POST /api/sensors/readings — single sensor reading.
    Returns the response JSON on success, None on failure.
    """
    if not sensor_id:
        logger.warning("send_sensor_reading called with empty sensor_id, skipping")
        return None

    payload = {"sensorId": sensor_id, "value": value}
    return _post_json("/api/sensors/readings", payload)


def send_sensor_readings_batch(readings: list[dict]) -> dict | None:
    """
    POST /api/sensors/readings — batch of readings.
    Each item: { sensorId: str, value: float }
    Returns the response JSON on success, None on failure.
    """
    skipped = [r for r in readings if not r.get("sensorId")]
    if skipped:
        logger.warning("send_sensor_readings_batch: %d reading(s) skipped — empty sensorId. "
                       "Set SENSOR_ID_* in .env after device registration.", len(skipped))
    valid = [r for r in readings if r.get("sensorId")]
    if not valid:
        logger.warning("send_sensor_readings_batch: no valid readings left, skipping request")
        return None

    payload = {"readings": valid}
    return _post_json("/api/sensors/readings", payload)


# ─── Alerts ──────────────────────────────────────────────────

def send_alert(alert_type: str, message: str, severity: str = "warning") -> dict | None:
    """
    POST /api/alerts — create an alert.
    Returns the response JSON on success, None on failure.
    """
    payload = {"type": alert_type, "message": message, "severity": severity}
    return _post_json("/api/alerts", payload)


# ─── Camera Events ───────────────────────────────────────────

def send_camera_event(
    result: str,
    match_score: float | None = None,
    person_id: str | None = None,
    face_count: int | None = None,
    faces_json: str | None = None,
    image_path: str | None = None,
) -> dict | None:
    """
    POST /api/camera/events — multipart/form-data with optional image.
    Returns the response JSON on success, None on failure.
    """
    url = _url("/api/camera/events")

    data = {"result": result}
    if match_score is not None:
        data["match_score"] = str(match_score)
    if person_id:
        data["person_id"] = person_id
    if face_count is not None:
        data["face_count"] = str(face_count)
    if faces_json:
        data["faces"] = faces_json

    files = None
    try:
        if image_path and Path(image_path).exists():
            files = {"image": ("capture.jpg", open(image_path, "rb"), "image/jpeg")}

        resp = requests.post(
            url,
            headers=_HEADERS,
            data=data,
            files=files,
            timeout=REQUEST_TIMEOUT_SECONDS,
        )

        if files:
            for f in files.values():
                f[1].close()
            files = None

        if resp.status_code == 201:
            logger.info("Camera event sent: result=%s", result)
            return resp.json()

        body = resp.text[:200]
        # Non-retryable client errors (will never succeed on retry)
        if 400 <= resp.status_code < 500 and resp.status_code != 429:
            logger.error("Camera event REJECTED (non-retryable): %d %s", resp.status_code, body)
            raise NonRetryableError(resp.status_code, body)

        # Retryable: 429 rate-limit or 5xx server error
        logger.warning("Camera event failed (retryable): %d %s", resp.status_code, body)
        return None

    except NonRetryableError:
        raise
    except requests.exceptions.ConnectionError:
        logger.warning("Backend unreachable — camera event queued for retry")
        return None
    except requests.exceptions.Timeout:
        logger.warning("Backend timeout — camera event queued for retry")
        return None
    except Exception as exc:
        logger.error("Unexpected error sending camera event: %s", exc)
        return None


# ─── Heartbeat ───────────────────────────────────────────────

def send_heartbeat() -> bool:
    """
    GET /api/health — check backend is reachable and alive.
    Returns True if backend responded OK.
    """
    try:
        resp = requests.get(
            _url("/api/health"),
            headers=_HEADERS,
            timeout=REQUEST_TIMEOUT_SECONDS,
        )
        return resp.status_code == 200
    except Exception:
        return False


# ─── Internal Helpers ────────────────────────────────────────

def _post_json(path: str, payload: dict) -> dict | None:
    """
    Generic JSON POST.
    Returns parsed response on success, None on retryable failure.
    Raises NonRetryableError on 4xx (except 429).
    """
    url = _url(path)
    try:
        resp = requests.post(
            url,
            headers={**_HEADERS, "Content-Type": "application/json"},
            json=payload,
            timeout=REQUEST_TIMEOUT_SECONDS,
        )

        if 200 <= resp.status_code < 300:
            logger.info("POST %s → %d", path, resp.status_code)
            return resp.json()

        body = resp.text[:200]
        # Non-retryable client errors (400, 401, 403, 404, 409)
        if 400 <= resp.status_code < 500 and resp.status_code != 429:
            logger.error("POST %s REJECTED (non-retryable): %d %s", path, resp.status_code, body)
            raise NonRetryableError(resp.status_code, body)

        # Retryable: 429 rate-limit or 5xx server error
        logger.warning("POST %s failed (retryable): %d %s", path, resp.status_code, body)
        return None

    except NonRetryableError:
        raise
    except requests.exceptions.ConnectionError:
        logger.warning("Backend unreachable for POST %s", path)
        return None
    except requests.exceptions.Timeout:
        logger.warning("Timeout for POST %s", path)
        return None
    except Exception as exc:
        logger.error("Unexpected error POST %s: %s", path, exc)
        return None
