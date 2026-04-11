import os
import json
import logging
import threading
import tempfile
import time
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

RESIDENT_EMBEDDING_REFRESH_SEC = int(os.getenv("RESIDENT_EMBEDDING_REFRESH_SEC", "45"))


def _run_resident_embedding_backfill_pass() -> dict:
    """
    For each resident with a storage photo_path but missing embedding, download the
    file, compute a face_recognition vector on the gateway (Pi), and write JSONB
    on `residents.embedding`. Returns a small summary for logs and the HTTP trigger.
    """
    from app.vision.embedder import FaceEmbedder

    summary = {
        "rows_total": 0,
        "skipped_no_photo": 0,
        "skipped_already_embedded": 0,
        "attempted": 0,
        "embedded_ok": 0,
        "failed_download": 0,
        "failed_no_face": 0,
        "failed_update": 0,
        "failed_other": 0,
        "updated_resident_ids": [],
    }

    embedder = FaceEmbedder()
    rows = (
        supabase.table("residents")
        .select("id, name, person_id, photo_path, embedding")
        .execute()
        .data
        or []
    )
    summary["rows_total"] = len(rows)

    for row in rows:
        path = row.get("photo_path")
        if not path:
            summary["skipped_no_photo"] += 1
            continue
        emb = row.get("embedding")
        if isinstance(emb, list) and len(emb) > 0:
            summary["skipped_already_embedded"] += 1
            continue
        summary["attempted"] += 1
        try:
            file_bytes = supabase.storage.from_(SNAPSHOT_BUCKET).download(path)
        except Exception as exc:
            summary["failed_download"] += 1
            logger.warning("Resident photo download failed (%s): %s", path, exc)
            continue
        suffix = Path(path).suffix.lower() or ".jpg"
        if suffix not in (".jpg", ".jpeg", ".png", ".webp"):
            suffix = ".jpg"
        tmp_path = None
        try:
            fd, tmp_path = tempfile.mkstemp(suffix=suffix)
            with os.fdopen(fd, "wb") as tmp_file:
                tmp_file.write(file_bytes)
            vec = embedder.get_embedding(tmp_path)
        except ValueError as exc:
            summary["failed_no_face"] += 1
            logger.warning("No usable face in resident photo %s: %s", path, exc)
            continue
        except Exception:
            summary["failed_other"] += 1
            logger.exception("Embedding failed for resident photo %s", path)
            continue
        finally:
            if tmp_path:
                try:
                    Path(tmp_path).unlink(missing_ok=True)
                except OSError:
                    pass
        try:
            supabase.table("residents").update({"embedding": vec}).eq("id", row["id"]).execute()
            summary["embedded_ok"] += 1
            summary["updated_resident_ids"].append(str(row["id"]))
            logger.info("Resident embedding stored: %s (%s)", row.get("name"), row["id"])
        except Exception:
            summary["failed_update"] += 1
            logger.exception("Failed to update embedding for resident %s", row["id"])

    logger.info(
        "Resident embedding pass: total=%s attempted=%s ok=%s "
        "(skip_photo=%s skip_done=%s fail_dl=%s fail_face=%s fail_up=%s fail_other=%s)",
        summary["rows_total"],
        summary["attempted"],
        summary["embedded_ok"],
        summary["skipped_no_photo"],
        summary["skipped_already_embedded"],
        summary["failed_download"],
        summary["failed_no_face"],
        summary["failed_update"],
        summary["failed_other"],
    )
    return summary


def _resident_embedding_daemon() -> None:
    time.sleep(3)
    while True:
        try:
            _run_resident_embedding_backfill_pass()
        except Exception:
            logger.exception("Resident embedding backfill pass failed")
        time.sleep(max(15, RESIDENT_EMBEDDING_REFRESH_SEC))


@app.on_event("startup")
def _start_resident_embedding_thread() -> None:
    threading.Thread(
        target=_resident_embedding_daemon,
        name="ResidentEmbeddingBackfill",
        daemon=True,
    ).start()
    logger.info(
        "Resident embedding backfill thread started (interval ~%ss)",
        RESIDENT_EMBEDDING_REFRESH_SEC,
    )


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


@app.get("/api/v1/residents")
def list_residents_for_edge(device_id: str = Query(...)):
    """
    Returns residents with non-empty embeddings for the edge FaceMatcher sync
    (see app.api.resident_sync).
    """
    try:
        ensure_device_exists(device_id)
        response = (
            supabase.table("residents")
            .select("id, name, person_id, embedding")
            .execute()
        )
        out = []
        for r in response.data or []:
            emb = r.get("embedding")
            if not emb or not isinstance(emb, list) or len(emb) == 0:
                continue
            rid = r["id"]
            out.append({
                "id": rid,
                "name": r.get("name") or "Resident",
                "person_id": r.get("person_id") or str(rid),
                "embedding": emb,
            })
        return {"residents": out}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("List residents failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/residents/backfill-embeddings")
def trigger_resident_embedding_backfill(device_id: str = Query(...)):
    """
    Run one embedding pass immediately (same logic as the background thread).
    Use from the Pi: curl -X POST "http://127.0.0.1:8000/api/v1/residents/backfill-embeddings?device_id=YOUR_DEVICE_UUID"
    """
    try:
        ensure_device_exists(device_id)
        summary = _run_resident_embedding_backfill_pass()
        return {"status": "ok", **summary}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Manual embedding backfill failed")
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
