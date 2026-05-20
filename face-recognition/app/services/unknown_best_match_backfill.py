"""
Backfill event_faces.best_match_resident_id for unknown rows created before
the gateway stored candidate_person_id on upload.
"""

from __future__ import annotations

import logging
import os
import tempfile
from typing import Any

logger = logging.getLogger(__name__)


def run_unknown_best_match_backfill(
    supabase,
    *,
    snapshot_bucket: str,
    limit: int = 50,
) -> dict[str, Any]:
    from app.vision.embedder import FaceEmbedder
    from app.vision.matcher import FaceMatcher

    summary: dict[str, Any] = {
        "candidates": 0,
        "updated_ok": 0,
        "skipped_no_snapshot": 0,
        "failed_download": 0,
        "failed_match": 0,
        "no_candidate": 0,
    }

    rows = (
        supabase.table("event_faces")
        .select("id, match_score, camera_event_id, camera_events(snapshot_path)")
        .eq("classification", "unknown")
        .is_("best_match_resident_id", "null")
        .limit(max(1, min(limit, 200)))
        .execute()
        .data
        or []
    )

    summary["candidates"] = len(rows)
    if not rows:
        return summary

    embedder = FaceEmbedder()
    matcher = FaceMatcher()

    for row in rows:
        cam = row.get("camera_events") or {}
        snapshot_path = cam.get("snapshot_path")
        if not snapshot_path:
            summary["skipped_no_snapshot"] += 1
            continue

        try:
            file_bytes = supabase.storage.from_(snapshot_bucket).download(snapshot_path)
        except Exception as exc:
            summary["failed_download"] += 1
            logger.warning("Best-match backfill download failed (%s): %s", snapshot_path, exc)
            continue

        tmp_path = None
        try:
            with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
                tmp.write(file_bytes)
                tmp_path = tmp.name

            embedding = embedder.get_embedding(tmp_path)
            if not embedding:
                summary["failed_match"] += 1
                continue

            result = matcher.find_best_match(embedding)
            candidate_id = result.get("candidate_person_id")
            if not candidate_id:
                summary["no_candidate"] += 1
                continue

            payload: dict[str, Any] = {"best_match_resident_id": candidate_id}
            score = result.get("score")
            if score is not None and row.get("match_score") is None:
                payload["match_score"] = score

            supabase.table("event_faces").update(payload).eq("id", row["id"]).execute()
            summary["updated_ok"] += 1
        except Exception as exc:
            summary["failed_match"] += 1
            logger.warning("Best-match backfill failed for %s: %s", row.get("id"), exc)
        finally:
            if tmp_path and os.path.exists(tmp_path):
                try:
                    os.remove(tmp_path)
                except OSError:
                    pass

    logger.info("Unknown best-match backfill: %s", summary)
    return summary
