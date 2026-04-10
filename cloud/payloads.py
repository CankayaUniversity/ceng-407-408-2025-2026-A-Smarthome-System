"""
Payload builders for all cloud request types.

Each builder returns a dict that can be:
  - Sent directly via api_client
  - Serialized to JSON and stored in the offline queue
"""

import json
from datetime import datetime, timezone

from cloud.config_loader import (
    SENSOR_ID_TEMPERATURE,
    SENSOR_ID_HUMIDITY,
    SENSOR_ID_GAS,
    SENSOR_ID_SOIL,
)


def climate_telemetry(temperature: float, humidity: float) -> dict:
    """
    Payload for POST /api/sensors/readings (batch).
    Sends temperature + humidity in a single request.
    """
    readings = []

    if SENSOR_ID_TEMPERATURE:
        readings.append({"sensorId": SENSOR_ID_TEMPERATURE, "value": temperature})
    if SENSOR_ID_HUMIDITY:
        readings.append({"sensorId": SENSOR_ID_HUMIDITY, "value": humidity})

    return {
        "request_type": "climate_telemetry",
        "endpoint": "/api/sensors/readings",
        "payload": {"readings": readings},
        "timestamp": _now(),
    }


def gas_emergency(gas_state: str) -> dict:
    """
    Payload for POST /api/alerts — gas detection state change.
    gas_state: "ALERT" or "NO GAS"
    """
    if gas_state == "ALERT":
        return {
            "request_type": "gas_emergency",
            "endpoint": "/api/alerts",
            "payload": {
                "type": "FIRE",
                "message": "Gas/smoke detected by MQ2 sensor!",
                "severity": "critical",
            },
            "timestamp": _now(),
        }
    else:
        return {
            "request_type": "gas_clear",
            "endpoint": "/api/alerts",
            "payload": {
                "type": "FIRE",
                "message": "Gas/smoke alert cleared — MQ2 sensor back to normal.",
                "severity": "info",
            },
            "timestamp": _now(),
        }


def soil_alert(soil_state: str) -> dict:
    """
    Payload for POST /api/alerts — soil moisture change.
    soil_state: "DRY" or "WET"
    """
    if soil_state == "DRY":
        return {
            "request_type": "soil_alert",
            "endpoint": "/api/alerts",
            "payload": {
                "type": "LOW_MOISTURE",
                "message": "Soil moisture is critically low — watering needed.",
                "severity": "warning",
            },
            "timestamp": _now(),
        }
    else:
        return {
            "request_type": "soil_clear",
            "endpoint": "/api/alerts",
            "payload": {
                "type": "LOW_MOISTURE",
                "message": "Soil moisture restored to normal level.",
                "severity": "info",
            },
            "timestamp": _now(),
        }


def security_event(
    result: str,
    image_path: str | None = None,
    match_score: float | None = None,
    person_id: str | None = None,
    face_count: int = 0,
    faces: list[dict] | None = None,
) -> dict:
    """
    Payload for POST /api/camera/events — security / face recognition event.

    result: "authorized" | "unauthorized" | "unknown"
    """
    data = {
        "result": result,
    }
    if match_score is not None:
        data["match_score"] = str(match_score)
    if person_id:
        data["person_id"] = person_id
    if face_count:
        data["face_count"] = str(face_count)
    if faces:
        data["faces"] = json.dumps(faces, ensure_ascii=False)

    return {
        "request_type": "security_event",
        "endpoint": "/api/camera/events",
        "payload": data,
        "file_path": image_path,
        "timestamp": _now(),
    }


def face_result(
    status: str,
    recognized_name: str | None,
    person_id: str | None,
    match_score: float | None,
    face_count: int,
    image_path: str | None = None,
) -> dict:
    """
    Convenience wrapper around security_event for face pipeline results.
    Maps face pipeline output to the camera event payload.
    """
    return security_event(
        result=status,
        image_path=image_path,
        match_score=match_score,
        person_id=person_id,
        face_count=face_count,
    )


def heartbeat_payload() -> dict:
    """
    Simple heartbeat — not queued, fire-and-forget.
    """
    return {
        "request_type": "heartbeat",
        "endpoint": "/api/health",
        "payload": {},
        "timestamp": _now(),
    }


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
