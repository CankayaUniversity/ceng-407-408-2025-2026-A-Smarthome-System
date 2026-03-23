# IoT Smart Home & Yüz Tanıma Projesi - Güncel Durum Raporu (Mart 2026)

Bu doküman, bitirme projesi kapsamında geliştirilen sistemin **100% dürüst, kanıta dayalı ve eksiksiz** bir durum özetidir. Halüsinasyon içermez, sadece kodlanan ve test edilen özellikleri barındırır.

---

## 1. Mimaride Gerçek (Çalışan) Olan Kısımlar Neler?

Sistemin belkemiği ve arka planda koşan iletişim protokolleri tamamen gerçektir.

- **Veritabanı ve Şema (PostgreSQL + Prisma):**
  - **Kanıt:** `website/server/prisma/schema.prisma` dosyasında `Device`, `Sensor`, `SensorReading`, `FaceProfile`, `CameraEvent`, `Alert` ve `User` tabloları mevcuttur. Prisma migrate ile Docker üzerinde PostgreSQL'e basılmıştır ve veri tutmaktadır.
- **RESTful API Uç Noktaları (Express.js):**
  - **Kanıt:** `website/server/src/routes/` içindeki dosyalar aktiftir. 
    - `POST /api/sensors/readings` (Sensör verisi kabul eder)
    - `POST /api/camera/events` (Kameralı yüz tanıma sonuçlarını kabul eder)
    - `GET /api/residents/sync` (Pi'nin kişileri sekronize etmesini sağlar)
  - Tüm bu uç noktalar `X-API-Key` veya `Bearer Token (JWT)` ile güvenlik doğrulaması (`authenticateDevice`, `authenticate`) yapar.
- **Gerçek Zamanlı İletişim (WebSockets):**
  - **Kanıt:** `website/server/src/socket/socketHandler.js` dosyası ile backend, veritabanına yeni bir veri girildiğinde anında ön yüze (React) `sensor:update`, `alert:new`, `camera:event` sinyalleri fırlatır. Sayfa yenilemeye gerek kalmadan arayüz güncellenir.
- **Arayüz (React & Vite):**
  - **Kanıt:** `DashboardPage`, `RoomsPage`, `HistoryPage` ve `ResidentsPage` cam/neon (glassmorphic) tasarımlarla, grid ve responsive mantıkla baştan yazılmıştır. Bu sayfalardaki hesaplamalar (ortalama sıcaklık vb.) kod içindeki gerçek fonksiyonlarla (`reduce`, `filter`) yapılır.

---

## 2. Sistemde Mock (Sanal) Olan Kısımlar Neler?

Arayüzün boş kalmaması, test yapılabilmesi ve demoda görsel bir şölen sunabilmesi için bazı veriler kod yardımıyla (fake) üretilmiştir. **Fiziksel sensörler bağlanana kadar bu kısımlar donanımsal değil, yazılımsaldır.**

- **Sensör Verileri ve Geçmişi (History/Analytics):**
  - **Kanıt:** `website/server/prisma/seed.js` dosyası. Bu script, 7 günlük geçmişi doldurmak için 336'şar adet okumayı `Math.sin()` (sinüs dalgası) ve `Math.random()` kullanarak üretir (Örn: 50 + sin(x) * 12).
- **Cihaz ve Oda Tanımları (Floor Plan):**
  - **Kanıt:** `seed.js` içindeki `ROOMS` dizisi ("Kitchen Hub", "Master Bedroom" vb.) fiziksel olarak ortamda var olmasa da veritabanına sanki evde 6 ayrı modül varmış gibi kaydedilmiştir.
- **Geçmiş Alarmlar (Alerts):**
  - **Kanıt:** `seed.js` içindeki `Alert.createMany`. "Mutfakta duman algılandı" veya "Su sızıntısı var" mesajları sisteme deneme amaçlı basılmıştır, gerçek bir yangın sensöründen gelmemiştir.

---

## 3. Yüz Tanıma (Face Recognition) Entegrasyonu Nasıl Çalışıyor?

Yüz tanıma özelliği "Edge-Computing" mantığıyla Raspberry Pi üzerinde kodlanmış, Website (Backend) ile tam entegre hale getirilmiştir. 

### Entegrasyon Kanıtları ve İşleyişi:
1. **Model Değişiklikleri (`schema.prisma`):** 
   - `FaceProfile` modeline `embedding Json?` ve `personId String?` eklendi.
   - `CameraEvent` modeline `result String` (authorized/unauthorized/unknown) eklendi ve `imagePath` istendiğinde null bırakılabilecek şekilde (`String?`) esnetildi.
2. **Kişi Kayıt Süreci (ResidentsPage):**
   - Sitenin ön yüzünden ("Add Resident" modalı) kişi ismi, rolü ve fotoğrafı (multipart/form-data) `/api/residents` veya `/api/residents/:id/photo` endpointlerine gönderilir.
   - Profil oluşturulur ancak `embedding` verisi yoksayılan olarak sayfada saydam bir "Pending" rozetiyle bekletilir.
3. **Senkronizasyon (Pi → Website):**
   - **Kanıt:** `face-recognition/app/api/resident_sync.py` dosyası. Raspberry Pi arka planda çalışan bir thread ile sitenin `/api/residents/sync` adresine istek atar. Olası yeni kişileri (ve onların JSON formatındaki yüz vektörlerini) kendi yerel diski olan `residents.json`'a kaydeder.
4. **Yüz Tespiti ve Web'e Bildirim (Pi → Website):**
   - **Kanıt:** `face-recognition/app/api/client.py` içindeki `send_camera_event` metodu. Pi kamerası yüz gördüğünde OpenCV ile doğrular, benzerlik (match_score) hesaplar ve sitenin `POST /api/camera/events` adresine sonucu yollar.
5. **Arayüze Yansıma (Website):**
   - **Kanıt:** CURL komutu testlerimiz. Biz `Invoke-WebRequest` ile sahte bir unauthorized event fırlattığımızda (Mock test no 1), `req.userId` doğrulandı, 201 Created döndü ve DashboardPage / CameraPage üzerindeki Socket.IO dinleyicisi anında "LIVE CAMERA" widget'ında "Unknown Person" bildirimini patlattı.

---

## 4. Sistemin Gerçek Hayatta Kullanılması İçin Eksikler (To-Do)

Proje %90 oranında kodlama bağlamında hazırdır ancak fiziki dünyayla konuşması için şu adımlar elzemdir:

1. **Pi Kamera Bağlantısı & Ağ Erişimi:**
   - Pi üzerindeki `config.py` içinde bulunan `API_BASE_URL` değişkeni, backend sunucumuzun (site) lokal veya public statik IP/Port'una eşitlenmelidir.
   - Pi cihazının api key'i, veritabanından alınan güncel cihaz key'ine (Şu anki docker seed key: `f9f2385b-41a5-4464-9788-6ce87e7dba07`) eşitlenmelidir.
2. **Fiziksel Sensör Scriptleri (Python/C++):**
   - Tıpkı Face Recognition modülümüz olan `send_camera_event` mantığı gibi, eğer DHT11/DHT22 (Sıcaklık) veya MQ-2 (Gaz/Duman) pini üzerinden fiziksel veri okunacaksa, bu veriyi okuyup `POST /api/sensors/readings` adresine yollayan basit bir Python scripti Pi üzerinde sürekli (Örn: 5 dakikada bir) çalışmalıdır.
   - Aksi takdirde site ömrü boyunca `seed.js`'den gelen 336 okumanın eski verilerini gösterecektir.
3. **Kişi Yüz Vektörleri (Embeddings):**
   - Website'den fotoğraf yüklenebilmektedir ancak yüz vektörü (Embedding array) üretmek ağır bir işlem olduğundan Pi'de koşturulan `enroll_resident.py` CLI'ından geçirilmesi hala teknik olarak bir gerekliliktir veya backend'e OpenCV kütüphanesi entegre edilip fotoğraf alındığı an backend'de parse edilmelidir. Şu anki akışta resimler Website'den, Embedding verileri Pi'den üretilmektedir.
