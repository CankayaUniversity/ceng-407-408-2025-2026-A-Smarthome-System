# IoT Smart Home System

A full-stack smart home system with Raspberry Pi edge processing, AI face recognition, a real-time web dashboard, and a Flutter mobile application.

## Architecture

```
Pi Edge (run_edge.py)  ──HTTP──>  FastAPI Gateway (main.py)  ──SDK──>  Supabase
                                                                          ↑   ↑
React Website  ──supabase-js────────────────────────────────────────────┘   │
Flutter Mobile App  ──supabase_flutter──────────────────────────────────────┘
```

- **Raspberry Pi**: Reads sensors (DHT11, MQ2, PIR, soil moisture), captures camera frames, runs face recognition, sends telemetry and events to the FastAPI gateway.
- **FastAPI Gateway** (`face-recognition/main.py`): Receives telemetry and events from the Pi and writes them to Supabase (DB + Storage).
- **Supabase**: PostgreSQL database, Auth, Realtime subscriptions, and file Storage (`event-snapshots` bucket).
- **React Website** (`website/client/`): Connects directly to Supabase via `@supabase/supabase-js`. Displays real-time sensor data, camera events, alerts, and manages residents.
- **Flutter Mobile App** (`Mobile-app/`): Native Android/iOS app built with Flutter. Connects directly to Supabase via `supabase_flutter`. Mirrors all web features with a mobile-optimised UI.

## Project Structure

```
bitirmeProject/
├── face-recognition/
│   ├── main.py                   # FastAPI gateway (Pi → Supabase)
│   ├── run_edge.py               # Pi entry point (sensors, camera, face recognition)
│   ├── app/
│   │   ├── config.py             # Central configuration
│   │   ├── api/
│   │   │   ├── gateway_client.py # HTTP client for main.py
│   │   │   └── resident_sync.py  # Periodic resident face-embedding sync
│   │   ├── camera/
│   │   │   └── capture.py        # Picamera2 wrapper
│   │   ├── vision/
│   │   │   ├── face_detector.py
│   │   │   ├── embedder.py
│   │   │   └── matcher.py
│   │   └── logging_system/
│   │       └── event_logger.py
│   └── requirements.txt
├── website/
│   ├── client/                   # React + Vite frontend
│   │   ├── src/
│   │   ├── .env                  # VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY
│   │   ├── Dockerfile
│   │   └── nginx.conf
│   └── docker-compose.yml
├── Mobile-app/                   # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart             # App entry point, Supabase init, Provider tree
│   │   ├── config/
│   │   │   └── supabase_config.dart   # URL, anon key, table names, Storage helpers
│   │   ├── models/
│   │   │   ├── environment_data.dart  # SensorReading model (maps sensor_readings table)
│   │   │   └── face_capture.dart      # FaceCapture model (camera_events + event_faces join)
│   │   ├── services/
│   │   │   ├── supabase_auth_service.dart     # Auth (sign-in, sign-up, profile CRUD)
│   │   │   ├── supabase_data_service.dart     # All Supabase data queries
│   │   │   ├── supabase_realtime_service.dart # Realtime postgres_changes subscriptions
│   │   │   └── notification_service.dart      # flutter_local_notifications wrapper
│   │   ├── providers/
│   │   │   ├── auth_provider.dart             # Auth state, session, user profile
│   │   │   ├── supabase_data_provider.dart    # Data state (sensors, events, residents)
│   │   │   └── notification_provider.dart     # Realtime alerts + local notification triggers
│   │   └── screens/
│   │       ├── login_screen.dart              # Sign-in / Sign-up
│   │       ├── app_shell.dart                 # Bottom nav shell + popup handler
│   │       ├── home_screen.dart (lib/)        # Dashboard (sensor summary, camera feed, alerts)
│   │       ├── rooms_screen.dart              # Per-room sensor cards
│   │       ├── history_screen.dart            # Sensor history charts (24h / 7d / 30d)
│   │       ├── camera_screen.dart (lib/)      # Camera event log with face photos
│   │       ├── alerts_screen.dart (lib/)      # Recent alerts with acknowledge
│   │       ├── security_alert_screen.dart (lib/)  # Face-detection popup (resident / unknown)
│   │       ├── residents_screen.dart          # Resident management + photo upload
│   │       └── settings_screen.dart (lib/)   # Profile, Supabase status, logout
│   └── pubspec.yaml
├── cloud/                        # Offline queue module (future use)
├── supabase_setup.sql            # DB schema, RLS policies, triggers
├── .env.example                  # Shared environment variable template
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

For the website, configure `website/client/.env`:

```
VITE_SUPABASE_URL=https://xxx.supabase.co
VITE_SUPABASE_ANON_KEY=<anon-key>
```

For the mobile app, edit `Mobile-app/lib/config/supabase_config.dart`:

```dart
static const String supabaseUrl = 'https://xxx.supabase.co';
static const String supabaseAnonKey = '<anon-key>';
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

### 4. Run the Mobile App

Requires Flutter SDK ≥ 3.9.

```bash
cd Mobile-app
flutter pub get
flutter run          # connects to a plugged device or emulator
```

To build a release APK:

```bash
flutter build apk --release
```

### 5. Run on Raspberry Pi

```bash
cd face-recognition
pip install -r requirements.txt

# Start the FastAPI gateway
uvicorn main:app --host 0.0.0.0 --port 8000

# In another terminal, start the edge controller
python run_edge.py
```

## Runtime Notes

- `run_edge.py` and `main.py` run on the same Pi but serve different purposes: `run_edge.py` reads sensors and captures images; `main.py` is the HTTP gateway to Supabase.
- Both the website and mobile app connect **directly to Supabase** (not to the Pi) for all data queries and real-time subscriptions.
- The mobile app uses **Supabase Realtime** (`postgres_changes`) on the `sensor_readings`, `events`, and `camera_events` tables. A green dot in Settings confirms the channel is subscribed.

### Resident Photos and `embedding` (Troubleshooting)

1. The React app or Flutter app uploads the image to **Storage** and sets `residents.photo_path` in Supabase (immediate).
2. **`residents.embedding` is filled only by `main.py` (uvicorn)** on a background timer (`RESIDENT_EMBEDDING_REFRESH_SEC`, default 45 s; first pass ~3 s after startup). `run_edge.py` does **not** write embeddings.
3. **Verify in Supabase:** Table Editor → `residents` → check `embedding` (JSON array) for your row.
4. **Verify on the Pi:** In the uvicorn terminal, look for `Resident embedding stored` or `Resident embedding pass: ...` summary lines; warnings mean download / no-face / update failures.
5. **Force one pass without waiting:**

```bash
curl -s -X POST "http://127.0.0.1:8000/api/v1/residents/backfill-embeddings?device_id=YOUR_DEVICE_UUID"
```

Use the same `DEVICE_ID` as in `.env`.
