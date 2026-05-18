#!/usr/bin/env python3
"""
─────────────────────────────────────────────────────────────────
 SmartHome — Raspberry Pi Camera Streamer
─────────────────────────────────────────────────────────────────
 Captures frames from the camera, compresses them as JPEG, encodes
 to base64, and sends them over a WebSocket to the cloud relay.

 Capture backends (in priority order):
   1. Picamera2 — for Raspberry Pi CSI cameras (OV5647, IMX219, …)
   2. OpenCV VideoCapture — fallback for USB cameras / other platforms

 Features:
   • Configurable resolution, FPS, and JPEG quality
   • Automatic reconnection with exponential back-off
   • Graceful shutdown on SIGINT / SIGTERM
   • Frame-rate governor to cap CPU / bandwidth usage

 Usage:
   python3 stream_camera.py
   python3 stream_camera.py --width 640 --height 480 --fps 15

 Environment overrides (optional):
   RELAY_URL   — WebSocket relay URL  (default ws://165.245.243.130:8080)
   STREAM_FPS  — target frames per second
─────────────────────────────────────────────────────────────────
"""

import argparse
import base64
import json
import logging
import os
import signal
import sys
import time

import cv2
import numpy as np

try:
    import websocket  # websocket-client library
except ImportError:
    print("[Streamer] ERROR: 'websocket-client' package not found.")
    print("           Install it with:  pip install websocket-client")
    sys.exit(1)

# ── Optional Picamera2 import (preferred for CSI cameras) ─────

try:
    from picamera2 import Picamera2
    _PICAMERA2_AVAILABLE = True
except ImportError:
    _PICAMERA2_AVAILABLE = False

# ── Logging setup ────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [Streamer] %(levelname)s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

# ── Default configuration ────────────────────────────────────────

DEFAULT_RELAY_URL = "ws://165.245.243.130:8080"
DEFAULT_WIDTH = 640
DEFAULT_HEIGHT = 480
DEFAULT_FPS = 20
DEFAULT_JPEG_QUALITY = 60  # 0-100  lower = smaller payload
MAX_RECONNECT_DELAY = 30   # seconds
STREAM_ON_DEMAND = os.getenv("STREAM_ON_DEMAND", "true").lower() in ("1", "true", "yes")
CAMERA_COLOR_MODE = os.getenv("CAMERA_COLOR_MODE", "no_convert").lower().strip()


def normalize_frame(frame):
    """Convert raw Picamera2 frame to OpenCV BGR using CAMERA_COLOR_MODE."""
    if CAMERA_COLOR_MODE == "no_convert":
        return frame
    if CAMERA_COLOR_MODE == "rgb_to_bgr":
        return cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
    if CAMERA_COLOR_MODE == "bgr_to_rgb":
        return cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    log.warning("Unknown CAMERA_COLOR_MODE='%s', using rgb_to_bgr", CAMERA_COLOR_MODE)
    return cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

# ── Graceful shutdown flag ────────────────────────────────────────

_shutdown_requested = False


def _signal_handler(signum, _frame):
    """Handle SIGINT / SIGTERM gracefully."""
    global _shutdown_requested
    log.info("Shutdown signal received (signal %d)", signum)
    _shutdown_requested = True


signal.signal(signal.SIGINT, _signal_handler)
signal.signal(signal.SIGTERM, _signal_handler)

# ── Argument parser ───────────────────────────────────────────────


def parse_args():
    parser = argparse.ArgumentParser(
        description="Stream camera frames to the cloud relay server."
    )
    parser.add_argument(
        "--url",
        default=os.getenv("RELAY_URL", DEFAULT_RELAY_URL),
        help="WebSocket relay URL (default: %(default)s)",
    )
    parser.add_argument(
        "--width",
        type=int,
        default=DEFAULT_WIDTH,
        help="Capture width in pixels (default: %(default)s)",
    )
    parser.add_argument(
        "--height",
        type=int,
        default=DEFAULT_HEIGHT,
        help="Capture height in pixels (default: %(default)s)",
    )
    parser.add_argument(
        "--fps",
        type=int,
        default=int(os.getenv("STREAM_FPS", str(DEFAULT_FPS))),
        help="Target frames per second (default: %(default)s)",
    )
    parser.add_argument(
        "--quality",
        type=int,
        default=DEFAULT_JPEG_QUALITY,
        help="JPEG compression quality 0-100 (default: %(default)s)",
    )
    parser.add_argument(
        "--camera",
        type=int,
        default=0,
        help="Camera device index (default: %(default)s)",
    )
    return parser.parse_args()

# ── Camera backends ───────────────────────────────────────────────


class Picamera2Backend:
    """CSI camera capture via Picamera2 (Raspberry Pi)."""

    def __init__(self, width: int, height: int):
        self._picam = Picamera2()
        config = self._picam.create_preview_configuration(
            main={"size": (width, height), "format": "RGB888"}
        )
        self._picam.configure(config)
        self._picam.start()
        # Allow AWB / AE to stabilize
        time.sleep(1.0)
        actual = self._picam.camera_configuration()["main"]["size"]
        log.info("Picamera2 started (RGB888, color_mode=%s) — resolution: %dx%d",
                 CAMERA_COLOR_MODE, actual[0], actual[1])

    def read(self):
        """Return (success, bgr_frame)."""
        try:
            raw_frame = self._picam.capture_array()
            bgr_frame = normalize_frame(raw_frame)
            return True, bgr_frame
        except Exception as exc:
            log.warning("Picamera2 capture failed: %s", exc)
            return False, None

    def release(self):
        try:
            self._picam.stop()
            self._picam.close()
        except Exception:
            pass


class OpenCVBackend:
    """USB/generic camera capture via OpenCV VideoCapture (fallback)."""

    def __init__(self, index: int, width: int, height: int):
        log.info("Opening OpenCV camera device %d  (%dx%d)", index, width, height)
        self._cap = cv2.VideoCapture(index)
        if not self._cap.isOpened():
            raise RuntimeError(f"Failed to open camera device {index}")
        self._cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        self._cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
        self._cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        actual_w = int(self._cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        actual_h = int(self._cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        log.info("OpenCV camera opened — resolution: %dx%d", actual_w, actual_h)

    def read(self):
        """Return (success, bgr_frame)."""
        return self._cap.read()

    def release(self):
        try:
            self._cap.release()
        except Exception:
            pass


def open_camera(index: int, width: int, height: int):
    """Open the best available camera backend: Picamera2 first, then OpenCV."""
    if _PICAMERA2_AVAILABLE:
        try:
            log.info("Attempting Picamera2 backend (CSI camera)…")
            return Picamera2Backend(width, height)
        except Exception as exc:
            log.warning("Picamera2 init failed (%s) — falling back to OpenCV", exc)

    try:
        return OpenCVBackend(index, width, height)
    except RuntimeError as exc:
        log.error("%s", exc)
        return None

# ── Main streaming loop ──────────────────────────────────────────


def _check_control(ws):
    """Non-blocking check for a control message from the relay."""
    try:
        ws.settimeout(0)
        data = ws.recv()
        ws.settimeout(10)
        msg = json.loads(data)
        if msg.get("type") == "control":
            return msg.get("action")
    except (websocket.WebSocketException, BlockingIOError, json.JSONDecodeError):
        pass
    except Exception:
        pass
    finally:
        try:
            ws.settimeout(10)
        except Exception:
            pass
    return None


def stream(args):
    """Connect to relay and continuously send base64-encoded JPEG frames."""
    reconnect_delay = 1  # seconds — grows exponentially on failure
    on_demand = STREAM_ON_DEMAND

    while not _shutdown_requested:
        ws = None
        cam = None
        try:
            # ── Connect to relay ──
            log.info("Connecting to relay at %s …", args.url)
            ws = websocket.create_connection(
                args.url,
                timeout=10,
                enable_multithread=False,
            )
            log.info("WebSocket connection established")

            # ── Register as streamer ──
            ws.send(json.dumps({"role": "streamer"}))
            log.info("Registered as streamer")

            # Reset back-off on successful connection
            reconnect_delay = 1

            # ── Open camera ──
            cam = open_camera(args.camera, args.width, args.height)
            if cam is None:
                raise RuntimeError("Camera unavailable")

            frame_interval = 1.0 / args.fps
            encode_params = [cv2.IMWRITE_JPEG_QUALITY, args.quality]
            frame_count = 0
            last_log_time = time.time()

            # On-demand: start paused and wait for relay "start" control
            streaming_active = not on_demand
            if on_demand:
                log.info("On-demand mode: waiting for viewer (control:start)...")
            else:
                log.info("Streaming at %d FPS  (JPEG quality %d) …", args.fps, args.quality)

            while not _shutdown_requested:
                # Check for control messages from relay
                action = _check_control(ws)
                if action == "start" and not streaming_active:
                    streaming_active = True
                    frame_count = 0
                    last_log_time = time.time()
                    log.info("Viewer connected — streaming started")
                elif action == "stop" and streaming_active:
                    streaming_active = False
                    log.info("No viewers — streaming paused")

                if not streaming_active:
                    time.sleep(0.25)
                    continue

                loop_start = time.time()

                ret, frame = cam.read()
                if not ret:
                    log.warning("Camera read failed — retrying in 1 s")
                    time.sleep(1)
                    continue

                # Encode frame to JPEG → base64
                success, buffer = cv2.imencode(".jpg", frame, encode_params)
                if not success:
                    continue

                b64_frame = base64.b64encode(buffer).decode("ascii")

                # Send to relay
                ws.send(b64_frame)
                frame_count += 1

                # Periodic throughput log (every 10 seconds)
                now = time.time()
                if now - last_log_time >= 10.0:
                    elapsed = now - last_log_time
                    fps_actual = frame_count / elapsed if elapsed > 0 else 0
                    payload_kb = len(b64_frame) / 1024
                    log.info(
                        "Sent %d frames in %.1f s  (%.1f FPS, ~%.0f KB/frame)",
                        frame_count, elapsed, fps_actual, payload_kb,
                    )
                    frame_count = 0
                    last_log_time = now

                # Frame-rate governor
                elapsed = time.time() - loop_start
                sleep_time = frame_interval - elapsed
                if sleep_time > 0:
                    time.sleep(sleep_time)

        except (
            websocket.WebSocketException,
            ConnectionError,
            OSError,
            RuntimeError,
        ) as exc:
            log.error("Connection error: %s", exc)

        except Exception as exc:
            log.exception("Unexpected error: %s", exc)

        finally:
            if cam is not None:
                cam.release()
                log.info("Camera released")
            if ws is not None:
                try:
                    ws.close()
                except Exception:
                    pass
                log.info("WebSocket closed")

        if _shutdown_requested:
            break

        log.info("Reconnecting in %d s …", reconnect_delay)
        time.sleep(reconnect_delay)
        reconnect_delay = min(reconnect_delay * 2, MAX_RECONNECT_DELAY)

    log.info("Streamer stopped.")


# ── Entry point ───────────────────────────────────────────────────

if __name__ == "__main__":
    args = parse_args()
    stream(args)
