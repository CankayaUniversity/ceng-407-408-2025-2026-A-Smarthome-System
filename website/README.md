# IoT Smart Home — Cloud-Based Web Application

This repository contains the **Module 2: Cloud-Based Web Application** for the "IoT Destekli Akıllı Ev Sistemi" project. It provides a real-time dashboard for monitoring climate sensors, receiving security alerts, viewing live camera feeds, and managing resident face profiles.

## Features
- 🌡️ **Real-time Climate Monitoring:** Temperature, Humidity, Smoke, Water Leak, and more.
- 🚨 **Security Alerts & Notifications:** Instant dashboard banners for Fire, Flood, and Intrusions via Socket.IO.
- 👁️ **Face Recognition Integration:** Manage authorized face profiles and view history of camera events.
- 📹 **Live Camera Feed:** View the MJPEG HTTP stream directly from the Raspberry Pi.
- 📈 **Historical Data & Charts:** View historical sensor data over 24h, 7d, or 30d periods.
- 🔒 **Role-Based Access + API Keys:** Secure web panel with JWT, and secure IoT device reporting with API Keys.

## Technology Stack
- **Frontend:** React 19, Vite, React Router, Recharts, Lucide React
- **Backend:** Node.js, Express.js, Socket.IO, Prisma ORM
- **Database:** PostgreSQL (or SQLite for quick local dev)
- **Deployment:** Docker, Docker Compose

---

## 🚀 Quick Start (Docker)

The easiest way to run the entire stack (PostgreSQL + Backend + Frontend) is using Docker Compose.

1. Create a `.env` file in the root based on `.env.example`.
2. Run Docker Compose:
```bash
docker-compose up --build -d
```
3. The dashboard will be accessible at: `http://localhost:80`

---

## 🛠️ Local Development Setup

If you want to run the application locally without Docker for development:

### 1. Backend Setup
```bash
cd server
npm install
# Create a .env file and set DATABASE_URL (SQLite is default configured in schema)
# To use SQLite on Windows: DATABASE_URL="file:./dev.db"
npx prisma db push
npm run db:seed  # Generates an admin user and test data
npm run dev      # Starts server on http://localhost:3001
```

### 2. Frontend Setup
```bash
cd client
npm install
# Create a .env file and set VITE_API_URL and VITE_SOCKET_URL
npm run dev      # Starts frontend on http://localhost:5173
```

### Default Admin Credentials (from seed):
- **Email:** admin@smarthome.local
- **Password:** admin123

---

## 🤖 IoT Device Integration

Raspberry Pi (veya ESP32) sensör verilerini göndermek için aşağıdaki REST API'yi kullanmalıdır:

**Endpoint:** `POST /api/sensors/readings`
**Headers:**
- `x-api-key`: Sizin belirlediğiniz gizli anahtar
- `x-device-id`: Cihazın ID'si (örneğin `1`)
- `Content-Type`: `application/json`

**Body (JSON):**
```json
{
  "readings": [
    { "sensorId": 1, "value": 23.5 },
    { "sensorId": 2, "value": 45.2 }
  ]
}
```

*Python (Raspberry Pi) veya Node.js ile simülasyon yapmak için `server/scripts/iot-simulator.js` dosyasını inceleyebilirsiniz.*
