"""
Heartbeat sender — background thread that periodically pings the backend.

This keeps the device's online/offline status visible on the dashboard
and also updates the local connectivity state used by other modules.
"""

import logging
import threading
import time

from cloud.connectivity import check_now
from cloud.config_loader import HEARTBEAT_INTERVAL_SECONDS

logger = logging.getLogger(__name__)


def _heartbeat_loop():
    """Periodically check backend health."""
    while True:
        try:
            online = check_now()
            status = "ONLINE" if online else "OFFLINE"
            logger.debug("Heartbeat: backend is %s", status)
        except Exception as exc:
            logger.error("Heartbeat error: %s", exc)

        time.sleep(HEARTBEAT_INTERVAL_SECONDS)


def start_heartbeat():
    """
    Start the heartbeat sender as a daemon background thread.
    Call once at startup from sh.py main().
    """
    thread = threading.Thread(
        target=_heartbeat_loop,
        name="CloudHeartbeat",
        daemon=True,
    )
    thread.start()
    logger.info(
        "Heartbeat thread started (interval: %ds)",
        HEARTBEAT_INTERVAL_SECONDS,
    )
    return thread
