import cv2
import mediapipe as mp
import numpy as np


class FaceDetector:
    def __init__(self, min_detection_confidence: float = 0.5):
        self.mp_face_detection = mp.solutions.face_detection
        self.detector = self.mp_face_detection.FaceDetection(
            model_selection=0,
            min_detection_confidence=min_detection_confidence,
        )

    def _extract_faces_from_results(self, results, image_shape) -> list:
        if not results.detections:
            return []

        h, w, _ = image_shape
        faces = []

        for detection in results.detections:
            bbox = detection.location_data.relative_bounding_box

            x = max(0, int(bbox.xmin * w))
            y = max(0, int(bbox.ymin * h))
            width = int(bbox.width * w)
            height = int(bbox.height * h)

            faces.append([x, y, width, height])

        return faces

    def _preprocess_for_detection(self, image):
        lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)

        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        l_enhanced = clahe.apply(l)

        enhanced_lab = cv2.merge((l_enhanced, a, b))
        enhanced_bgr = cv2.cvtColor(enhanced_lab, cv2.COLOR_LAB2BGR)

        sharpen_kernel = np.array([
            [0, -1, 0],
            [-1, 5, -1],
            [0, -1, 0]
        ])
        sharpened = cv2.filter2D(enhanced_bgr, -1, sharpen_kernel)

        return sharpened

    def detect_faces(self, image_path: str) -> list:
        image = cv2.imread(image_path)

        if image is None:
            raise ValueError(f"Could not read image: {image_path}")

        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = self.detector.process(image_rgb)
        faces = self._extract_faces_from_results(results, image.shape)

        if faces:
            return faces

        enhanced_image = self._preprocess_for_detection(image)
        enhanced_rgb = cv2.cvtColor(enhanced_image, cv2.COLOR_BGR2RGB)
        enhanced_results = self.detector.process(enhanced_rgb)
        enhanced_faces = self._extract_faces_from_results(
            enhanced_results,
            enhanced_image.shape
        )

        return enhanced_faces