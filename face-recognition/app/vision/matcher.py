import json
import logging
from pathlib import Path
from typing import Optional
import math

from app.config import RESIDENTS_FILE, FACE_MATCH_THRESHOLD, FACE_MATCH_MIN_MARGIN

logger = logging.getLogger(__name__)


class FaceMatcher:
    def __init__(
        self,
        threshold: float = FACE_MATCH_THRESHOLD,
        min_margin: float = FACE_MATCH_MIN_MARGIN,
    ):
        self.threshold = threshold
        self.min_margin = min_margin

    def load_residents(self) -> dict:
        if not RESIDENTS_FILE.exists():
            return {"residents": []}

        with open(RESIDENTS_FILE, "r", encoding="utf-8") as file:
            return json.load(file)

    def euclidean_distance(self, emb1: list, emb2: list) -> float:
        if len(emb1) != len(emb2):
            raise ValueError("Embedding lengths do not match.")

        return math.sqrt(sum((a - b) ** 2 for a, b in zip(emb1, emb2)))

    def _rank_matches(self, query_embedding: list) -> list[dict]:
        """One entry per resident (best sample distance), sorted ascending."""
        data = self.load_residents()
        best_per_resident: dict[str, dict] = {}

        for resident in data.get("residents", []):
            if not resident.get("is_active", True):
                continue

            person_id = resident.get("person_id")
            for sample in resident.get("samples", []):
                stored_embedding = sample.get("embedding")
                if not stored_embedding:
                    continue

                distance = self.euclidean_distance(query_embedding, stored_embedding)
                entry = {
                    "person_id": person_id,
                    "name": resident.get("name"),
                    "distance": distance,
                }
                prev = best_per_resident.get(person_id)
                if prev is None or distance < prev["distance"]:
                    best_per_resident[person_id] = entry

        ranked = list(best_per_resident.values())
        ranked.sort(key=lambda m: m["distance"])
        return ranked

    def find_best_match(self, query_embedding: list) -> dict:
        ranked = self._rank_matches(query_embedding)

        if not ranked:
            return {
                "matched": False,
                "person_id": None,
                "name": None,
                "score": None,
                "status": "unauthorized",
            }

        best = ranked[0]
        best_distance = best["distance"]
        second_distance = ranked[1]["distance"] if len(ranked) > 1 else float("inf")
        margin = second_distance - best_distance

        score = round(best_distance, 4)

        if best_distance > self.threshold:
            return {
                "matched": False,
                "person_id": None,
                "name": None,
                "score": score,
                "status": "unauthorized",
            }

        if margin < self.min_margin:
            runner_up = ranked[1]["name"] if len(ranked) > 1 else "?"
            logger.warning(
                "Ambiguous face match: best=%s (%.4f) vs runner-up=%s (%.4f), margin=%.4f < %.4f — treating as unknown",
                best["name"],
                best_distance,
                runner_up,
                second_distance if second_distance != float("inf") else -1,
                margin,
                self.min_margin,
            )
            return {
                "matched": False,
                "person_id": None,
                "name": None,
                "score": score,
                "status": "unauthorized",
                "ambiguous": True,
                "runner_up_name": runner_up if len(ranked) > 1 else None,
                "runner_up_score": round(second_distance, 4) if len(ranked) > 1 else None,
            }

        return {
            "matched": True,
            "person_id": best["person_id"],
            "name": best["name"],
            "score": score,
            "status": "authorized",
        }
