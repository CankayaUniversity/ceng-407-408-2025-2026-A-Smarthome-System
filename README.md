# IoT Smart Home System

A full-stack smart home system with Raspberry Pi edge processing, AI face recognition, Supabase-backed realtime data, an on-demand live camera relay, a React web dashboard, and a Flutter mobile application.

## Architecture

```text
                         ┌────────────────────────────┐
                         │        Supabase            │
                         │ PostgreSQL + Auth + Storage│
                         │ Realtime subscriptions     │
                         └──────────────▲─────────────┘
                                        │
                 SDK / REST             │             supabase-js / supabase_flutter
                                        │
┌────────────────────┐     HTTP     ┌───┴────────────────┐
│ Raspberry Pi Edge  │─────────────▶│ FastAPI Gateway    │
│ run_edge.py        │              │ main.py            │
│ sensors + camera   │              │ Pi → Supabase      │
│ face recognition   │              └────────────────────┘
└─────────┬──────────┘
          │ WebSocket streamer
          ▼
┌────────────────────┐        WebSocket viewer        ┌────────────────────┐
│ Oracle Cloud Relay │◀──────────────────────────────▶│ React Website      │
│ cloud/relay_server │                               │ Surveillance page  │
└────────────────────┘                               └────────────────────┘

Flutter Mobile App ────────────────────────────────▶ Supabase
```

- **Raspberry Pi**: Reads sensors (DHT11, MQ2, PIR, soil moisture), captures camera frames, runs face recognition, sends telemetry and events to the FastAPI gateway, and streams live camera frames to the Oracle relay when requested.
- **FastAPI Gateway** (`face-recognition/main.py`): Receives telemetry and events from the Pi and writes them to Supabase (DB + Storage).
- **Oracle Cloud Relay** (`cloud/relay_server.js`): WebSocket relay for live camera. The Pi registers as a streamer, the website registers as a viewer, and the relay sends start/stop control messages for on-demand streaming.
- **Supabase**: PostgreSQL database, Auth, Realtime subscriptions, and file Storage (`event-snapshots` bucket).
- **React Website** (`website/client/`): Connects directly to Supabase via `@supabase/supabase-js`. Displays real-time sensor data, camera events, alerts, residents, latest snapshots, and on-demand live camera.
- **Flutter Mobile App** (`Mobile-app/`): Native Android/iOS app built with Flutter. Connects directly to Supabase via `supabase_flutter`. Mirrors the web features with a mobile-optimized UI.

## Project Structure

```text
bitirmeProject/
├── face-recognition/
│   ├── main.py                         # FastAPI gateway (Pi → Supabase)
│   ├── run_edge.py                     # Pi entry point (sensors, camera, face recognition, live relay streamer)
│   ├── stream_camera.py                # Standalone live camera streamer fallback/test tool
│   ├── app/
│   │   ├── config.py                   # Central configuration
│   │   ├── api/
│   │   │   ├── gateway_client.py       # HTTP client for main.py
│   │   │   └── resident_sync.py        # Periodic resident face-embedding sync
│   │   ├── camera/
│   │   │   ├── __init__.py
│   │   │   ├── capture.py              # Picamera2 wrapper with shared camera access
│   │   │   └── color_utils.py          # CAMERA_COLOR_MODE handling
│   │   ├── vision/
│   │   │   ├── face_detector.py
│   │   │   ├── embedder.py
│   │   │   └── matcher.py
│   │   └── logging_system/
│   │       └── event_logger.py
│   └── requirements.txt
├── cloud/
│   ├── relay_server.js                 # Oracle WebSocket relay for live camera
│   ├── package.json
│   └── package-lock.json
├── website/
│   ├── client/                         # React + Vite frontend
│   │   ├── src/
│   │   │   ├── components/Surveillance/LiveCameraFeed.jsx
│   │   │   └── pages/CameraPage.jsx
│   │   ├── .env                        # VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY, VITE_RELAY_WS_URL
│   │   ├── Dockerfile
│   │   └── nginx.conf
│   └── docker-compose.yml
├── Mobile-app/                         # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart                   # App entry point, Supabase init, Provider tree
│   │   ├── config/
│   │   │   └── supabase_config.dart    # URL, anon key, table names, Storage helpers
│   │   ├── models/
│   │   │   ├── environment_data.dart   # SensorReading model
│   │   │   └── face_capture.dart       # FaceCapture model
│   │   ├── services/
│   │   ├── providers/
│   │   └── screens/
│   └── pubspec.yaml
├── supabase_setup.sql                  # DB schema, RLS policies, triggers
├── .env.example                        # Shared environment variable template
└── README.md
```

## Quick Start

### 1. Supabase Setup

Run `supabase_setup.sql` in the Supabase SQL Editor to create all tables, RLS policies, triggers, and Storage configuration.

### 2. Environment Variables

Copy and configure `.env` at the project root:

```env
API_BASE_URL=http://localhost:8000
DEVICE_ID=<your-device-uuid>
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_KEY=<service-role-key>
```

For the website, configure `website/client/.env`:

```env
VITE_SUPABASE_URL=https://xxx.supabase.co
VITE_SUPABASE_ANON_KEY=<anon-key>
VITE_RELAY_WS_URL=ws://92.5.17.205:8080
```

For the mobile app, edit `Mobile-app/lib/config/supabase_config.dart`:

```dart
static const String supabaseUrl = 'https://xxx.supabase.co';
static const String supabaseAnonKey = '<anon-key>';
```

For the Pi live camera relay, these environment variables are supported:

```env
RELAY_URL=ws://92.5.17.205:8080
RELAY_ENABLED=true
STREAM_ON_DEMAND=true
RELAY_FPS=15
RELAY_JPEG_QUALITY=60
CAMERA_COLOR_MODE=no_convert
```

`CAMERA_COLOR_MODE=no_convert` is the default for the tested Raspberry Pi OV5647 camera. Override it only for troubleshooting.

### 3. Run the Oracle Cloud Relay

On the Oracle VM:

```bash
cd ~/cloud
node relay_server.js
```

Expected log:

```text
[Relay] WebSocket relay server listening on port 8080
```

Port `8080` must be allowed in the Oracle VCN security list and the VM firewall rules.

### 4. Run the Raspberry Pi Gateway

In Pi terminal 1:

```bash
cd face-recognition
uvicorn main:app --host 0.0.0.0 --port 8000
```

### 5. Run the Raspberry Pi Edge Controller

In Pi terminal 2:

```bash
cd face-recognition
RELAY_URL=ws://92.5.17.205:8080 \
RELAY_ENABLED=true \
STREAM_ON_DEMAND=true \
CAMERA_COLOR_MODE=no_convert \
python3 run_edge.py
```

`run_edge.py` handles sensors, camera captures, face recognition, and integrated live relay streaming. Do not run `stream_camera.py` at the same time as `run_edge.py`, because both may compete for the same CSI camera.

### 6. Run the Website

```bash
cd website/client
npm install
npm run dev
```

Open:

```text
http://localhost:5173
```

Surveillance behavior:

- Page opens in **Snapshot** mode and shows the latest saved snapshot.
- Switching to **Live** renders the live camera panel, but it does not auto-connect.
- Pressing **LIVE** starts the WebSocket viewer and triggers Pi streaming through the relay.
- Pressing **STOP** closes the viewer connection and the relay tells the Pi to pause streaming.
- Face classification briefly shows **Scanning...** before resolving to the resident name or **Unknown Person**.

### 7. Run the Mobile App

Requires Flutter SDK ≥ 3.9.

```bash
cd Mobile-app
flutter pub get
flutter run
```

To build a release APK:

```bash
flutter build apk --release
```

## Live Camera Relay Details

The live camera is on-demand to avoid unnecessary bandwidth and camera workload.

```text
Website LIVE button
      │
      ▼
Website registers as viewer with Oracle relay
      │
      ▼
Relay sends {"type":"control","action":"start"} to Pi streamer
      │
      ▼
Pi starts sending base64 JPEG frames
      │
      ▼
Relay broadcasts frames to viewer(s)
```

When the last viewer disconnects, the relay sends:

```json
{"type":"control","action":"stop"}
```

The Pi remains connected but pauses frame capture/transmission.

### Standalone Live Camera Test

Use this only when `run_edge.py` is not running:

```bash
cd face-recognition
RELAY_URL=ws://92.5.17.205:8080 \
STREAM_ON_DEMAND=true \
CAMERA_COLOR_MODE=no_convert \
python3 stream_camera.py
```

## Camera Color Troubleshooting

The tested OV5647 CSI camera works best with:

```bash
CAMERA_COLOR_MODE=no_convert
```

Supported modes:

| Mode | Behavior |
|---|---|
| `no_convert` | Use the Picamera2 frame as-is. Default for this project. |
| `rgb_to_bgr` | Convert with `cv2.COLOR_RGB2BGR`. Useful for some Picamera2 configurations. |
| `bgr_to_rgb` | Reverse channel swap. Test only. |

Example:

```bash
CAMERA_COLOR_MODE=rgb_to_bgr python3 stream_camera.py
CAMERA_COLOR_MODE=no_convert python3 stream_camera.py
CAMERA_COLOR_MODE=bgr_to_rgb python3 stream_camera.py
```

## Runtime Notes

- `run_edge.py` and `main.py` run on the same Pi but serve different purposes: `run_edge.py` reads sensors, captures images, performs face recognition, and handles relay streaming; `main.py` is the HTTP gateway to Supabase.
- Both the website and mobile app connect **directly to Supabase** for data queries and real-time subscriptions.
- The live camera path is separate from Supabase: Pi → Oracle WebSocket relay → React website.
- The mobile app uses **Supabase Realtime** (`postgres_changes`) on the `sensor_readings`, `events`, and `camera_events` tables. A green dot in Settings confirms the channel is subscribed.

## Resident Photos and `embedding` Troubleshooting

1. The React app or Flutter app uploads the image to **Storage** and sets `residents.photo_path` in Supabase.
2. **`residents.embedding` is filled only by `main.py` (uvicorn)** on a background timer (`RESIDENT_EMBEDDING_REFRESH_SEC`, default 45 s; first pass ~3 s after startup). `run_edge.py` does **not** write embeddings.
3. **Verify in Supabase:** Table Editor → `residents` → check `embedding` (JSON array) for your row.
4. **Verify on the Pi:** In the uvicorn terminal, look for `Resident embedding stored` or `Resident embedding pass: ...` summary lines; warnings mean download / no-face / update failures.
5. **Force one pass without waiting:**

```bash
curl -s -X POST "http://127.0.0.1:8000/api/v1/residents/backfill-embeddings?device_id=YOUR_DEVICE_UUID"
```

Use the same `DEVICE_ID` as in `.env`.

## Common Commands

Check Oracle relay port:

```bash
sudo ss -lntp | grep 8080
```

Stop Pi processes:

```bash
pkill -f stream_camera.py
pkill -f run_edge.py
pkill -f uvicorn
```

Stop Oracle relay:

```bash
pkill -f relay_server.js
```

Check active Pi processes:

```bash
ps aux | grep -E "stream_camera|run_edge|uvicorn"
```
