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


def _next_visitor_label(supabase) -> str:
    """Allocate Visitor 1, Visitor 2, … (skip custom admin labels)."""
    import re

    rows = (
        supabase.table("unknown_face_profiles")
        .select("display_label")
        .execute()
        .data
        or []
    )
    max_n = 0
    for row in rows:
        label = (row.get("display_label") or "").strip()
        m = re.match(r"^Visitor\s+(\d+)$", label, re.IGNORECASE)
        if m:
            max_n = max(max_n, int(m.group(1)))
    return f"Visitor {max_n + 1}"


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
        supabase.table("unknown_face_profiles").update({
            "centroid_embedding": new_centroid,
            "sighting_count": new_count,
            "last_seen_at": _utc_now_iso(),
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
    label = _next_visitor_label(supabase)
    insert_row = {
        "display_label": label,
        "sighting_count": 1,
        "centroid_embedding": embedding,
        "representative_snapshot_path": snapshot_path,
        "status": "active",
    }
    created = supabase.table("unknown_face_profiles").insert(insert_row).execute()
    profile_id = created.data[0]["id"]
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


def run_unknown_clustering_backfill(
    supabase,
    *,
    snapshot_bucket: str,
    limit: int = 50,
) -> dict[str, Any]:
    """
    Cluster existing unknown event_faces that have no unknown_profile_id yet
    (e.g. uploaded before gateway had clustering). Downloads each snapshot,
    computes embedding, merges into profiles — same logic as live upload.
    """
    from app.vision.embedder import FaceEmbedder

    summary: dict[str, Any] = {
        "candidates": 0,
        "clustered_ok": 0,
        "skipped_no_snapshot": 0,
        "failed_download": 0,
        "failed_cluster": 0,
        "profiles_created": 0,
        "profiles_merged": 0,
    }

    rows = (
        supabase.table("event_faces")
        .select("id, camera_event_id, camera_events(snapshot_path, created_at)")
        .eq("classification", "unknown")
        .is_("unknown_profile_id", "null")
        .limit(max(1, min(limit, 200)))
        .execute()
        .data
        or []
    )

    def _sort_key(row: dict) -> str:
        cam = row.get("camera_events") or {}
        return cam.get("created_at") or ""

    rows.sort(key=_sort_key)
    summary["candidates"] = len(rows)

    embedder = FaceEmbedder()

    for row in rows:
        face_id = row["id"]
        cam = row.get("camera_events") or {}
        snapshot_path = cam.get("snapshot_path")
        camera_event_id = row.get("camera_event_id")

        if not snapshot_path or not camera_event_id:
            summary["skipped_no_snapshot"] += 1
            continue

        try:
            file_bytes = supabase.storage.from_(snapshot_bucket).download(snapshot_path)
        except Exception as exc:
            summary["failed_download"] += 1
            logger.warning("Backfill download failed (%s): %s", snapshot_path, exc)
            continue

        result = cluster_unknown_detection(
            supabase,
            embedder,
            file_bytes,
            face_id,
            camera_event_id,
            snapshot_path,
        )
        if not result:
            summary["failed_cluster"] += 1
            continue

        summary["clustered_ok"] += 1
        if result.get("created"):
            summary["profiles_created"] += 1
        else:
            summary["profiles_merged"] += 1

    logger.info("Unknown clustering backfill: %s", summary)
    return summary
