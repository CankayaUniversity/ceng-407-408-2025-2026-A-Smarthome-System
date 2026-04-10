import cv2
import numpy as np
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

    def get_embedding_from_crop(self, crop_bgr: np.ndarray, padding: int = 20) -> list | None:
        """
        MediaPipe bbox ile kesilmiş crop görüntüsünden embedding çıkarır.
        Crop'un tamamını yüz lokasyonu olarak verir; tekrar detection yapmaz.
        Başarısızsa None döner.
        """
        if crop_bgr is None or crop_bgr.size == 0:
            return None

        h, w = crop_bgr.shape[:2]
        if h < 20 or w < 20:
            return None

        crop_rgb = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2RGB)

        # Padding ekle — crop kenarlarında kayıp bilgiyi telafi eder
        padded = cv2.copyMakeBorder(
            crop_rgb, padding, padding, padding, padding,
            cv2.BORDER_REPLICATE,
        )

        ph, pw = padded.shape[:2]
        # Tüm padded görüntüyü tek yüz lokasyonu olarak ver
        # face_recognition formatı: (top, right, bottom, left)
        face_location = [(padding, pw - padding, ph - padding, padding)]

        encodings = face_recognition.face_encodings(padded, known_face_locations=face_location)

        if len(encodings) == 0:
            return None

        return encodings[0].tolist()