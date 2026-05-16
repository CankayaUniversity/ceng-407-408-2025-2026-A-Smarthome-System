"""
Cluster unknown face detections into recurring visitor profiles (gateway-side).

Runs after upload-intelligent when classification is 'unknown'. Uses Euclidean
distance on 128-D embeddings (same family as FaceMatcher).
"""

from __future__ import annotations

import logging
import math
import os
import tempfile
from typing import Any, Optional
from datetime import datetime, timezone

logger = logging.getLogger(__name__)


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

UNKNOWN_CLUSTER_THRESHOLD = float(os.getenv("UNKNOWN_CLUSTER_THRESHOLD", "0.48"))


def _euclidean(a: list, b: list) -> float:
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def _mean_embedding(vectors: list[list]) -> list:
    if not vectors:
        return []
    dim = len(vectors[0])
    acc = [0.0] * dim
    for v in vectors:
        for i, val in enumerate(v):
            acc[i] += val
    n = len(vectors)
    return [x / n for x in acc]


def cluster_unknown_detection(
    supabase,
    embedder,
    image_bytes: bytes,
    event_face_id: str,
    camera_event_id: str,
    snapshot_path: str,
) -> Optional[dict[str, Any]]:
    """
    Assign this unknown detection to an existing profile or create a new one.
    Returns summary dict or None on failure.
    """
    suffix = ".jpg"
    tmp_path = None
    try:
        fd, tmp_path = tempfile.mkstemp(suffix=suffix)
        with os.fdopen(fd, "wb") as f:
            f.write(image_bytes)
        embedding = embedder.get_embedding(tmp_path)
    except Exception as exc:
        logger.warning("Unknown clustering: embedding failed: %s", exc)
        return None
    finally:
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass

    if not embedding:
        return None

    profiles = (
        supabase.table("unknown_face_profiles")
        .select("id, display_label, sighting_count, centroid_embedding, representative_snapshot_path")
        .eq("status", "active")
        .execute()
        .data
        or []
    )

    best_id = None
    best_dist = float("inf")
    best_row = None

    for row in profiles:
        centroid = row.get("centroid_embedding")
        if not isinstance(centroid, list) or len(centroid) == 0:
            continue
        try:
            dist = _euclidean(embedding, centroid)
        except ValueError:
            continue
        if dist < best_dist:
            best_dist = dist
            best_id = row["id"]
            best_row = row

    if best_id and best_dist <= UNKNOWN_CLUSTER_THRESHOLD:
        profile_id = best_id
        old_centroid = best_row.get("centroid_embedding") or []
        new_centroid = _mean_embedding([old_centroid, embedding]) if old_centroid else embedding
        new_count = int(best_row.get("sighting_count") or 0) + 1
        label = best_row.get("display_label") or "Unknown visitor"
        if new_count > 1 and not label.startswith("Unknown #"):
            label = f"Unknown #{str(profile_id)[:8]}"

        supabase.table("unknown_face_profiles").update({
            "centroid_embedding": new_centroid,
            "sighting_count": new_count,
            "last_seen_at": _utc_now_iso(),
            "display_label": label,
        }).eq("id", profile_id).execute()

        supabase.table("unknown_face_sightings").insert({
            "unknown_face_profile_id": profile_id,
            "event_face_id": event_face_id,
            "camera_event_id": camera_event_id,
            "match_distance": round(best_dist, 4),
        }).execute()

        supabase.table("event_faces").update({
            "unknown_profile_id": profile_id,
        }).eq("id", event_face_id).execute()

        return {
            "profile_id": profile_id,
            "sighting_count": new_count,
            "match_distance": best_dist,
            "created": False,
        }

    # New profile
    insert_row = {
        "display_label": "Unknown visitor",
        "sighting_count": 1,
        "centroid_embedding": embedding,
        "representative_snapshot_path": snapshot_path,
        "status": "active",
    }
    created = supabase.table("unknown_face_profiles").insert(insert_row).execute()
    profile_id = created.data[0]["id"]
    short = str(profile_id).split("-")[0]
    label = f"Unknown #{short}"
    supabase.table("unknown_face_profiles").update({
        "display_label": label,
    }).eq("id", profile_id).execute()
    supabase.table("unknown_face_sightings").insert({
        "unknown_face_profile_id": profile_id,
        "event_face_id": event_face_id,
        "camera_event_id": camera_event_id,
        "match_distance": None,
    }).execute()
    supabase.table("event_faces").update({
        "unknown_profile_id": profile_id,
    }).eq("id", event_face_id).execute()

    return {
        "profile_id": profile_id,
        "sighting_count": 1,
        "match_distance": None,
        "created": True,
    }
