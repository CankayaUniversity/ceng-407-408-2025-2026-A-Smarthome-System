from picamera2 import Picamera2
from datetime import datetime

picam2 = Picamera2()
picam2.start()

filename = f"test_{datetime.now().strftime('%H%M%S')}.jpg"

picam2.capture_file(filename)

print("Image captured:", filename)

picam2.stop()