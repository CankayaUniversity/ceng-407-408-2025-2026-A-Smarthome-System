# IoT Smart Home System

A full-stack smart home system with Raspberry Pi edge processing, AI face recognition, and a real-time web dashboard.

## Architecture

```
Pi Edge (run_edge.py)  ──HTTP──>  FastAPI Gateway (main.py)  ──SDK──>  Supabase
                                                                          ↑
React Website  ──supabase-js────────────────────────────────────────────┘
```

- **Raspberry Pi**: Reads sensors (DHT11, MQ2, PIR, soil), captures camera frames, runs face recognition, sends data to the FastAPI gateway.
- **FastAPI Gateway** (`face-recognition/main.py`): Receives telemetry + events from the Pi and writes to Supabase (DB + Storage).
- **Supabase**: PostgreSQL database, Auth, Realtime subscriptions, and file Storage.
- **React Website** (`website/client/`): Connects directly to Supabase via `@supabase/supabase-js`. Receives real-time sensor updates, displays alerts, camera events, and manages residents.

## Project Structure

```
bitirmeProject/
├── face-recognition/
│   ├── main.py              # FastAPI gateway (Pi → Supabase)
│   ├── run_edge.py           # Pi entry point (sensors, camera, face recognition)
│   ├── app/
│   │   ├── config.py         # Central configuration
│   │   ├── api/
│   │   │   ├── gateway_client.py  # HTTP client for main.py
│   │   │   └── resident_sync.py   # Periodic resident sync
│   │   ├── camera/
│   │   │   └── capture.py    # Picamera2 wrapper
│   │   ├── vision/
│   │   │   ├── face_detector.py
│   │   │   ├── embedder.py
│   │   │   └── matcher.py
│   │   └── logging_system/
│   │       └── event_logger.py
│   └── requirements.txt
├── website/
│   ├── client/               # React + Vite frontend
│   │   ├── src/
│   │   ├── Dockerfile
│   │   └── nginx.conf
│   └── docker-compose.yml    # Frontend-only compose
├── cloud/                    # Offline queue module (future use)
├── supabase_setup.sql        # DB schema, RLS policies, triggers
├── .env                      # Shared environment variables
└── README.md
```

## Quick Start

### 1. Supabase Setup

Run `supabase_setup.sql` in the Supabase SQL Editor to create all tables, RLS policies, and triggers.

### 2. Environment Variables

Copy and configure `.env` at the project root:

```
API_BASE_URL=http://localhost:8000
DEVICE_ID=<your-device-uuid>
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_KEY=<service-role-key>
```

For the website client, configure `website/client/.env`:

```
VITE_SUPABASE_URL=https://xxx.supabase.co
VITE_SUPABASE_ANON_KEY=<anon-key>
```

### 3. Run the Website

```bash
cd website/client
npm install
npm run dev
```

Or with Docker:

```bash
cd website
docker compose up --build
```

### 4. Run on Raspberry Pi

```bash
cd face-recognition
pip install -r requirements.txt

# Start the FastAPI gateway
uvicorn main:app --host 0.0.0.0 --port 8000

# In another terminal, start the edge controller
python run_edge.py
```

## Runtime Notes

- `run_edge.py` and `main.py` run on the same Pi but serve different purposes: `run_edge.py` reads sensors and captures images, while `main.py` is the HTTP gateway to Supabase.
- The website connects directly to Supabase (not to the Pi) for all data queries and real-time subscriptions.
