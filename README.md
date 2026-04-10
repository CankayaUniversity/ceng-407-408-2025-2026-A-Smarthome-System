# ceng-407-408-2025-2026-A-Smarthome-System
A Smarthome System

## Quick Start (Raspberry Pi)

1. Copy `.env.example` to `.env` and fill in the values:
   ```bash
   cp .env.example .env
   nano .env
   ```
2. Run the main system:
   ```bash
   python sh.py
   ```

## Configuration

All shared settings live in **one** `.env` file at the project root.
Both `sh.py` (via `cloud/config_loader.py`) and `face-recognition/app/`
(via `face-recognition/app/config.py`) read from the same `.env`.

| Key | Used by | Description |
|-----|---------|-------------|
| `API_BASE_URL` | sh.py, face-recognition | Backend server address |
| `DEVICE_API_KEY` | sh.py, face-recognition | Device authentication key |
| `SYNC_RESIDENTS_INTERVAL` | face-recognition | Resident sync period (sec) |
| `SENSOR_ID_*` | sh.py (cloud) | Sensor UUIDs from backend |
| `CLIMATE_INTERVAL_SECONDS` | sh.py (cloud) | Telemetry send interval |

See `.env.example` for the full list.

## Runtime Warning

> **IMPORTANT:** `sh.py` and `face-recognition/app/main.py` must **never** run
> at the same time on the same Pi. They both use the same camera, PIR sensor,
> and device API key. Running both simultaneously will cause hardware conflicts
> and duplicate events on the backend.

- **Production / Demo:** Run only `sh.py`.
- **Face-recognition testing:** Stop `sh.py` first, then run `face-recognition/app/main.py`.
