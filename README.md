# IoT Smart Home System

Full-stack smart home: Raspberry Pi edge (sensors, camera, face recognition), Supabase backend, DigitalOcean WebSocket relay for on-demand live camera, Flask push server (FCM), React web dashboard (GitHub Pages), Flutter mobile app.

**Current production (May 2026):** Oracle Cloud replaced by **DigitalOcean Droplet** (`165.245.243.130`). Pi services run under **systemd** on boot.

Detailed handoff for new contributors / AI sessions: **[docs/PROJECT_HANDOFF.md](docs/PROJECT_HANDOFF.md)**

## Architecture

```text
                         ┌────────────────────────────┐
                         │        Supabase            │
                         │ PostgreSQL + Auth + Storage│
                         │ Realtime + DB webhooks     │
                         └──────────────▲─────────────┘
                                        │
                 SDK / REST             │             supabase-js / supabase_flutter
                                        │
┌────────────────────┐     HTTP     ┌───┴────────────────┐
│ Raspberry Pi       │─────────────▶│ FastAPI Gateway    │
│ smarthome-edge     │   :8000      │ smarthome-gateway  │
│ (systemd)          │              │ main.py            │
└─────────┬──────────┘              └────────────────────┘
          │ wss streamer
          ▼
┌────────────────────┐   wss viewer   ┌────────────────────┐
│ DigitalOcean Relay │◀──────────────▶│ Web + Mobile       │
│ relay.yoursmarthome│                │ (on-demand LIVE)   │
│ .app               │                └────────────────────┘
└─────────┬──────────┘
          │
          │ events INSERT webhook
          ▼
┌────────────────────┐
│ Push API           │
│ api.yoursmarthome  │──▶ Firebase FCM ──▶ phone
│ .app/alarm         │
└────────────────────┘
```

| Layer | Role |
|-------|------|
| **Pi edge** (`run_edge.py`) | PIR, DHT/MQ2/soil, camera burst, face match, relay JPEG streamer |
| **Pi gateway** (`main.py`) | Supabase writes: sensors, events, snapshots, resident embedding backfill |
| **Relay** (`cloud/relay_server.js`) | WebSocket hub: one streamer (Pi), many viewers (web/mobile), start/stop control |
| **Push** (`cloud/push_server/`) | Supabase webhook → FCM HTTP v1 |
| **Supabase** | Data, auth, `event-snapshots` storage, Realtime |
| **Web** | `https://yoursmarthome.app` (deploy via separate `smarthome-website` repo) |
| **Mobile** | Flutter → Supabase + relay WSS for live view |

## Project structure

```text
bitirmeProject/
├── face-recognition/
│   ├── main.py                    # FastAPI gateway
│   ├── run_edge.py                # Edge: sensors, camera, face, relay
│   ├── deploy/                    # systemd unit templates (Pi)
│   ├── app/vision/matcher.py      # Face match (threshold + margin)
│   └── requirements.txt
├── cloud/
│   ├── relay_server.js            # WebSocket relay
│   └── push_server/               # Flask push webhook (Droplet)
├── website/client/                # React + Vite
├── Mobile-app/                    # Flutter
├── supabase/migrations/
├── docs/PROJECT_HANDOFF.md        # Full ops + state doc
└── README.md
```

## Environment variables

### Pi — root `.env`

Copy from `.env.example`. Critical fields:

```env
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_KEY=<service-role-secret>
API_BASE_URL=http://127.0.0.1:8000
DEVICE_ID=<uuid-from-devices-table>

RELAY_URL=wss://relay.yoursmarthome.app
RELAY_ENABLED=true
STREAM_ON_DEMAND=true
CAMERA_COLOR_MODE=no_convert

# Face matching (Euclidean distance; lower = closer)
FACE_MATCH_THRESHOLD=0.45
FACE_MATCH_MIN_MARGIN=0.06
```

### Web — `website/client/.env` (and GitHub Actions secrets for Pages)

```env
VITE_SUPABASE_URL=...
VITE_SUPABASE_ANON_KEY=sb_publishable_...
VITE_RELAY_WS_URL=wss://relay.yoursmarthome.app
VITE_DEVICE_ID=<same-as-pi-DEVICE_ID>
VITE_SITE_URL=https://yoursmarthome.app
# Optional: Pi gateway for Identity "Cluster" button (LAN/tunnel only)
# VITE_GATEWAY_URL=http://192.168.x.x:8000
```

### Mobile

Default relay URL in `Mobile-app/lib/config/relay_config.dart` (`wss://relay.yoursmarthome.app`). Override at build time:

```bash
flutter run --dart-define=RELAY_WS_URL=wss://relay.yoursmarthome.app
```

### Droplet push — `/opt/smarthome-push/.env` (never commit)

`WEBHOOK_SECRET`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, Firebase service account JSON. See `cloud/push_server/env.example`.

## Raspberry Pi — systemd (recommended)

Install unit files from `face-recognition/deploy/` (adjust `User` and paths if needed), then:

```bash
sudo cp face-recognition/deploy/smarthome-*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable smarthome-gateway smarthome-edge
sudo systemctl start smarthome-gateway smarthome-edge
```

Use `python3 -m uvicorn` in gateway unit ( `venv/bin/uvicorn` may not exist).

```bash
systemctl is-active smarthome-gateway smarthome-edge
journalctl -u smarthome-edge -f
```

Expect: `Live relay streaming enabled → wss://relay.yoursmarthome.app`, `Registered as streamer`.

**Manual dev mode** (do not run alongside systemd):

```bash
cd face-recognition && source venv/bin/activate
uvicorn main:app --host 0.0.0.0 --port 8000    # terminal 1
python3 run_edge.py                             # terminal 2
```

Do not run `stream_camera.py` while `run_edge.py` is active (camera lock).

### Pi 5 venv + camera

```bash
sudo apt install -y python3-picamera2 python3-libcamera python3-venv
python3 -m venv --system-site-packages venv
source venv/bin/activate
pip install -r requirements.txt
pip install git+https://github.com/ageitgey/face_recognition_models
```

## DigitalOcean Droplet

| Service | systemd | URL |
|---------|---------|-----|
| Relay | `smarthome-relay` | `wss://relay.yoursmarthome.app` → localhost:8080 |
| Push | `smarthome-push` | `https://api.yoursmarthome.app/health`, `POST /alarm` |

Repo on server: `/opt/smarthome-relay`. Push app files: `/opt/smarthome-push` (copy from `cloud/push_server/` after pull).

```bash
cd /opt/smarthome-relay
git pull origin feature/identity-review-unknown-faces
cp -r /opt/smarthome-relay/cloud/push_server/* /opt/smarthome-push/
systemctl restart smarthome-relay smarthome-push
curl -s https://api.yoursmarthome.app/health
```

Firewall: 22, 80, 443, 8080 (8080 optional if only nginx WSS is used).

## Live camera (on-demand)

```text
User presses LIVE (web/mobile)
  → viewer connects to relay (wss)
  → relay sends {"type":"control","action":"start"} to Pi streamer
  → Pi sends base64 JPEG frames → relay → viewer
STOP / disconnect last viewer → action "stop" → Pi pauses frames
```

## Web — local dev

```bash
cd website/client
npm install
npm run dev
```

Production: push `website/client` to **`smarthome-website`** repo; GitHub Pages + Actions secrets (`VITE_RELAY_WS_URL`, etc.). Root domain stays on GitHub; `relay` / `api` DNS point to Droplet (Cloudflare, grey cloud).

## Mobile

```bash
cd Mobile-app
flutter pub get
flutter run
```

## Supabase setup

Run `supabase_setup.sql` (and migrations under `supabase/migrations/` as needed). Webhook for push must target `https://api.yoursmarthome.app/alarm` with header `X-Webhook-Secret` matching Droplet `.env`. Remove any old Oracle function URL.

## Resident embeddings

1. App uploads photo → Storage, sets `residents.photo_path`.
2. **Only `main.py`** backfills `residents.embedding` (timer ~45s).
3. Pi `resident_sync` pulls embeddings into local `residents.json` for `FaceMatcher`.
4. Force backfill: `curl -X POST "http://127.0.0.1:8000/api/v1/residents/backfill-embeddings?device_id=DEVICE_ID"`

## Events status

`events.status` must be `pending` or `acknowledged` (see `supabase/migrations/005_events_status_check.sql`). Gateway inserts use `pending`.

## Troubleshooting

| Issue | Check |
|-------|--------|
| No snapshot | `systemctl status smarthome-gateway`; edge log for `Connection refused` |
| No live video | Pi edge active; press LIVE; `journalctl -u smarthome-edge \| grep Relay` |
| Wrong person ID | `FACE_MATCH_*` in `.env`; re-enroll photos; see matcher margin logs |
| Push missing | `curl https://api.yoursmarthome.app/health`; Supabase webhook URL |
| DHT 0 / error | Hardware wiring (`HARDWARE_ERROR`) |
| Gas spam | MQ2 wiring/threshold; `GAS_ALERT_COOLDOWN_SECONDS` |

```bash
# Pi
sudo systemctl restart smarthome-gateway smarthome-edge
journalctl -u smarthome-gateway -n 50 --no-pager
journalctl -u smarthome-edge -n 50 --no-pager

# Stop until next boot (if enabled, reboot will start again)
sudo systemctl stop smarthome-edge smarthome-gateway
```

## Legacy / deprecated

- **Oracle Cloud VM** (`92.5.17.205`) and **OCI Function** `push_alarm` — replaced by DigitalOcean.
- **`oci_functions/`** — reference only; production push is `cloud/push_server/`.
- Direct `ws://165.245.243.130:8080` — dev fallback; production uses **WSS** hostnames.
