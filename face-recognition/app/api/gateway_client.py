"""
HTTP client for communicating with the FastAPI gateway (main.py).

The gateway forwards data to Supabase. All Pi → Cloud communication
goes through this single module.
"""

import json
import logging
import time

import requests

from app.config import API_BASE_URL, DEVICE_ID

logger = logging.getLogger(__name__)

API_URL = f"{API_BASE_URL.rstrip('/')}/api/v1"
REQUEST_TIMEOUT = 10


def _post_json(endpoint: str, payload: dict):
    url = f"{API_URL}{endpoint}"
    try:
        response = requests.post(url, json=payload, timeout=REQUEST_TIMEOUT)
        response.raise_for_status()
        logger.info("POST %s -> %s", endpoint, response.status_code)
        return response.json() if response.content else {}
    except requests.HTTPError as exc:
        body = ""
        try:
            body = exc.response.text[:500] if exc.response is not None else ""
        except Exception:
            pass
        logger.warning("POST %s failed: %s | body=%s", endpoint, exc, body)
        return None
    except Exception as exc:
        logger.warning("POST %s error: %s", endpoint, exc)
        return None


def _post_file(endpoint: str, params: dict, file_path: str):
    url = f"{API_URL}{endpoint}"
    try:
        with open(file_path, "rb") as f:
            response = requests.post(
                url, params=params, files={"file": f}, timeout=REQUEST_TIMEOUT,
            )
        response.raise_for_status()
        logger.info("UPLOAD %s -> %s", endpoint, response.status_code)
        return response.json() if response.content else {}
    except requests.HTTPError as exc:
        body = ""
        try:
            body = exc.response.text[:500] if exc.response is not None else ""
        except Exception:
            pass
        logger.warning("UPLOAD %s failed: %s | body=%s", endpoint, exc, body)
        return None
    except Exception as exc:
        logger.warning("UPLOAD %s error: %s", endpoint, exc)
        return None


def send_sensor_telemetry(temperature: float, humidity: float,
                          gas_detected: bool, soil_dry: bool):
    return _post_json("/telemetry/sensors", {
        "device_id": DEVICE_ID,
        "temperature": temperature,
        "humidity": humidity,
        "gas_detected": gas_detected,
        "soil_dry": soil_dry,
    })


def create_security_event(event_type: str, message: str):
    return _post_json("/events/security", {
        "device_id": DEVICE_ID,
        "event_type": event_type,
        "message": message,
    })


def create_alert_event(event_type: str, message: str,
                       priority: str = "warning"):
    return _post_json("/events/alert", {
        "device_id": DEVICE_ID,
        "event_type": event_type,
        "message": message,
        "priority": priority,
    })


def upload_intelligent_snapshot(event_id: str, is_resident: bool,
                                image_path: str, resident_id=None,
                                face_count: int = 1,
                                match_score: float | None = None,
                                bbox=None):
    params = {
        "event_id": event_id,
        "is_resident": str(is_resident).lower(),
        "face_count": face_count,
    }
    if resident_id:
        params["resident_id"] = resident_id
    if match_score is not None:
        params["match_score"] = match_score
    if bbox is not None:
        params["bbox"] = json.dumps(bbox)
    return _post_file("/events/upload-intelligent", params, image_path)


def send_heartbeat():
    return _post_json("/heartbeat", {
        "device_id": DEVICE_ID,
        "status": "online",
        "timestamp": time.time(),
    })
