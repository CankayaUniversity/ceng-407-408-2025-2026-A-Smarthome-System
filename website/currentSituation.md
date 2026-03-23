# currentSituation.md — IoT Akıllı Ev Sistemi Dürüst Durum Analizi

> Tarih: 2026-03-11 · Karşılaştırma kaynağı: `implementation_plan.md`

---

## Bölüm 1 — Teknoloji Yığını (Gerçek Durum)

| Katman | Teknoloji | Açıklama |
|---|---|---|
| **Frontend dili** | JavaScript (JSX) | React 19 + Vite. TypeScript kullanılmıyor — tip güvencesi yok |
| **Backend dili** | JavaScript (ESM) | Node.js 18 + Express.js. Yine TypeScript yok |
| **Veritabanı** | **PostgreSQL** | Prisma ORM üzerinden, Docker container içinde çalışıyor |
| **ORM** | Prisma | Schema-first, migration destekli. Üretimde de çalışır |
| **Auth** | JWT (jsonwebtoken) + bcrypt | Token süresi 7 gün sabit kodlanmış, refresh token yok |
| **Real-time** | Socket.IO | Bağlı, olaylar yayılıyor (`sensor:update`, `alert:new`, `camera:event`) |
| **Dosya yükleme** | Multer | Yüz fotoğrafı + kamera event image upload — lokal disk'e kaydediyor |
| **Docker** | Docker Compose | 3 container: `smarthome_db` (PostgreSQL), `smarthome_backend` (Node), `smarthome_frontend` (Nginx) |
| **Nginx** | Static file serving | Frontend build'i sunar, SPA yönlendirme (`try_files`) yapılandırıldı |
| **CSS** | Vanilla CSS (Design System) | "Living Carbon" dark tema, CSS variables tabanlı |

### Docker Ne İçin Kullanılıyor?

```
docker-compose up -d
├── smarthome_db       → PostgreSQL 15 veritabanı (port 5432)
├── smarthome_backend  → Express API (port 3001, dışa 3001)
└── smarthome_frontend → Nginx ile React build (port 80)
```

Amacı: Tek komutla tüm ortamı ayağa kaldırmak. Geliştirici ortam kurulumu gerektirmiyor.

---

## Bölüm 2 — Gerçek mi, Mock mu?

### ✅ GERÇEKTEN ÇALIŞAN (Veritabanına Yazılıyor / Okunuyor)

| Özellik | Durum |
|---|---|
| Kullanıcı kaydı & giriş (JWT) | ✅ Gerçek — bcrypt hash, PostgreSQL User tablosu |
| Sensor verisi kaydetme (`POST /api/sensors/readings`) | ✅ Gerçek API — IoT cihaz X-API-Key ile bağlandığında çalışır |
| Sensor latest okuma (`GET /api/sensors/latest`) | ✅ Gerçek — DB'den çekiyor |
| Tarihsel veri (`GET /api/sensors/history`) | ✅ Gerçek — zaman aralığı filtreli, DB'den |
| Alert oluşturma (`POST /api/alerts`) | ✅ Gerçek API — device auth sonrası DB'ye kaydeder |
| Alert listeleme & acknowledge | ✅ Gerçek — filtreli, sayfalı |
| Resident ekleme / silme | ✅ Gerçek — FormData ile multer, DB'ye kaydeder |
| Camera event kaydetme (`POST /api/camera/events`) | ✅ API hazır — device'dan image + result bekliyor |
| Camera events listeleme | ✅ Gerçek |
| WebSocket real-time | ✅ Gerçek — Socket.IO çalışıyor, sensor/alert event'leri yayılıyor |

### ⚠️ MOCK DATA (Seed Scriptten Geliyor — Gerçek Donanım Bağlı Değil)

| Özellik | Gerçek Durum |
|---|---|
| Dashboard'daki tüm sensor değerleri | **MOCK** — `prisma/seed.js` ile 7 günlük sahte veri üretildi |
| Floor Plan'daki sensörler | **MOCK** — seed'den gelen veriler |
| Alerts sayfasındaki uyarılar | **MOCK** — seed'de el ile yaratıldı |
| Residents (Deniz, Ayşe, Mehmet) | **MOCK** — seed'de yaratıldı, yüz fotoğrafları yok |
| Camera event log | **MOCK** — seed'de `CameraEvent` oluşturulmadı, gerçek event yok |

> [!IMPORTANT]
> **Mock verilerin tamamı `server/prisma/seed.js` dosyasındadır.** Gerçek donanım bağlandığında bu dosya çalıştırılmaz — sadece test için vardır. Tek komut: `docker exec smarthome_backend npm run db:seed`

### ❌ TAMAMEN EKSİK / ÇALIŞMIYOR

| Özellik | Durum |
|---|---|
| **Canlı kamera akışı (MJPEG)** | ❌ Yok — Frontend'de "OFFLINE" placeholder. Backend'de proxy endpoint YOK |
| **AI yüz tanıma** | ❌ Yok — `FaceProfile.imagePath` + `embedding` alanı şemada var ama hiç bir AI entegrasyonu yok |
| **Kamera event fotoğraf görüntüleme** | ❌ Camera sayfasında gerçek event fotoğrafları gösterilmiyor |
| **IoT cihaz → API bağlantısı (Raspberry Pi)** | ❌ Bağlı değil — Raspberry Pi gerçekte API'ye istek atmıyor |
| **Otomatik alert tetikleme** | ❌ Sensör threshold'u aşınca otomatik alert üretilmiyor. Alert'ler sadece IoT device `POST /api/alerts` atarsa oluşuyor |
| **Settings sayfası — kaydetme** | ❌ Toggle'lar görsel — backend'e hiçbir şey yazılmıyor |
| **Settings — cihaz yönetimi** | ❌ UI var ama CRUD çalışmıyor |
| **HistoryPage — tarih aralığı seçici** | ❌ Gerçek date range picker yok, sadece sensor seçimi var |
| **CSV export** | ❌ Planlandı ama hiç yapılmadı |
| **HTTPS / TLS** | ❌ Yok — HTTP over port 80/3001 |
| **Rate limiting** | ❌ Planlandı ama hiç implemente edilmedi |
| **Input validation (Zod/express-validator)** | ❌ Yok — req.body doğrulama minimal/yok |
| **Refresh token** | ❌ Yok — token süresi dolunca yeniden login zorunlu |
| **IoT simülatör scripti** | ❌ Planlandı ama yazılmadı |
| **Downsampling (haftalık/aylık avg)** | ❌ Yok — tüm raw veri çekiliyor, büyük veri setlerinde yavaşlar |
| **B-tree index on createdAt** | ❌ Prisma şemasında index tanımlı değil |
| **Resident fotoğraf görüntüleme** | ❌ Yüklenen görsel UI'da gösterilmiyor |
| **Push notification** | ❌ Hiç yok |

---

## Bölüm 3 — Plana Göre Durum Özeti

| Faz | Plan | Gerçek Durum |
|---|---|---|
| Faz 0 — Proje iskeleti | ✅ Planlandı | ✅ Tamamlandı |
| Faz 1 — Auth & DB schema | ✅ Planlandı | ✅ Tamamlandı (refresh token hariç) |
| Faz 2 — RESTful API | ✅ Planlandı | ✅ %80 — camera/stream endpoint eksik |
| Faz 3 — Socket.IO real-time | ✅ Planlandı | ✅ Tamamlandı |
| Faz 4 — Dashboard UI | ✅ Planlandı | ⚠️ %70 — kamera feed, date picker, gauge eksik |
| Faz 5 — Güvenlik | ✅ Planlandı | ❌ %15 — CORS var, gerisi yok |
| Faz 6 — Entegrasyon & Test | ✅ Planlandı | ❌ Test yok, simülatör yok |
| Faz 7 — Docker & Deploy | ✅ Planlandı | ✅ Tamamlandı |

---

## Bölüm 4 — Yanlış veya Farklı Yapılması Gereken Şeyler

### 🔴 Kritik Hatalar / Yanlışlar

1. **Alert şemasında `status` alanı yok, `acknowledged` boolean.** Frontend `status === 'active'` bekliyor ama DB'de bu alan yok. Şu an `acknowledged: false` = active, `acknowledged: true` = acknowledged olarak map ediliyor — tutarsız.

2. **Camera event endpoint image zorunlu.** Raspberry Pi her zaman image göndermeyebilir. `CameraEvent.imagePath` nullable değil fakat frontend placeholder görüntülüyor.

3. **JWT token 7 gün — refresh token yok.** Süresi dolunca sessizce login sayfasına atıyor. Kullanıcı deneyimi kötü, güvenlik açısından da refresh token olmalı.

4. **Tüm veriler `userId` ile ayrılıyor ama tek admin var.** Multi-tenant gibi tasarlandı ama gerçekte tek kullanıcı var. Resident kullanıcısının dashboard'u farklı mı olmalı belirsiz.

5. **Multer dosyaları container içinde `/uploads/` klasörüne kaydediyor.** Container yeniden başladığında veya rebuild'de bu dosyalar **KAYBOLUR** — persistent volume yok.

### 🟡 Tasarım Tercihleri Sorgulanabilir

6. **Settings sayfası tamamen görsel (dummy).** Kullanıcı toggle'a basıyor ama hiçbir şey kaydedilmiyor. Yanıltıcı.

7. **Floor Plan oda-cihaz eşleşmesi regex tabanlı isim kontrolü.** `deviceName.includes('Kitchen')` gibi kırılgan. Device tablosundaki `location` alanı varken kullanılmıyor — buradan eşleşmeli.

8. **Dashboard sensör listesi cihaz adına göre odaları eşliyor ama `Main RPi Controller` gibi belirsiz isimler tüm sensörleri Living Room'a düşürüyor** — seed verisi bu ismi kullandığından birçok farklı sensör aynı odada görünüyor.

9. **SensorReading'de `value Float` — string sensör değerleri (`"1"`, `"0"` motion) float'a dönüştürülüyor.** Motion sensor için 0/1 çalışıyor ama binary değerler (Kapı Açık/Kapalı) anlam olarak numeric değil.

10. **HistoryPage tarih aralığı seçici yok** — API destekliyor (`?from=&to=`) ama UI'da sadece sensor seçimi var, tarih filtresi yok.

---

## Bölüm 5 — Cloud'a Geçince Ne Değişecek?

### Zorunlu Değişiklikler

| Değişecek | Ne Yapılacak |
|---|---|
| **`DATABASE_URL`** | PostgreSQL container yerine managed DB'ye işaret edecek (AWS RDS, Supabase, Railway, NeonDB) |
| **`JWT_SECRET`**, **`MASTER_API_KEY`** | Environment variable olarak güvenli secret manager'a (AWS Secrets Manager, Vault, Railway secrets) taşınacak |
| **`VITE_API_URL`**, **`VITE_SOCKET_URL`** | `http://localhost:3001` yerine gerçek domain/IP |
| **`CLIENT_URL` (CORS)** | `http://localhost` yerine production domain |
| **Nginx / Reverse Proxy** | HTTPS termination + SSL sertifikası (Let's Encrypt / Certbot) |
| **Multer upload dizini** | Container dışına çıkacak: AWS S3 / Cloudflare R2 / GCS. Aksi halde yüklenen dosyalar kaybolur |
| **Port 80 → 443** | HTTP redirect + HTTPS zorunlu |

### Ekstra Yapılması Gerekenler (Cloud İçin)

| Görev | Öncelik |
|---|---|
| `docker-compose.yml` → `docker-compose.prod.yml` ayrımı | 🔴 Kritik |
| Persistent volume for uploads (S3 entegrasyonu) | 🔴 Kritik |
| Rate limiting aktifleştirme | 🟡 Yüksek |
| HTTPS / TLS (Nginx + Let's Encrypt) | 🟡 Yüksek |
| Health check endpoint (`GET /api/health`) | 🟡 Yüksek |
| DB migration scripti otomasyonu (`prisma migrate deploy`) | 🟡 Yüksek |
| PM2 veya container restart policy | 🟡 Yüksek |
| Log management (Winston → CloudWatch/Loki) | 🟢 Orta |
| DB indexing (`createdAt` üzerinde) | 🟢 Orta |
| Seed scripti cloud'da **ÇALIŞTIRILMAMALI** — CI/CD'den çıkarılmalı | ⚠️ Dikkat |

### Raspberry Pi ile Cloud Entegrasyonu

Raspberry Pi, bulut backend'e şu şekilde bağlanacak:

```
Raspberry Pi (Python/Node script)
    → HTTPS POST /api/sensors/readings
    → Header: X-API-Key: <device_apiKey>
    → Body: { sensorId, value }

Raspberry Pi (MJPEG stream)
    → Backend /api/camera/stream proxy endpoint (henüz yok!)
    → Veya WebRTC P2P
```

> [!WARNING]
> Raspberry Pi → Backend bağlantısı için şu anda **HIÇ SENARYO TEST EDİLMEDİ.** API hazır, ama gerçek cihaz hiç veri atmadı. İlk gerçek entegrasyon testi yapılmadan cloud deployment söz konusu olmamalı.

---

## Bölüm 6 — Mock Verilerin Kaldırılması

Tüm mock veriler `server/prisma/seed.js` içindedir. Gerçek sisteme geçerken:

```bash
# Veritabanını temizle (tüm mock data gider)
docker exec smarthome_backend npx prisma migrate reset --force

# Prodüksiyonda seed ÇALIŞTIRILMAZ
# Sadece migration:
docker exec smarthome_backend npx prisma migrate deploy
```

Seed'deki her kayıt yorum satırı ile `[MOCK_DATA]` etiketiyle işaretlidir — arama ile bulunabilir:

```bash
grep -n "MOCK_DATA" server/prisma/seed.js
```

---

## Bölüm 7 — Hızlı Referans

```
Giriş (mock/test):
  Admin    → admin@smarthome.local  / admin123
  Resident → deniz@smarthome.local  / resident1

API Base URL (local): http://localhost:3001/api
WebSocket (local):    ws://localhost:3001

IoT device auth:  X-API-Key header (her device'ın unique apiKey'i var)
Kullanıcı auth:   Authorization: Bearer <jwt>

Seed verilerini sıfırla:
  docker exec smarthome_backend npm run db:seed

Container logları:
  docker logs smarthome_backend -f
  docker logs smarthome_frontend -f
```
