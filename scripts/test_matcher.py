import argparse

from app.vision.embedder import FaceEmbedder
from app.vision.matcher import FaceMatcher


def main():
    parser = argparse.ArgumentParser(description="Test face matching against registered residents.")
    parser.add_argument("--image", required=True, help="Path to test image")
    args = parser.parse_args()

    embedder = FaceEmbedder()
    matcher = FaceMatcher(threshold=0.55)

    try:
        embedding = embedder.get_embedding(args.image)
        result = matcher.find_best_match(embedding)

        print("Match result:")
        print(result)

    except Exception as error:
        print(f"Hata: {error}")


if __name__ == "__main__":
    main()