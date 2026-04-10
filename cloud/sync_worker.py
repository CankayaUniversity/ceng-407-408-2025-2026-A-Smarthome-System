"""
Sync worker — background thread that drains the offline queue.

Periodically checks the SQLite queue for pending items and attempts
to resend them to the backend. Respects ordering: events first,
then snapshots (by row id / FIFO).
"""

import json
import logging
import threading
import time

from cloud import api_client
from cloud import queue as q
from cloud.api_client import NonRetryableError
from cloud.connectivity import check_now, is_backend_reachable
from cloud.config_loader import SYNC_RETRY_INTERVAL_SECONDS

logger = logging.getLogger(__name__)


_RESULT_SUCCESS = "success"
_RESULT_RETRYABLE = "retryable"
_RESULT_NON_RETRYABLE = "non_retryable"


def _dispatch_item(item: dict) -> str:
    """
    Try to send a single queued item.
    Returns _RESULT_SUCCESS, _RESULT_RETRYABLE, or _RESULT_NON_RETRYABLE.
    """
    endpoint = item["endpoint"]
    payload = json.loads(item["payload_json"])
    file_path = item.get("file_path")
    request_type = item["request_type"]

    try:
        # Route to the correct api_client function based on endpoint
        if endpoint == "/api/sensors/readings":
            if "readings" in payload:
                result = api_client.send_sensor_readings_batch(payload["readings"])
            else:
                result = api_client.send_sensor_reading(
                    payload.get("sensorId", ""),
                    payload.get("value", 0),
                )

        elif endpoint == "/api/alerts":
            result = api_client.send_alert(
                alert_type=payload.get("type", ""),
                message=payload.get("message", ""),
                severity=payload.get("severity", "warning"),
            )

        elif endpoint == "/api/camera/events":
            result = api_client.send_camera_event(
                result=payload.get("result", "unknown"),
                match_score=float(payload["match_score"]) if payload.get("match_score") else None,
                person_id=payload.get("person_id"),
                face_count=int(payload["face_count"]) if payload.get("face_count") else None,
                faces_json=payload.get("faces"),
                image_path=file_path,
            )

        else:
            logger.warning("Unknown endpoint in queue: %s", endpoint)
            return _RESULT_NON_RETRYABLE

        return _RESULT_SUCCESS if result is not None else _RESULT_RETRYABLE

    except NonRetryableError as nr_exc:
        logger.error("Queue item %d DROPPED (non-retryable HTTP %d): %s",
                      item["id"], nr_exc.status_code, nr_exc.detail[:120])
        return _RESULT_NON_RETRYABLE
    except Exception as exc:
        logger.error("Dispatch error for queue item %d: %s", item["id"], exc)
        return _RESULT_RETRYABLE


def _drain_cycle():
    """Run one drain cycle: peek items, try to send, update queue."""
    items = q.peek(limit=20)
    if not items:
        return

    logger.info("Sync worker: %d pending items, attempting drain…", len(items))

    for item in items:
        # Re-check connectivity before each item to fail fast
        if not is_backend_reachable():
            logger.info("Backend offline mid-drain, stopping cycle")
            break

        outcome = _dispatch_item(item)

        if outcome == _RESULT_SUCCESS:
            q.mark_done(item["id"])
        elif outcome == _RESULT_NON_RETRYABLE:
            q.mark_done(item["id"])
            logger.warning("Queue item %d removed — non-retryable error", item["id"])
        else:
            q.mark_failed(item["id"], "dispatch_failed")


def _worker_loop():
    """Main loop for the background sync worker thread."""
    while True:
        try:
            # First check connectivity
            online = check_now()

            if online:
                _drain_cycle()

                # Purge items that have exceeded retry limit
                q.purge_dead_letters()

            pending = q.count_pending()
            if pending > 0:
                logger.info("Sync worker: %d items still pending", pending)

        except Exception as exc:
            logger.error("Sync worker error: %s", exc)

        time.sleep(SYNC_RETRY_INTERVAL_SECONDS)


def start_sync_worker():
    """
    Start the sync worker as a daemon background thread.
    Call once at startup from sh.py main().
    """
    thread = threading.Thread(
        target=_worker_loop,
        name="CloudSyncWorker",
        daemon=True,
    )
    thread.start()
    logger.info(
        "Cloud sync worker started (interval: %ds)",
        SYNC_RETRY_INTERVAL_SECONDS,
    )
    return thread
