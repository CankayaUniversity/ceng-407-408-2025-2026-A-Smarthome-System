import os
import json
import logging
from uuid import uuid4
from pathlib import Path
from typing import Optional
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException, UploadFile, File, Query
from pydantic import BaseModel
from supabase import create_client, Client

try:
    from dotenv import load_dotenv
except Exception:
    load_dotenv = None

# -------------------------------------------------
# Env loading: first local face-recognition/.env, then parent .env
# -------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
ENV_CANDIDATES = [
    BASE_DIR / ".env",
    BASE_DIR.parent / ".env",
]

if load_dotenv:
    for env_path in ENV_CANDIDATES:
        if env_path.exists():
            load_dotenv(env_path)
            break

# -------------------------------------------------
# Logging
# -------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("smart_home_cloud")

app = FastAPI(title="Smart Home Cloud API")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

SNAPSHOT_BUCKET = os.getenv("SUPABASE_SNAPSHOT_BUCKET", "event-snapshots")
RESIDENT_PREFIX = os.getenv("RESIDENT_SNAPSHOT_PREFIX", "resident_snapshots")
UNKNOWN_PREFIX = os.getenv("UNKNOWN_SNAPSHOT_PREFIX", "unknown_snapshots")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in environment.")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)


# -------------------------------------------------
# Models
# -------------------------------------------------
class FullSensorData(BaseModel):
    device_id: str
    temperature: float
    humidity: float
    gas_detected: bool
    soil_dry: bool


class SecurityEvent(BaseModel):
    device_id: str
    event_type: str
    message: str


class AlertEvent(BaseModel):
    device_id: str
    event_type: str
    message: str
    priority: str = "warning"


class Heartbeat(BaseModel):
    device_id: str
    status: str = "online"
    timestamp: Optional[float] = None


# -------------------------------------------------
# Helpers
# -------------------------------------------------
def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def ensure_device_exists(device_id: str) -> None:
    try:
        response = (
            supabase.table("devices")
            .select("id")
            .eq("id", device_id)
            .limit(1)
            .execute()
        )
        if not response.data:
            raise HTTPException(status_code=404, detail=f"Device not found: {device_id}")
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Device lookup failed")
        raise HTTPException(status_code=500, detail=str(e))
        
def ensure_event_exists(event_id: str) -> None:
    try:
        response = (
            supabase.table("events")
            .select("id")
            .eq("id", event_id)
            .limit(1)
            .execute()
        )
        if not response.data:
            raise HTTPException(status_code=404, detail=f"Event not found: {event_id}")
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Event lookup failed")
        raise HTTPException(status_code=500, detail=str(e))


# -------------------------------------------------
# Endpoints
# -------------------------------------------------
@app.get("/")
def root():
    return {"status": "operational", "service": "smart-home-cloud-api"}


@app.get("/api/v1/health")
def health_check():
    return {"status": "ok"}


@app.post("/api/v1/heartbeat")
def receive_heartbeat(data: Heartbeat):
    try:
        ensure_device_exists(data.device_id)
        try:
            (
                supabase.table("devices")
                .update({
                    "is_online": True,
                    "last_seen_at": _utc_now_iso(),
                })
                .eq("id", data.device_id)
                .execute()
            )
        except Exception:
            (
                supabase.table("devices")
                .update({
                    "is_online": True,
                })
                .eq("id", data.device_id)
                .execute()
            )

        return {"status": "received"}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Heartbeat failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/telemetry/sensors")
def receive_sensor_telemetry(data: FullSensorData):
    """
    Working/stable mapping kept intentionally:
    - temperature
    - humidity
    - smoke
    - water
    """
    try:
        ensure_device_exists(data.device_id)

        readings = [
            {
                "device_id": data.device_id,
                "sensor_type": "temperature",
                "numeric_value": data.temperature,
                "unit": "C",
            },
            {
                "device_id": data.device_id,
                "sensor_type": "humidity",
                "numeric_value": data.humidity,
                "unit": "%",
            },
            {
                "device_id": data.device_id,
                "sensor_type": "smoke",
                "numeric_value": 1.0 if data.gas_detected else 0.0,
                "unit": "status",
            },
            {
                "device_id": data.device_id,
                "sensor_type": "water",
                "numeric_value": 1.0 if data.soil_dry else 0.0,
                "unit": "status",
            },
        ]

        supabase.table("sensor_readings").insert(readings).execute()
        return {"status": "success"}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Telemetry insert failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/events/security")
def create_security_event(event: SecurityEvent):
    try:
        ensure_device_exists(event.device_id)

        response = (
            supabase.table("events")
            .insert({
                "device_id": event.device_id,
                "event_type": event.event_type,
                "priority": "high",
                "message": event.message,
            })
            .execute()
        )

        return {"event_id": response.data[0]["id"]}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Security event insert failed")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/events/alert")
def create_alert_event(event: AlertEvent):
    try:
        ensure_device_exists(event.device_id)

        response = (
            supabase.table("events")
            .insert({
                "device_id": event.device_id,
                "event_type": event.event_type,
                "priority": event.priority,
                "message": event.message,
            })
            .execute()
        )

        return {"event_id": response.data[0]["id"]}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Alert event insert failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/events/upload-intelligent")
async def upload_intelligent_snapshot(
    event_id: str = Query(...),
    is_resident: bool = Query(...),
    resident_id: Optional[str] = Query(None),
    face_count: int = Query(1),
    match_score: Optional[float] = Query(None),
    bbox: Optional[str] = Query(None),
    file: UploadFile = File(...),
):
    """
    IMPORTANT:
    This endpoint should only be called when a face is actually detected.
    No-face cases must be skipped by sh.py.
    """
    try:
        ensure_event_exists(event_id)

        file_bytes = await file.read()

        folder = RESIDENT_PREFIX if is_resident else UNKNOWN_PREFIX
        file_name = f"{folder}/{event_id}_{uuid4().hex}.jpg"

        supabase.storage.from_(SNAPSHOT_BUCKET).upload(
            path=file_name,
            file=file_bytes,
            file_options={"content-type": "image/jpeg"},
        )

        camera_response = (
            supabase.table("camera_events")
            .insert({
                "event_id": event_id,
                "snapshot_path": file_name,
                "human_detected": True,
                "face_count": face_count,
            })
            .execute()
        )

        camera_event_id = camera_response.data[0]["id"]

        bbox_json = None
        if bbox:
            try:
                bbox_json = json.loads(bbox)
            except Exception:
                bbox_json = None

        classification = "resident" if is_resident else "unknown"

        supabase.table("event_faces").insert({
            "camera_event_id": camera_event_id,
            "resident_id": resident_id if is_resident else None,
            "match_score": match_score,
            "classification": classification,
            "bbox": bbox_json,
        }).execute()

        return {
            "status": "success",
            "camera_event_id": camera_event_id,
            "storage_path": file_name,
            "classification": classification,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Snapshot upload failed")
        raise HTTPException(status_code=500, detail=str(e))
