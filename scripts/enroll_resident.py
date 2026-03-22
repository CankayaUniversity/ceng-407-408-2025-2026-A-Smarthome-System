import argparse
import json
from datetime import datetime
from pathlib import Path
import uuid

from app.vision.embedder import FaceEmbedder


RESIDENTS_FILE = Path("app/storage/residents.json")


def load_residents():
    if not RESIDENTS_FILE.exists():
        return {"residents": []}

    with open(RESIDENTS_FILE, "r", encoding="utf-8") as file:
        return json.load(file)


def save_residents(data):
    RESIDENTS_FILE.parent.mkdir(parents=True, exist_ok=True)

    with open(RESIDENTS_FILE, "w", encoding="utf-8") as file:
        json.dump(data, file, indent=2, ensure_ascii=False)


def find_resident_by_name(data, name):
    for resident in data["residents"]:
        if resident["name"].strip().lower() == name.strip().lower():
            return resident
    return None


def enroll_resident(name: str, image_path: str):
    image_file = Path(image_path)

    if not image_file.exists():
        raise FileNotFoundError(f"Image not found: {image_path}")

    embedder = FaceEmbedder()
    embedding = embedder.get_embedding(str(image_file))

    data = load_residents()
    existing_resident = find_resident_by_name(data, name)

    sample_data = {
        "image_path": str(image_file).replace("\\", "/"),
        "embedding": embedding
    }

    if existing_resident:
        existing_resident["samples"].append(sample_data)
        print(f"Yeni örnek eklendi: {name}")
    else:
        new_resident = {
            "person_id": f"res_{uuid.uuid4().hex[:8]}",
            "name": name,
            "is_active": True,
            "created_at": datetime.now().isoformat(),
            "samples": [sample_data]
        }
        data["residents"].append(new_resident)
        print(f"Yeni resident eklendi: {name}")

    save_residents(data)
    print("Kayıt başarıyla tamamlandı.")


def main():
    parser = argparse.ArgumentParser(description="Register a resident with face embedding.")
    parser.add_argument("--name", required=True, help="Resident name")
    parser.add_argument("--image", required=True, help="Path to resident image")

    args = parser.parse_args()

    try:
        enroll_resident(args.name, args.image)
    except Exception as error:
        print(f"Hata: {error}")


if __name__ == "__main__":
    main()