import os
from typing import Optional

from fastapi import FastAPI, HTTPException, UploadFile, File
from pydantic import BaseModel
from supabase import create_client, Client

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

app = FastAPI(title="Smart Home Cloud API")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in environment.")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)


# ----------------------------
# Data models
# ----------------------------
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


# ----------------------------
# Endpoints
# ----------------------------
@app.get("/")
def root():
    return {"status": "operational", "service": "smart-home-cloud-api"}


@app.get("/api/v1/health")
def health_check():
    return {"status": "ok"}


@app.post("/api/v1/heartbeat")
def receive_heartbeat(data: Heartbeat):
    """
    Lightweight heartbeat endpoint.
    If you have a devices table with status fields, you can update it here.
    """
    try:
        # Optional status update if devices table exists and supports it
        try:
            supabase.table("devices").update({
                "is_online": True,
            }).eq("id", data.device_id).execute()
        except Exception:
            # Keep heartbeat non-blocking if schema differs
            pass

        return {"status": "received"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/telemetry/sensors")
def receive_sensor_telemetry(data: FullSensorData):
    """
    Logs environmental sensor data into the cloud database.
    """
    try:
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
                "numeric_value": 0.0 if data.soil_dry else 1.0,
                "unit": "status",
            },
        ]

        supabase.table("sensor_readings").insert(readings).execute()
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/events/security")
def create_security_event(event: SecurityEvent):
    """
    Creates a security event record and returns a unique event_id.
    """
    try:
        response = supabase.table("events").insert({
            "device_id": event.device_id,
            "event_type": event.event_type,
            "priority": "high",
            "message": event.message,
        }).execute()

        return {"event_id": response.data[0]["id"]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/events/alert")
def create_alert_event(event: AlertEvent):
    """
    Creates alert-like events (fire, moisture, etc.) in the same events table.
    """
    try:
        response = supabase.table("events").insert({
            "device_id": event.device_id,
            "event_type": event.event_type,
            "priority": event.priority,
            "message": event.message,
        }).execute()

        return {"event_id": response.data[0]["id"]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/events/upload-intelligent")
async def upload_intelligent_snapshot(
    event_id: str,
    is_resident: bool,
    resident_id: Optional[str] = None,
    file: UploadFile = File(...),
):
    """
    Uploads snapshots to Supabase Storage and links them to database tables.
    """
    try:
        file_bytes = await file.read()

        folder = "residents" if is_resident else "strangers"
        file_name = f"{folder}/{event_id}.jpg"

        supabase.storage.from_("event-snapshots").upload(
            path=file_name,
            file=file_bytes,
            file_options={"content-type": "image/jpeg"},
        )

        if is_resident and resident_id:
            # If your schema supports this
            supabase.table("resident_faces").insert({
                "resident_id": resident_id,
                "snapshot_path": file_name,
            }).execute()
        else:
            supabase.table("camera_events").insert({
                "event_id": event_id,
                "snapshot_path": file_name,
                "human_detected": True,
            }).execute()

        return {"status": "success", "storage_path": file_name}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))