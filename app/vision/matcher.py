import json
from pathlib import Path
from typing import Optional
import math


RESIDENTS_FILE = Path("app/storage/residents.json")


class FaceMatcher:
    def __init__(self, threshold: float = 0.55):
        self.threshold = threshold

    def load_residents(self) -> dict:
        if not RESIDENTS_FILE.exists():
            return {"residents": []}

        with open(RESIDENTS_FILE, "r", encoding="utf-8") as file:
            return json.load(file)

    def euclidean_distance(self, emb1: list, emb2: list) -> float:
        if len(emb1) != len(emb2):
            raise ValueError("Embedding lengths do not match.")

        return math.sqrt(sum((a - b) ** 2 for a, b in zip(emb1, emb2)))

    def find_best_match(self, query_embedding: list) -> dict:
        data = self.load_residents()

        best_match: Optional[dict] = None
        best_distance = float("inf")

        for resident in data.get("residents", []):
            if not resident.get("is_active", True):
                continue

            for sample in resident.get("samples", []):
                stored_embedding = sample.get("embedding")
                if not stored_embedding:
                    continue

                distance = self.euclidean_distance(query_embedding, stored_embedding)

                if distance < best_distance:
                    best_distance = distance
                    best_match = {
                        "person_id": resident.get("person_id"),
                        "name": resident.get("name"),
                        "distance": distance
                    }

        if best_match and best_distance <= self.threshold:
            return {
                "matched": True,
                "person_id": best_match["person_id"],
                "name": best_match["name"],
                "score": round(best_distance, 4),
                "status": "authorized"
            }

        return {
            "matched": False,
            "person_id": None,
            "name": None,
            "score": round(best_distance, 4) if best_distance != float("inf") else None,
            "status": "unauthorized"
        }