"""
Connectivity checker for backend reachability.

Used by sync_worker and hooks to decide whether to attempt
a live request or go straight to the offline queue.
"""

import logging
import threading
import time

import requests

from cloud.config_loader import API_BASE_URL, REQUEST_TIMEOUT_SECONDS

logger = logging.getLogger(__name__)

_is_online = False
_lock = threading.Lock()


def is_backend_reachable() -> bool:
    """Return the last known connectivity state (non-blocking)."""
    with _lock:
        return _is_online


def check_now() -> bool:
    """
    Actively probe the backend health endpoint.
    Updates the cached state and returns it.
    """
    global _is_online
    try:
        resp = requests.get(
            f"{API_BASE_URL}/api/health",
            timeout=REQUEST_TIMEOUT_SECONDS,
        )
        online = resp.status_code == 200
    except Exception:
        online = False

    with _lock:
        prev = _is_online
        _is_online = online

    if online and not prev:
        logger.info("Backend connectivity RESTORED")
    elif not online and prev:
        logger.warning("Backend connectivity LOST")

    return online
