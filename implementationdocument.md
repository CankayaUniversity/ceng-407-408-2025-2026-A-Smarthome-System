ÇANKAYA UNIVERSITY
FACULTY OF ENGINEERING
COMPUTER ENGINEERING DEPARTMENT
Implementation Document
CENG 408
Innovative System Design and Development II
A SMART HOME SYSTEM
Enis Mirsad Şengül
202211065
Duhan Ayberk Seven
202211062
Deniz Arda Çınarer
202211019
İbrahim Ersan Özdemir
202211054
Advisor: Prof. Dr. Murat Koyuncu
ÇANKAYA UNIVERSITY
CENG
A SMART HOME SYSTEM
Introduction
System Overview
2.1 Edge Layer (IoT Sensor & AI Module)
2.2 Cloud Backend (FastAPI Gateway & Supabase)
2.3 Web Dashboard
2.4 Mobile Application
2.5 Data Flow and Communication Architecture
Implemented Features
3.1 Environmental Monitoring System
3.2 Emergency Alert System
3.3 AI-Based Face Recognition & Security Pipeline
3.4 Resident Management and Embedding Sync
3.5 Real-Time Dashboard and Data Visualization
3.6 Push Notification System
3.7 Offline Resilience (Graceful Degradation)
Implementation Details
4.1 Versioning
4.2 Iteration Log
4.3 Repository Reference
4.4 Screenshots
1. Introduction
The Internet of Things (IoT) has progressed beyond theoretical exploration to become a
practical technology in everyday life, fundamentally transforming how people interact
with their living spaces.
While commercial platforms such as Google Home, Amazon Alexa, and Apple HomeKit
have popularized the concept of home automation with a focus on convenience and
voice-based controls, a considerable gap remains between systems that offer simple,
command-based automation and those that provide comprehensive environmental
monitoring, intelligent security, and proactive automation.
This project, titled “A Smart Home System,” addresses these limitations by proposing a
multi-faceted smart home solution integrating environmental monitoring, AI-enhanced
security, and remote accessibility.
The system is built upon four interconnected components: IoT sensor modules deployed
on a Raspberry Pi 5 edge controller, a FastAPI cloud gateway connected to a Supabase
backend, a React-based web dashboard, and a Flutter mobile application.
The development process was divided into two academic phases. In CENG 407, the
foundational architecture was designed, hardware components were selected and
validated, and the initial sensor integration and basic backend were prototyped.
In CENG 408, the project was expanded into a fully functional system with complete
cloud integration via Supabase, a production-ready face recognition pipeline, real-time
dashboards on both web and mobile platforms, push notification delivery, and
comprehensive resident management features.
This report details the implementation carried out in CENG 408, covering the developed
features, the iterative development process, technical components, and system
architecture decisions made throughout the development lifecycle.

2. System Overview
The Smart Home System follows a modular 4-Tier Layered Architecture designed for
separation of concerns, scalability, and maintainability.
The system prioritizes an “Edge-First” approach: critical processing and sensor
monitoring are performed locally on the Raspberry Pi to ensure reliability and privacy,
while cloud services provide data persistence and remote accessibility.
The system architecture consists of the following core modules:

2.1 Edge Layer (IoT Sensor & AI Module)
The Raspberry Pi 5 serves as the central edge controller, running the run_edge.py
orchestrator. This module manages all hardware interactions and local intelligence:

Sensor Hardware: DHT11 (temperature & humidity), MQ-2 (gas/smoke detection), soil
moisture sensor, and a PIR motion sensor are connected via GPIO pins. The Raspberry Pi
Camera Module v2 is connected via the CSI interface.
Sensor Reading Threads: A dedicated dht_reading_thread polls the DHT11 sensor every
2 seconds and transmits aggregated telemetry to the cloud at a configurable interval
(default: 60 seconds). A digital_sensor_thread continuously monitors MQ-2, soil
moisture, and PIR sensors at 1-second intervals with interrupt-like state change detection.
Face Recognition Pipeline: Upon PIR motion detection, the camera captures a burst of
images (configurable, default: 3 frames with 0.3-second delays). These frames are
processed through a three-stage AI pipeline:
Face Detection (FaceDetector): Uses MediaPipe Face Detection as the primary
backend with face_recognition library as a fallback. Includes CLAHE-based image
enhancement for low-light conditions.
Embedding Extraction (FaceEmbedder): Generates 128-dimensional face embeddings
using the face_recognition library. Supports both full-image and crop-based embedding
extraction with padding for improved accuracy.
Identity Matching (FaceMatcher): Compares extracted embeddings against locally
cached resident profiles using Euclidean distance with a configurable threshold (default:
0.55). Classifies individuals as “authorized” or “unauthorized.”
Cooldown Mechanism: A motion cooldown timer (default: 5 seconds) prevents
excessive camera captures and redundant recognition cycles.
2.2 Cloud Backend (FastAPI Gateway & Supabase)
The cloud backend consists of two tightly integrated components:
FastAPI Gateway (main.py): A Python-based REST API server running on the same host
as the edge controller also on a separate cloud server. It provides the following endpoints:

POST /api/v1/telemetry/sensors — Receives sensor readings and writes them to the
Supabase sensor_readings table.
POST /api/v1/events/security — Creates security events in the events table.
POST /api/v1/events/alert — Creates environmental alerts with configurable priority
levels.
POST /api/v1/events/upload-intelligent — Receives camera snapshots with face
classification metadata and stores them in Supabase Storage.
GET /api/v1/residents — Serves resident profiles with face embeddings to the edge
device for local matching.

POST /api/v1/heartbeat — Updates device online status and last-seen timestamp.
POST /api/v1/residents/backfill-embeddings — Triggers on-demand embedding
computation for resident photos.
Supabase Backend: A managed PostgreSQL database with real-time subscriptions, Row
Level Security (RLS), and object storage. The database schema includes the following
tables:
profiles — Links Supabase Auth users to application profiles.
devices — Registered IoT devices with online status, room assignment, and last-seen
timestamps.
sensor_readings — Time-series sensor data (temperature, humidity, smoke, water/soil).
events — System events including alerts, security events, with acknowledgement
tracking.
camera_events — Camera-triggered events with snapshot paths and face detection
metadata.
event_faces — Individual face classification results per camera event, including match
scores and bounding boxes.
residents — Registered resident profiles with photo paths and JSONB face embeddings.
Resident Embedding Backfill Thread: A background daemon thread runs on the FastAPI
gateway at configurable intervals (default: 45 seconds). It scans the residents table for
entries with uploaded photos but missing embeddings, downloads photos from Supabase
Storage, computes 128-dimensional face embeddings using the FaceEmbedder, and
writes the resulting vectors back to the database.
2.3 Web Dashboard
The web dashboard is built with React 19 and Vite 7, providing a comprehensive
management interface:

Technology Stack: React, React Router v7, Supabase JS Client, Recharts for data
visualization, Lucide React for iconography, and date-fns for date formatting.
Pages: The application includes eight main pages:
Dashboard: Real-time sensor readings, device status, and recent alerts overview.
Rooms: Room-based device grouping with sensor data aggregation.
History: Historical sensor data visualization with interactive line charts and date range
filtering.
Camera: Camera event gallery with snapshot images, face classification labels, and
detection metadata.
Alerts: Alert list with filtering, acknowledgement functionality, and priority indicators.
Residents: Resident profile management including photo upload, face embedding
status, and CRUD operations.

Settings: User preferences and system configuration.
Login: Supabase Auth-based email/password authentication.
Real-Time Updates: The dashboard uses Supabase Realtime subscriptions to receive
live updates for sensor readings, events, and camera events without polling.
Authentication & Authorization: Protected routes with Supabase Auth integration. Row
Level Security (RLS) policies ensure that only authenticated users can access data.
Theme Support: Light and dark theme toggle with persistent preference storage.
2.4 Mobile Application
The mobile application is developed using Flutter (Dart SDK 3.9.2), targeting Android
devices:

State Management: Provider pattern with four main providers:
AuthProvider: Manages Supabase authentication state and session lifecycle.
SupabaseDataProvider: Centralized data layer for fetching and caching data.
NotificationProvider: Real-time event subscriptions, and in-app alert popups.
ThemeProvider: Handles light/dark theme switching with SharedPreferences
persistence.
Screens: The application includes six main screens accessible via a bottom navigation
bar: Home (Dashboard), Camera, Alerts, Rooms, History, Settings, Residents, and Login.
Push Notifications: Implemented using flutter_local_notifications for local notification
display. The NotificationProvider subscribes to Supabase Realtime channels and
generates local notifications for critical events even when the app is in the background.
Real-Time Data: Supabase Realtime subscriptions for live sensor updates, new events,
and camera event notifications.
Offline Handling: Graceful error handling with user-friendly messages when network
connectivity is unavailable.
2.5 Data Flow and Communication Architecture
The end-to-end data flow follows this path:

Sensor → Edge Controller: Hardware sensors transmit readings via GPIO pins to the
Raspberry Pi run_edge.py process.
Edge Controller → FastAPI Gateway: Sensor telemetry, security events, alert events,
and camera snapshots are sent via HTTP POST requests to the FastAPI gateway.
FastAPI Gateway → Supabase: The gateway validates incoming data, associates it
with registered devices, and inserts records into the appropriate Supabase tables. Camera
snapshots are uploaded to Supabase Storage.

Supabase → Client Applications: The web dashboard and mobile app receive real-time
updates through Supabase Realtime subscriptions and fetch historical data via Supabase
REST API queries.
Cloud → Edge (Resident Sync): The edge controller’s ResidentSyncThread
periodically polls the gateway’s endpoint to download updated resident profiles with face
embeddings.
The cloud module provides an additional resilience layer with:
Offline Queue: SQLite-based request buffering for failed cloud uploads.
Sync Worker: A background thread that drains the offline queue when connectivity is
restored.
Connectivity Monitor: Probes the backend health endpoint to track online/offline state
transitions.
Heartbeat Sender: Periodic health checks that keep the device’s online status visible on
dashboards.
3. Implemented Features
3.1 Environmental Monitoring System
The system continuously monitors the indoor environment using a suite of sensors:

Temperature & Humidity: The DHT11 sensor is read in a dedicated background thread
every 2 seconds. Valid readings are aggregated and transmitted to the cloud at the
configured climate interval.
Gas/Smoke Detection: The MQ-2 sensor operates on a state-change detection model.
When the sensor’s digital output transitions, the system immediately creates an alert
event with appropriate severity.
Soil Moisture Monitoring: The capacitive soil moisture sensor reports dry/wet binary
state. State transitions trigger warning-level alerts for dry conditions and info-level
notifications for moisture restoration.
Both web and mobile dashboards display these readings in real-time with automatic
updates via Supabase.
3.2 Emergency Alert System
The emergency alert system uses an interrupt-based architecture for life-critical events:

Local Response: Upon gas/smoke detection, the edge controller immediately logs the
event and transmits a high-priority alert to the cloud backend.
Cloud Processing: The FastAPI gateway creates a fire_alert event with critical priority
in the Supabase events table.
Push Notification Delivery: The mobile application subscribes to the Supabase Realtime
channel. When a new critical event is detected, a local push notification is generated.

Alert Acknowledgement: Users can acknowledge active alerts through both the web
dashboard and mobile app. The acknowledged status is written back to the events table.
3.3 AI-Based Face Recognition & Security Pipeline
The face recognition system is the project’s core security feature, operating as a complete
pipeline from motion detection to identity classification:

Motion Detection & Burst Capture: When the PIR sensor detects motion, the camera
captures a burst of images.
Face Detection: Each burst frame is processed by the FaceDetector class, which
employs a dual-backend strategy (MediaPipe + face_recognition) and CLAHE-based
image enhancement.
Embedding Extraction: Detected face crops are passed to the FaceEmbedder, generating
128-dimensional vectors.
Identity Matching: The FaceMatcher compares extracted embeddings against locally
cached resident profiles. If the best match distance is ≤ 0.55, the person is classified as
“authorized”; otherwise, “unauthorized”.
Best Frame Selection: The system processes all burst frames and selects the best result.
Supabase Storage Upload: The selected frame with its classification results is uploaded
to the FastAPI gateway, which creates a security event and stores the snapshot.
Local Event Logging: All recognition events are logged to a local JSONL file for
offline auditability.
3.4 Resident Management and Embedding Sync
The system provides a complete workflow for managing authorized residents:

Adding Residents: Users can add new residents and optionally upload a face photo.
Automatic Embedding Computation: The FastAPI gateway runs a background daemon
thread that computes face embeddings for new photos and writes the vector back to the
database.
Edge Synchronization: The edge controller runs a ResidentSyncThread that fetches
resident profiles with valid embeddings to update the local residents.json file.
Deleting Residents: Resident deletion cascades properly, removing their embedding
from the next sync cycle.
3.5 Real-Time Dashboard and Data Visualization
Both the web dashboard and mobile application provide comprehensive data
visualization:

Real-Time Sensor Display: Current sensor values are displayed with automatic real-time
updates via Supabase Realtime channels.
Historical Data Charts: Interactive line charts for historical sensor data, utilizing
Recharts (web) and fl_chart (mobile).
Camera Event Gallery: Camera events are displayed with snapshot thumbnails, face
classification labels, match confidence scores, and timestamps.
3.6 Push Notification System
The notification system ensures users are informed of critical events:

Mobile Implementation: Uses flutter_local_notifications to display push notifications
for high-priority events (fire/gas detection, unauthorized person, low soil moisture).
Notification Content: Includes the event type, a descriptive message, and a timestamp.
Critical alerts are configured with maximum importance level.
In-App Alert Popup: Tapping a notification navigates to the relevant screen.
3.7 Offline Resilience (Graceful Degradation)
The system is designed to maintain core functionality during internet outages:

Local Sensor Processing: The edge controller continues to read sensors, trigger local
alarms, and process face recognition entirely offline.
Automatic Sync on Reconnection: A background drain cycle periodically checks
backend connectivity and replays queued items when restored.
Connectivity Monitoring: Probes the backend health endpoint to detect connectivity
transitions.
Local Event Log: All face recognition events are securely logged locally.
4. Implementation Details
4.1 Versioning
v0.1 — Initial hardware setup: Raspberry Pi 5 configuration, GPIO pin assignments,
sensor integration.
v0.2 — Core sensor polling loop and basic cloud communication.
v0.3 — Face recognition prototype with FaceMatcher.
v0.4 — Cloud migration to Supabase, FastAPI gateway setup.
v0.5 — Web dashboard implementation with real-time features.
v0.6 — Mobile application completion and offline resilience layer.
v1.0 — Final integrated system with end-to-end testing and UI refinements.
4.2 Iteration Log
Iteration 1 (CENG 407): Hardware assembly and initial sensor integration.
Iteration 2 (CENG 407–408 Transition): Core edge controller development
(multi-threaded polling, motion detection).
Iteration 3 (CENG 408): Cloud backend migration to Supabase and FastAPI.
Iteration 4 (CENG 408): Web dashboard development with React/Vite.
Iteration 5 (CENG 408): Mobile application development with Flutter.
Iteration 6 (CENG 408): AI pipeline refinement (CLAHE, embedding backfill) and
resilience module.
Iteration 7 (CENG 408): Integration testing, performance tuning, and documentation.
4.3 Repository Reference
Repository:
https://github.com/CankayaUniversity/ceng-407-408-2025-2026-A-Smarthome-System
Directory Structure:

face-recognition/ — Edge controller, FastAPI gateway, and AI vision modules
scripts/ — Test scripts
cloud/ — Offline resilience module
website/client/ — React/Vite web dashboard
Mobile-app/ — Flutter mobile application
supabase_setup.sql — Database schema and configuration
4.4 Screenshots
Screenshots are provided to demonstrate the implemented features and user interfaces of
the Smart Home System.
Figure 1: Mobile Application Login Screen

Figure 2: Mobile Application Dashboard — Real-Time Sensor Display

Figure 3: Mobile Application Camera Event — Face Recognition Result

Figure 4: Mobile Application Alerts Screen — All Alerts

Figure 5: Mobile Application Residents Screen — Add New Resident

Figure 6: Mobile Application Settings Screen

Figure 7: Web Dashboard — Main Dashboard with Sensor Cards and Recent Alerts
Figure 8: Web Dashboard — Historical Temperature and Humidity Charts

Figure 9: Web Dashboard — Camera Events with Face Classification
Figure 10: Web Dashboard — Resident Management with Embedding Status

Figure 11: Web Dashboard — Alerts List with Acknowledgement