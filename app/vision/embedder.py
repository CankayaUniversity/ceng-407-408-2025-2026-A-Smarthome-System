import face_recognition


class FaceEmbedder:
    def __init__(self):
        pass

    def get_embedding(self, image_path: str) -> list:
        """
        Verilen görüntüden yüz embedding çıkarır.
        """

        # resmi yükle
        image = face_recognition.load_image_file(image_path)

        # yüzleri bul
        face_locations = face_recognition.face_locations(image)

        if len(face_locations) == 0:
            raise ValueError("No face found in image.")

        if len(face_locations) > 1:
            print("Warning: Multiple faces detected. Using the first one.")

        # embedding çıkar
        encodings = face_recognition.face_encodings(image, face_locations)

        if len(encodings) == 0:
            raise ValueError("Failed to extract embedding.")

        embedding = encodings[0]

        return embedding.tolist()