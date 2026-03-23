# IoT Akıllı Ev Sistemi — Cloud-Based Web Application Geliştirme Planı & Yol Haritası

> Bu doküman, proje raporunuzun (report.md) detaylı analizi sonucunda hazırlanmıştır. Yalnızca **Module 2: Cloud-Based Web Application** kapsamını ele alır.

---

## 1. Rapor Analizi — Web Uygulaması Gereksinimleri Özeti

Rapordan süzülen web uygulamasını ilgilendiren temel gereksinimler:

| Kaynak | Gereksinim | Öncelik |
|---|---|---|
| User Story 2.3.1 | RESTful API (HTTPS/TLS, Token-based Auth) | 🔴 Kritik |
| User Story 2.3.2 | Tarihsel veri görselleştirme (line chart, tarih aralığı seçimi) | 🔴 Kritik |
| User Story 2.1.1 | Canlı iklim verisi gösterimi (sıcaklık, nem) | 🔴 Kritik |
| User Story 2.1.2 | Acil durum uyarıları (yangın, su baskını) — dashboard'da banner | 🔴 Kritik |
| User Story 2.2.2 | AI yüz tanıma sonuçları gösterimi & yetkili kişi yönetimi | 🟡 Yüksek |
| User Story 2.4.3 | Yetkilendirilmiş kişi ekleme (yüz fotoğrafı upload) | 🟡 Yüksek |
| User Story 2.1.4 | Pet kaynak izleme (yem/su seviyesi) | 🟢 Orta |
| User Story 2.1.5 | Işık durumu & enerji izleme | 🟢 Orta |
| User Story 2.1.6 | Bitki nem seviyesi izleme | 🟢 Orta |
| Fig. 7 | Live Camera Feed (gerçek zamanlı kamera akışı) | 🟡 Yüksek |
| NFR 3.1 | Kullanıcı şifreleri bcrypt/Argon2 ile hash'lenecek | 🔴 Kritik |
| NFR 3.5 | 200ms'de UI feedback, hata mesajları kullanıcı dostu | 🟢 Orta |
| Arch. Layer 1 | Stateless, API-driven Presentation Layer | 🔴 Kritik |
| DB 3.1–3.5 | ER: Users, Devices, Sensors, SensorReadings, Alerts, CameraEvents, FaceProfiles | 🔴 Kritik |

---

## 2. Teknoloji Yığını (Technology Stack) Önerisi & Gerekçeleri

### 2.1 Frontend

| Teknoloji | Gerekçe |
|---|---|
| **React 19 + Vite** | Hızlı geliştirme, komponent bazlı mimari, rapordaki "stateless" gereksinimine uygun |
| **React Router v7** | Dashboard, Settings, Camera gibi birden fazla sayfa arası navigasyon |
| **Recharts** veya **Chart.js (react-chartjs-2)** | User Story 2.3.2 — tarihsel veri line chart görselleştirmesi |
| **Vanilla CSS + CSS Modules** | Projenin kapsamına uygun, ekstra bağımlılık gerektirmez |
| **Lucide React** | Hafif, modern ikonlar |

### 2.2 Backend

| Teknoloji | Gerekçe |
|---|---|
| **Node.js + Express.js** | JavaScript ekosisteminde kalır, RESTful API geliştirme hızı yüksek |
| **JWT (jsonwebtoken)** | Token-based authentication (User Story 2.3.1) |
| **bcrypt** | Şifre hash'leme (NFR 3.1) |
| **Socket.IO** | Gerçek zamanlı sensor data push & canlı kamera akışı (WebSocket) |
| **Multer** | Yüz fotoğrafı yükleme (User Story 2.4.3) |
| **helmet + cors + rate-limiter** | Güvenlik katmanı |

### 2.3 Veritabanı

| Teknoloji | Gerekçe |
|---|---|
| **PostgreSQL** | Rapordaki ilişkisel ER diyagramı (Users ↔ Devices ↔ Sensors ↔ Alerts) bire bir destekler, time-series sorgular için güçlü |
| **Prisma ORM** | Type-safe, kolay migration, şema-ilk yaklaşım |

> [!TIP]
> **Alternatif:** Projenin ölçeğine göre daha hızlı kurulum için **SQLite** (geliştirme) + **PostgreSQL** (production) ikili yapısı da düşünülebilir. Firebase/Supabase gibi BaaS seçenekler de değerlendirilebilir — bu konudaki tercihinizi bekliyorum.

### 2.4 Real-time & Camera Feed

| Teknoloji | Gerekçe |
|---|---|
| **Socket.IO** | Sensör verilerini push etme, canlı durum güncelleme |
| **MJPEG over HTTP** veya **WebRTC** | Live Camera Feed — Raspberry Pi kamerası MJPEG stream'i sunacak, web dashboard proxy üzerinden gösterecek |

### 2.5 DevOps & Deployment

| Teknoloji | Gerekçe |
|---|---|
| **Docker + Docker Compose** | Backend + DB tek komutla ayağa kalkar |
| **Nginx** (opsiyonel) | Reverse proxy, HTTPS/TLS termination |

---

## 3. Proje Mimarisi & Klasör Yapısı

```
BITIRME-WEBSITESI/
├── client/                      # React Frontend (Vite)
│   ├── public/
│   ├── src/
│   │   ├── assets/              # Görseller, fontlar
│   │   ├── components/          # Yeniden kullanılabilir UI bileşenleri
│   │   │   ├── Layout/          # Sidebar, Header, Footer
│   │   │   ├── Dashboard/       # SensorCard, AlertBanner, LiveCamera
│   │   │   ├── Charts/          # HistoricalChart, GaugeCard
│   │   │   └── Common/          # Button, Modal, LoadingSpinner
│   │   ├── pages/               # Route sayfaları
│   │   │   ├── LoginPage.jsx
│   │   │   ├── DashboardPage.jsx
│   │   │   ├── HistoryPage.jsx
│   │   │   ├── CameraPage.jsx
│   │   │   ├── AlertsPage.jsx
│   │   │   ├── ResidentsPage.jsx
│   │   │   └── SettingsPage.jsx
│   │   ├── context/             # AuthContext, SocketContext
│   │   ├── hooks/               # useAuth, useSensorData, useAlerts
│   │   ├── services/            # api.js (axios instance), socket.js
│   │   ├── utils/               # formatters, constants
│   │   ├── App.jsx
│   │   ├── main.jsx
│   │   └── index.css
│   ├── package.json
│   └── vite.config.js
│
├── server/                      # Node.js Backend (Express)
│   ├── prisma/
│   │   └── schema.prisma        # Veritabanı şeması
│   ├── src/
│   │   ├── config/              # db.js, env.js
│   │   ├── middleware/          # auth.js, errorHandler.js, validate.js
│   │   ├── routes/              # auth.routes.js, sensor.routes.js, alert.routes.js, camera.routes.js
│   │   ├── controllers/        # auth.controller.js, sensor.controller.js, ...
│   │   ├── services/           # climate.service.js, alert.service.js, face.service.js
│   │   ├── socket/             # socketHandler.js (real-time event broadcasting)
│   │   ├── utils/              # helpers, constants
│   │   └── app.js              # Express app setup
│   ├── package.json
│   └── .env.example
│
├── docker-compose.yml           # PostgreSQL + Backend + Frontend
├── report.md                    # Proje raporu (mevcut)
└── README.md
```

---

## 4. Adım Adım Geliştirme Fazları

### Faz 0 — Proje İskeleti & Ortam Kurulumu *(~1 oturum)*

- [ ] Vite + React projesi oluşturma (`client/`)
- [ ] Express.js projesi oluşturma (`server/`)
- [ ] PostgreSQL Docker container kurulumu
- [ ] Prisma ORM bağlantısı & ilk migration
- [ ] Ortam değişkenleri (`.env`) yapılandırması
- [ ] Temel CSS Design System (renk paleti, tipografi, dark theme altyapısı)

---

### Faz 1 — Authentication & Veritabanı Şeması *(~2 oturum)*

- [ ] **DB Schema (Prisma):** `User`, `Device`, `Sensor`, `SensorReading`, `Alert`, `CameraEvent`, `FaceProfile` tabloları
- [ ] **Auth API:** `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me`
- [ ] JWT token üretimi & doğrulama middleware'i
- [ ] Şifre hash'leme (bcrypt)
- [ ] **Frontend:** Login sayfası, AuthContext, ProtectedRoute wrapper
- [ ] Postman/Thunder Client ile API testi

> **Doğrulama:** Register → Login → Token al → Korumalı endpoint'e istek at

---

### Faz 2 — RESTful API Geliştirme *(~2-3 oturum)*

Rapordaki her bir Business Logic modülü için CRUD endpoint'leri:

#### Climate Monitoring
- [ ] `POST /api/sensors/readings` — Raspberry Pi'den gelen veri (sıcaklık, nem, duman, su, ağırlık, nem)
- [ ] `GET /api/sensors/latest` — En son okumalar
- [ ] `GET /api/sensors/history?from=...&to=...&type=...` — Tarihsel data

#### Alert Management
- [ ] `POST /api/alerts` — Yeni alert oluşturma (IoT'den gelir)
- [ ] `GET /api/alerts` — Alert listesi (filtreli, sayfalı)
- [ ] `PATCH /api/alerts/:id/acknowledge` — Alert'i okundu işaretleme

#### Camera & Surveillance
- [ ] `POST /api/camera/events` — Kamera olayı kaydetme (image + sonuç)
- [ ] `GET /api/camera/events` — Geçmiş kamera olayları
- [ ] `GET /api/camera/stream` — Canlı stream proxy endpoint

#### Resident Management (Face Profiles)
- [ ] `POST /api/residents` — Yeni yüz profili ekleme (multipart/form-data)
- [ ] `GET /api/residents` — Kayıtlı kişi listesi
- [ ] `DELETE /api/residents/:id` — Kişi silme

#### Device Management
- [ ] `POST /api/devices` — Cihaz kaydı
- [ ] `GET /api/devices` — Cihaz listesi

> **Doğrulama:** Her endpoint için Postman collection oluşturma + hata durumları testi

---

### Faz 3 — Real-time Altyapısı (Socket.IO) *(~1 oturum)*

- [ ] Socket.IO server entegrasyonu (JWT ile auth)
- [ ] Event kanalları tasarımı:
  - `sensor:update` — Anlık sensör verisi
  - `alert:new` — Yeni acil durum uyarısı
  - `camera:frame` — Canlı kamera karesi (opsiyonel, MJPEG tercih edilebilir)
- [ ] Frontend `SocketContext` — bağlantı yönetimi
- [ ] Backend'e IoT cihaz gönderimi simülasyonu (test scripti)

---

### Faz 4 — Dashboard UI İnşası *(~3-4 oturum)*

Bu faz, raporun Figure 7'deki Web Dashboard tasarımını hayata geçirir:

#### 4.1 Layout & Navigation
- [ ] Sidebar (Dashboard, History, Camera, Alerts, Residents, Settings)
- [ ] Header (kullanıcı profili, bildirim göstergesi)
- [ ] Responsive grid layout

#### 4.2 Dashboard Ana Sayfa
- [ ] **SensorCard** bileşenleri — Sıcaklık 🌡️, Nem 💧, Duman 🔥, Su seviyesi 🌊
- [ ] **AlertBanner** — Aktif acil durum uyarıları (kırmızı, yanıp sönen border — NFR'den)
- [ ] **Pet Resource Gauge** — Yem/Su yüzdesi (gauge veya progress bar)
- [ ] **Plant Moisture** — Toprak nemi göstergesi
- [ ] **Light Status** — Işık On/Off durumu & süre
- [ ] **Mini Live Camera Preview** — Küçük live feed penceresi

#### 4.3 History (Tarihsel Veri) Sayfası
- [ ] Tarih aralığı seçici (date range picker)
- [ ] Sensör tipi filtresi
- [ ] Recharts/Chart.js ile **line chart** görselleştirmesi
- [ ] Veri export (CSV) butonu (opsiyonel)

#### 4.4 Camera Sayfası
- [ ] Live Camera Feed alanı (MJPEG `<img>` tag veya WebRTC)
- [ ] Geçmiş kamera olayları listesi (tarih, sonuç: Authorized/Unauthorized, fotoğraf)

#### 4.5 Alerts Sayfası
- [ ] Alert listesi (tablo formatı: tarih, tip, cihaz, durum)
- [ ] Filtreleme (tip: fire/flood/intrusion, durum: active/acknowledged)
- [ ] "Acknowledge" butonu

#### 4.6 Residents Sayfası
- [ ] Kayıtlı kişi kartları (ad, fotoğraf)
- [ ] "Yeni Kişi Ekle" modal'ı — fotoğraf yükleme + isim
- [ ] Kişi silme

#### 4.7 Settings Sayfası
- [ ] Bildirim tercihleri toggle'ları
- [ ] Cihaz yönetimi
- [ ] Sensör polling aralığı ayarı (opsiyonel)

---

### Faz 5 — Güvenlik & Hardening *(~1 oturum)*

- [ ] HTTPS/TLS yapılandırması (self-signed cert veya Let's Encrypt)
- [ ] CORS politikası konfigürasyonu
- [ ] Rate limiting
- [ ] API Key/Token mekanizması — IoT cihaz → Server arası (API Key header)
- [ ] Input validation (express-validator / Zod)
- [ ] Error handling middleware (kullanıcı dostu mesajlar — NFR 3.5)

---

### Faz 6 — Entegrasyon & Test *(~1-2 oturum)*

- [ ] IoT simülatör scripti (sensör verisi + alert gönderen Python/Node script)
- [ ] Uçtan uca akış testi: Sensör → API → DB → WebSocket → Dashboard
- [ ] Camera feed entegrasyon testi (Raspberry Pi veya mock stream)
- [ ] Responsive tasarım kontrolü (tablet & masaüstü)
- [ ] Performans: 200ms UI feedback doğrulama (NFR 3.5)

---

### Faz 7 — Docker & Deployment *(~1 oturum)*

- [ ] `Dockerfile` — Backend
- [ ] `Dockerfile` — Frontend (static build)
- [ ] `docker-compose.yml` — PostgreSQL + Backend + Frontend
- [ ] README.md — Kurulum ve çalıştırma talimatları
- [ ] Demo data seeder scripti (opsiyonel)

---

## 5. Spesifik Zorluklar ve Stratejik Çözümler

### 5.1 RESTful API Tasarımı

**Zorluk:** IoT cihazdan gelen yüksek frekanslı veri (her 30 sn) ile kullanıcı istekleri arasında yetkilendirme farkı.

**Strateji:**
- **İki katmanlı auth:** Kullanıcılar JWT ile, IoT cihaz ise `X-API-Key` header ile doğrulanır
- Sensör veri endpoint'i toplu yazma destekler (batch insert)
- Rate limiter kullanıcı ve cihaz için farklı kota uygular

### 5.2 Historical Data Visualization

**Zorluk:** Aylar boyunca birikmiş büyük veri setleri ile performanslı grafik çizimi.

**Strateji:**
- Veritabanında time-series indexleme (`created_at` üzerinde B-tree index)
- Backend'de veri aralığına göre **downsampling** — 1 günlük aralık: ham veri, 1 hafta: saatlik ortalama, 1 ay: günlük ortalama
- Frontend'de lazy loading ve virtualization

### 5.3 Real-time Live Camera Feed

**Zorluk:** Raspberry Pi'den düşük gecikmeli, güvenli video akışı.

**Strateji:**
```
Raspberry Pi (MJPEG stream) → Backend Proxy → Authenticated WebSocket/HTTP → Frontend <img> tag
```
- Raspberry Pi `libcamera` + MJPEG HTTP server çalıştırır (port 8081)
- Backend, authenticated proxy endpoint sunar (`GET /api/camera/stream`)
- Frontend basitçe bir `<img src="..." />` ile MJPEG gösterir — tarayıcı native destekler
- **Gizlilik:** Camera feed sadece auth'lu kullanıcılardan erişilebilir, varsayılan olarak kapalı



---

## 6. Veritabanı ER Şeması (Prisma Modeli Taslağı)

Rapordaki Section 3 (Database Design) ile uyumlu:

```
┌──────────┐    1:N    ┌──────────┐    1:N    ┌──────────────┐
│   User   │──────────▶│  Device  │──────────▶│    Sensor    │
│          │           │          │           │              │
│ id       │           │ id       │           │ id           │
│ email    │           │ userId   │           │ deviceId     │
│ password │           │ name     │           │ type (enum)  │
│ name     │           │ location │           │ label        │
│ role     │           │ status   │           └──────┬───────┘
│ notifs   │           └────┬─────┘                  │ 1:N
└──────────┘                │                        ▼
                            │ 1:N          ┌─────────────────┐
                            │              │ SensorReading   │
                            │              │ id              │
                            │              │ sensorId        │
                            │              │ value           │
                            │              │ unit            │
                            │              │ createdAt       │
                            │              └─────────────────┘
                            │
                            │ 1:N
                            ▼
                   ┌──────────────┐          ┌───────────────┐
                   │    Alert     │          │  CameraEvent  │
                   │ id           │          │ id            │
                   │ deviceId     │          │ deviceId      │
                   │ userId       │          │ imagePath     │
                   │ type (enum)  │          │ result (enum) │
                   │ message      │          │ faceProfileId?│
                   │ severity     │          │ createdAt     │
                   │ acknowledged │          └───────────────┘
                   │ createdAt    │
                   └──────────────┘
                                             ┌───────────────┐
                                             │  FaceProfile  │
                                             │ id            │
                                             │ userId        │
                                             │ name          │
                                             │ imagePath     │
                                             │ embedding     │
                                             │ createdAt     │
                                             └───────────────┘
```

---

## 7. Zaman Çizelgesi (Tahmini)

| Faz | Süre (Oturum) | Kümülatif |
|---|---|---|
| Faz 0 — Proje İskeleti | 1 | 1 |
| Faz 1 — Auth & DB Schema | 2 | 3 |
| Faz 2 — RESTful API | 2-3 | 5-6 |
| Faz 3 — Real-time (Socket.IO) | 1 | 6-7 |
| Faz 4 — Dashboard UI | 3-4 | 9-11 |
| Faz 5 — Güvenlik | 1 | 10-12 |
| Faz 6 — Entegrasyon & Test | 1-2 | 11-14 |
| Faz 7 — Docker & Deploy | 1 | 12-15 |

> [!IMPORTANT]
> Yukarıdaki tahminler "oturum" bazlıdır (her oturum ≈ birlikte çalıştığımız ≈2-4 saat). Gerçek süre, kararlarımıza ve çıkacak konulara göre değişebilir.

---

## User Review Required

Plana devam etmeden önce kararınızı beklediğim noktalar:

> [!IMPORTANT]
> **1. Veritabanı Tercihi:** PostgreSQL öneriyorum, ancak Firebase/Supabase gibi BaaS platformları da kullanılabilir. Bu, backend karmaşıklığını önemli ölçüde azaltır ama öğrenme/kontrol açısından farklı trade-off'lar sunar. Tercihiniz nedir?
>
> **2. Deployment Hedefi:** Proje sunumu için nerede host edilecek? (Lokal Docker, üniversite sunucusu, Vercel/Railway/Render, VPS?) Bu karar bazı mimari kararları etkiler.
>
> **3. Mobil Entegrasyon:** Mobile app (Module 3) ayrı bir proje mi olacak yoksa API'yi bu web panel ile paylaşacak mı? Bunu bilmek API tasarımını etkiler.
>
> **4. AI İşleme:** Yüz tanıma AI'ı tamamen Raspberry Pi'da mı çalışacak yoksa cloud (bu backend) üzerinden mi işlenecek? Raporda iki seçenek de geçiyor.

---

## Verification Plan

### Automated Tests
- Her API endpoint'i için Postman/Thunder Client collection
- `npm test` ile temel API entegrasyon testleri (opsiyonel, Jest + Supertest)

### Manual Verification
- Faz sonlarında tarayıcıda görsel kontrol (responsive, dark mode)
- IoT simülatör scripti ile uçtan uca veri akışı testi
- Login → Dashboard → History → Camera akışını adım adım doğrulama
