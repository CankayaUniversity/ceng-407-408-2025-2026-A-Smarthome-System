"""
SQLite-based offline queue for failed cloud requests.

When a request to the backend fails (network down, timeout, etc.),
the caller enqueues it here. The sync_worker drains the queue when
connectivity is restored.
"""

import json
import logging
import sqlite3
import threading
from datetime import datetime, timezone
from pathlib import Path

from cloud.config_loader import QUEUE_DB_PATH, MAX_RETRY_COUNT

logger = logging.getLogger(__name__)

_lock = threading.Lock()


def _connect() -> sqlite3.Connection:
    QUEUE_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(QUEUE_DB_PATH), timeout=5)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """Create the queue table if it doesn't exist. Call once at startup."""
    with _lock:
        conn = _connect()
        try:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS cloud_queue (
                    id            INTEGER PRIMARY KEY AUTOINCREMENT,
                    request_type  TEXT    NOT NULL,
                    endpoint      TEXT    NOT NULL,
                    payload_json  TEXT    NOT NULL,
                    file_path     TEXT,
                    retry_count   INTEGER NOT NULL DEFAULT 0,
                    last_error    TEXT,
                    created_at    TEXT    NOT NULL
                )
            """)
            conn.commit()
        finally:
            conn.close()
    logger.info("Offline queue DB initialized at %s", QUEUE_DB_PATH)


def enqueue(
    request_type: str,
    endpoint: str,
    payload: dict,
    file_path: str | None = None,
) -> int:
    """
    Add a failed request to the queue.
    Returns the row id of the inserted record.
    """
    now = datetime.now(timezone.utc).isoformat()
    payload_json = json.dumps(payload, ensure_ascii=False)

    with _lock:
        conn = _connect()
        try:
            cur = conn.execute(
                """
                INSERT INTO cloud_queue
                    (request_type, endpoint, payload_json, file_path, retry_count, created_at)
                VALUES (?, ?, ?, ?, 0, ?)
                """,
                (request_type, endpoint, payload_json, file_path, now),
            )
            conn.commit()
            row_id = cur.lastrowid
        finally:
            conn.close()

    logger.info("Enqueued [%s] → %s (id=%d)", request_type, endpoint, row_id)
    return row_id


def peek(limit: int = 20) -> list[dict]:
    """
    Get the oldest pending items (FIFO order).
    Only returns items that haven't exceeded MAX_RETRY_COUNT.
    """
    with _lock:
        conn = _connect()
        try:
            rows = conn.execute(
                """
                SELECT id, request_type, endpoint, payload_json, file_path,
                       retry_count, last_error, created_at
                FROM cloud_queue
                WHERE retry_count < ?
                ORDER BY id ASC
                LIMIT ?
                """,
                (MAX_RETRY_COUNT, limit),
            ).fetchall()
        finally:
            conn.close()

    return [dict(r) for r in rows]


def mark_done(row_id: int):
    """Remove a successfully sent item from the queue."""
    with _lock:
        conn = _connect()
        try:
            conn.execute("DELETE FROM cloud_queue WHERE id = ?", (row_id,))
            conn.commit()
        finally:
            conn.close()
    logger.debug("Queue item %d removed (success)", row_id)


def mark_failed(row_id: int, error_message: str):
    """Increment retry count and store last error."""
    with _lock:
        conn = _connect()
        try:
            conn.execute(
                """
                UPDATE cloud_queue
                SET retry_count = retry_count + 1,
                    last_error  = ?
                WHERE id = ?
                """,
                (error_message, row_id),
            )
            conn.commit()
        finally:
            conn.close()
    logger.debug("Queue item %d retry incremented: %s", row_id, error_message)


def count_pending() -> int:
    """Return the number of items still pending in the queue."""
    with _lock:
        conn = _connect()
        try:
            row = conn.execute(
                "SELECT COUNT(*) as cnt FROM cloud_queue WHERE retry_count < ?",
                (MAX_RETRY_COUNT,),
            ).fetchone()
        finally:
            conn.close()
    return row["cnt"] if row else 0


def purge_dead_letters():
    """Remove items that have exceeded MAX_RETRY_COUNT."""
    with _lock:
        conn = _connect()
        try:
            cur = conn.execute(
                "DELETE FROM cloud_queue WHERE retry_count >= ?",
                (MAX_RETRY_COUNT,),
            )
            conn.commit()
            removed = cur.rowcount
        finally:
            conn.close()
    if removed:
        logger.warning("Purged %d dead-letter queue items", removed)
