from app.vision.embedder import FaceEmbedder


def main():
    image_path = "data/sample_images/test.jpg"

    embedder = FaceEmbedder()

    try:
        embedding = embedder.get_embedding(image_path)

        print("Embedding başarıyla çıkarıldı.")
        print("Embedding uzunluğu:", len(embedding))
        print("İlk 5 değer:", embedding[:5])

    except Exception as e:
        print("Hata:", str(e))


if __name__ == "__main__":
    main()