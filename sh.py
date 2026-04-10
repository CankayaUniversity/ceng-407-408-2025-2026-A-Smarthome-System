import os
# VNC ekranında kameranın açılmasını sağlar
os.environ["DISPLAY"] = ":0"

import cv2
import time
import threading
import board
import adafruit_dht
from pathlib import Path
from gpiozero import DigitalInputDevice
from picamera2 import Picamera2

# --- ARKADAŞININ YÜZ TANIMA VE LOGLAMA SİSTEMİ İÇE AKTARILIYOR ---
from app.vision.face_detector import FaceDetector
from app.vision.embedder import FaceEmbedder
from app.vision.matcher import FaceMatcher
from app.logging_system.event_logger import EventLogger

# --- GLOBAL DEĞİŞKENLER ---
current_temp = "WAITING..."
current_hum = "WAITING..."
current_gas = "NO GAS"
current_motion = "None"
current_soil = "WET"
dht_log = "Initializing..."

is_motion_active = False
motion_last_detected_time = 0
last_face_capture_time = 0
MOTION_COOLDOWN_SECONDS = 5  # Arkadaşının sistemindeki bekleme süresi

# Fotoğrafların kaydedileceği klasör
CAPTURE_DIR = Path("data/captures")
CAPTURE_DIR.mkdir(parents=True, exist_ok=True)

# --- SENSÖR PİN AYARLARI ---
mq2_sensor = DigitalInputDevice(17, pull_up=False) # Gaz sensörü
pir_sensor = DigitalInputDevice(27, pull_up=False) # Hareket sensörü
soil_sensor = DigitalInputDevice(22)               # Toprak nemi

# DHT11 Sıcaklık ve Nem Sensörü
dht_device = adafruit_dht.DHT11(board.D4, use_pulseio=False)

# --- YÜZ TANIMA MODÜLLERİNİ BAŞLATMA ---
try:
    print("[INFO] Yüz Tanıma Modülleri Yükleniyor...")
    face_detector = FaceDetector()
    face_embedder = FaceEmbedder()
    face_matcher = FaceMatcher()
    event_logger = EventLogger()
    print("[INFO] Modüller Başarıyla Yüklendi.")
except Exception as e:
    print(f"[ERROR] Modüller yüklenirken hata oluştu: {e}")

def process_face_pipeline(image_path):
    """Kamerayı dondurmamak için arka planda (Thread) çalışan yüz tanıma fonksiyonu."""
    print(f"[VISION] Fotoğraf analiz ediliyor: {image_path}")
    
    try:
        faces = face_detector.detect_faces(image_path)
        face_count = len(faces)
        
        if face_count == 0:
            print("[VISION] Yüz bulunamadı.")
            event_logger.log_event(
                event_type="motion",
                image_path=image_path,
                face_detected=False,
                face_count=0,
                recognized_name=None,
                person_id=None,
                match_score=None,
                status="no_face"
            )
            return

        print(f"[VISION] {face_count} yüz bulundu. Kimlik tespiti yapılıyor...")
        embedding = face_embedder.get_embedding(image_path)
        result = face_matcher.find_best_match(embedding)
        
        print(f"[VISION] Eşleşme Sonucu: {result}")
        
        # Arkadaşının orijinal JSON log sistemine kaydet
        event_logger.log_event(
            event_type="motion",
            image_path=image_path,
            face_detected=True,
            face_count=face_count,
            recognized_name=result.get("name"),
            person_id=result.get("person_id"),
            match_score=result.get("score"),
            status=result.get("status")
        )
            
    except Exception as error:
        print(f"[VISION ERROR] Yüz tanıma sırasında hata: {error}")

def read_dht11():
    """DHT11 Sensörünü okur ve hataları yakalar."""
    global current_temp, current_hum, dht_log, dht_device
    while True:
        try:
            t = dht_device.temperature
            h = dht_device.humidity
            if t is not None and h is not None:
                current_temp = f"{t:.1f}C"
                current_hum = f"{h:.1f}%"
                dht_log = "READING_OK"
        except RuntimeError as error:
            dht_log = f"HARDWARE_ERROR: {error.args[0]}"
            time.sleep(2.0)
            continue
        except Exception as error:
            dht_log = f"CRITICAL_ERROR: {error}"
            dht_device.exit()
            try:
                dht_device = adafruit_dht.DHT11(board.D4, use_pulseio=False)
            except:
                pass
        time.sleep(2.0)

def read_digital_sensors():
    """Dijital sensörleri okur ve terminale bilgi basar."""
    global current_gas, current_motion, current_soil
    global is_motion_active, motion_last_detected_time
    
    while True:
        # Yeşil ışık yandığında 0 döner
        gas_detected = (mq2_sensor.value == 0)
        soil_dry = soil_sensor.value 
        
        # Hareket algılama ve 3 saniye kuralı
        if pir_sensor.value == 1:
            motion_last_detected_time = time.time()
            is_motion_active = True
            current_motion = "DETECTED"
        else:
            if time.time() - motion_last_detected_time > 3.0:
                is_motion_active = False
                current_motion = "None"
        
        current_gas = "ALERT" if gas_detected else "NO GAS"
        current_soil = "DRY" if soil_dry else "WET"
        
        print(f"[STATUS] Temp: {current_temp} | Hum: {current_hum} | Gas: {current_gas} | Motion: {current_motion} | Soil: {current_soil} | DHT_LOG: {dht_log}")
        time.sleep(1.0) 

def main():
    global last_face_capture_time
    print("Initializing CENG 407 Smart Home & Vision Core System...")
    
    # Sensör okuma işlemlerini arka planda (Thread) başlat
    threading.Thread(target=read_dht11, daemon=True).start()
    threading.Thread(target=read_digital_sensors, daemon=True).start()
    
    # Kamerayı başlat
    try:
        picam2 = Picamera2()
        config = picam2.create_preview_configuration(main={"size": (1280, 720)})
        picam2.configure(config)
        picam2.start()
    except Exception as e:
        print(f"[ERROR] Kamera başlatılamadı: {e}")
        return

    window_open = False

    while True:
        try:
            # Görüntüyü ve yüz tanımayı SADECE HAREKET VARSA aktifleştir
            if is_motion_active:
                frame = picam2.capture_array()
                frame_bgr = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
                
                # Ekrana sensör verilerini (OSD) yazdır
                cv2.putText(frame_bgr, f"Temp: {current_temp} Hum: {current_hum}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
                cv2.putText(frame_bgr, f"Gas: {current_gas}", (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255) if current_gas == "ALERT" else (0, 255, 0), 2)
                cv2.putText(frame_bgr, f"Motion: {current_motion}", (10, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                cv2.putText(frame_bgr, f"Soil: {current_soil}", (10, 120), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 165, 255) if current_soil == "DRY" else (255, 0, 0), 2)
                
                cv2.imshow("Smart Home Live Feed", frame_bgr)
                window_open = True
                
                # --- ASENKRON YÜZ TANIMA TETİKLEYİCİSİ ---
                current_time = time.time()
                # Eğer son fotoğrafın üzerinden 5 saniye (Cooldown) geçtiyse yeni fotoğraf çek
                if current_time - last_face_capture_time > MOTION_COOLDOWN_SECONDS:
                    last_face_capture_time = current_time
                    timestamp = int(current_time)
                    image_path = str(CAPTURE_DIR / f"motion_{timestamp}.jpg")
                    
                    # Fotoğrafı diske kaydet (Arkadaşının kodunun okuyabilmesi için)
                    cv2.imwrite(image_path, frame_bgr)
                    
                    # Yüz tanıma işlemini kamerayı dondurmamak için arka plana (Thread) yolla
                    threading.Thread(target=process_face_pipeline, args=(image_path,), daemon=True).start()

                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break
            else:
                # Hareket bittiğinde 3 saniye geçince pencereyi kapat
                if window_open:
                    cv2.destroyAllWindows()
                    window_open = False
                time.sleep(0.1)
                
        except Exception as e:
            print(f"[ERROR] GUI/Video hatası: {e}")
            break
            
    picam2.stop()
    cv2.destroyAllWindows()
    print("Sistem güvenli bir şekilde kapatıldı.")

if __name__ == '__main__':
    main()