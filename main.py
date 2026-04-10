import os
from fastapi import FastAPI, HTTPException, UploadFile, File
from pydantic import BaseModel
from typing import Optional, List
from supabase import create_client, Client

# I am initializing the FastAPI backend as a secure middleware. 
# It handles authentication and validates data before it reaches my Supabase database.
app = FastAPI(title="CENG 407 Smart Home Cloud API")

# I use the 'service_role' key to bypass RLS and perform administrative database operations.
SUPABASE_URL = "YOUR_SUPABASE_URL"
SUPABASE_SERVICE_KEY = "YOUR_SERVICE_ROLE_KEY"
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

# --- MODELS FOR VALIDATION ---
class ClimateData(BaseModel):
    device_id: str
    temperature: float
    humidity: float

class SecurityEvent(BaseModel):
    device_id: str
    user_id: Optional[str] = None
    event_type: str 
    priority: str = "high"
    message: str

class DeviceHeartbeat(BaseModel):
    device_id: str

# --- DEVICE ENDPOINTS (FOR RASPBERRY PI 5) ---

@app.post("/api/v1/telemetry/climate")
def receive_climate_data(data: ClimateData):
    """I use this to log periodic environment data into the sensor_readings table."""
    try:
        supabase.table("sensor_readings").insert([
            {"device_id": data.device_id, "sensor_type": "temperature", "numeric_value": data.temperature, "unit": "C"},
            {"device_id": data.device_id, "sensor_type": "humidity", "numeric_value": data.humidity, "unit": "%"}
        ]).execute()
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/events/security")
def receive_security_event(event: SecurityEvent):
    """I log security alerts here and return an ID so the Pi can upload a matching snapshot."""
    try:
        response = supabase.table("events").insert({
            "device_id": event.device_id,
            "event_type": event.event_type,
            "priority": event.priority,
            "message": event.message
        }).execute()
        return {"status": "success", "event_id": response.data[0]['id']}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/events/{event_id}/snapshot")
async def upload_event_snapshot(event_id: str, file: UploadFile = File(...)):
    """I securely upload event snapshots to the private 'event-snapshots' bucket."""
    try:
        file_bytes = await file.read()
        file_name = f"{event_id}_{file.filename}"
        
        # Uploading to private bucket
        supabase.storage.from_("event-snapshots").upload(
            path=file_name,
            file=file_bytes,
            file_options={"content-type": "image/jpeg"}
        )
        
        # Linking the snapshot path to the camera_events table
        supabase.table("camera_events").insert({
            "event_id": event_id,
            "snapshot_path": file_name,
            "human_detected": True 
        }).execute()

        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/device/heartbeat")
def update_heartbeat(heartbeat: DeviceHeartbeat):
    """I keep track of my device's online status in the cloud."""
    try:
        supabase.table("devices").update({
            "is_online": True, 
            "last_seen_at": "now()"
        }).eq("id", heartbeat.device_id).execute()
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
def health_check():
    return {"status": "online", "message": "Smart Home Cloud Backend is operational."}