ÇANKAYA UNIVERSITY
FACULTY OF ENGINEERING
COMPUTER ENGINEERING DEPARTMENT
Test Plan, Test Design Specifications and Test Cases
Version 1
CENG
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
Test Plan, Test Design Specifications and Test Cases
CENG
A SMART HOME SYSTEM
INTRODUCTION
1.1 Version Control
1.2 Overview
1.3 Scope
1.4 Terminology
FEATURES TO BE TESTED
2.1 User Authentication (UA)
2.2 Sensor Monitoring (SM)
2.3 Emergency Alert System (EA)
2.4 Face Recognition & Security (FR)
2.5 Dashboard & Data Visualization (DV)
2.6 Resident Management (RM)
FEATURES NOT TO BE TESTED
ITEM PASS/FAIL CRITERIA
4.1 Exit Criteria
REFERENCES
TEST DESIGN SPECIFICATIONS
6.1 User Authentication (UA)
6.1.1 Subfeatures to be tested
6.1.2 Test Cases
6.2 Sensor Monitoring (SM)
6.2.1 Subfeatures to be tested
6.2.2 Test Cases
6.3 Emergency Alert System (EA)
6.3.1 Subfeatures to be tested
6.3.2 Test Cases
6.4 Face Recognition & Security (FR)
6.4.1 Subfeatures to be tested
6.4.2 Test Cases
6.5 Dashboard & Data Visualization (DV)
6.5.1 Subfeatures to be tested
6.5.2 Test Cases
6.6 Resident Management (RM)
6.6.1 Subfeatures to be tested
6.6.2 Test Cases
DETAILED TEST CASES
7.1 UA.EP.01
7.2 UA.EP.02
7.3 UA.EP.03
7.4 UA.SO.01
7.5 SM.CT.01
7.6 SM.CT.02
7.7 SM.GD.01
7.8 EA.FA.01
7.9 EA.ND.01
7.10 EA.AK.01
7.11 FR.MC.01
7.12 FR.FD.01
7.13 FR.FM.01
7.14 FR.FM.02
7.15 FR.SU.01
7.16 DV.RS.01
7.17 DV.HC.01
7.18 DV.CE.01
7.19 RM.AR.01
7.20 RM.DR.01
7.21 RM.ES.01
7.22 RM.ES.02
7.23 SM.GD.02
7.24 SM.SM.01
7.25 SM.SM.02
7.26 EA.FA.02
7.27 EA.ND.02
7.28 FR.MC.02
7.29 FR.FD.02
7.30 FR.FM.03
7.31 FR.SU.02
7.32 DV.RS.02
7.33 DV.HC.02
7.34 DV.CE.02 36
7.35 RM.AR.02 37
1. INTRODUCTION
1.1 Version Control
Version No Description of Changes Date
1.0 First version of the test plan
document
April 29, 2026
1.2 Overview
This document describes the test plan, test design specifications, and test cases for the “A Smart
Home System” project. The system integrates IoT sensor monitoring, AI-based face recognition
for security, a cloud backend (Supabase), a Flutter mobile application, and a React-based web
dashboard to provide comprehensive home automation, environmental monitoring, and
intelligent security.

1.3 Scope
This document covers the functional testing of major features of the Smart Home System,
including user authentication, environmental sensor monitoring (temperature, humidity, gas, soil
moisture), emergency alert detection and notification, AI-based face recognition and intrusion
detection, real-time dashboard visualization, and resident management. It defines pass/fail
criteria and detailed test cases for all implemented modules across the mobile app, web
dashboard, edge device (Raspberry Pi), and cloud backend.

1.4 Terminology
Acronym Definition
2.1 User Authentication (UA)
SM Sensor Monitoring
EA Emergency Alert System
FR Face Recognition & Security
DV Dashboard & Data Visualization
RM Resident Management
IoT Internet of Things
PIR Passive Infrared (motion sensor)
DHT Digital Humidity and Temperature sensor
MQ-2 Gas/Smoke sensor
API Application Programming Interface
TC Test Case
2. FEATURES TO BE TESTED
This section lists and gives a brief description of all the major features to be tested. For each
major feature there will be a Test Design Specification added at the end of this document.

2.1 User Authentication (UA)
The system provides user authentication through Supabase. Users can sign in with
email/password credentials via the mobile app and web dashboard. The system maintains session
state and supports sign-out functionality.

2.2 Sensor Monitoring (SM)
The edge device (Raspberry Pi 5) reads environmental sensors (DHT11 for
temperature/humidity, MQ-2 for gas/smoke, soil moisture sensor) at configurable intervals and
transmits telemetry data to the cloud backend via a FastAPI gateway. Both web and mobile
interfaces display real-time and historical sensor data.

2.3 Emergency Alert System (EA)
The system uses an interrupt-based architecture for critical events. When gas/smoke is detected
or soil moisture drops below threshold, high-priority alerts are generated, stored in the database,
and push notifications are sent to the mobile application.

2.4 Face Recognition & Security (FR)
Upon PIR motion detection, the camera captures burst images. A face detection pipeline
(MediaPipe/face_recognition) identifies faces, generates embeddings, and compares them against
registered resident profiles using Euclidean distance matching. Authorized persons are logged;
unauthorized persons trigger security alerts with snapshot uploads.

2.5 Dashboard & Data Visualization (DV)
The web dashboard (React/Vite) and mobile app (Flutter) display real-time sensor readings,
camera events, alerts, and device status. Historical sensor data is visualized through charts, and
alerts can be acknowledged by users.

2.6 Resident Management (RM)
Users can add, update, and delete resident profiles through the mobile app and web dashboard.
Resident photos are uploaded to Supabase Storage, face embeddings are automatically computed
by a background thread, and the edge device periodically syncs resident data for local face
matching.

3. FEATURES NOT TO BE TESTED
● Scenario-Based Automation Engine: The IFTTT-style rule engine for creating complex
automation scenarios (e.g., “Away Mode”, “Night Mode”) is part of the extended scope
and is not included in the current testing phase.
● Energy Consumption Monitoring: Integration of current transformer sensors for
real-time power monitoring is planned as future work.
● Local Touch Display Dashboard: The Raspberry Pi touchscreen interface is under
development and excluded from this testing cycle.
● Pet Resource Monitoring (Load Cell): While the hardware is integrated, the
weight-based pet food/water monitoring feature is not fully calibrated for testing.
4. ITEM PASS/FAIL CRITERIA
When the actual output of the system matches the expected output described in the test case, the
test case is considered passed. When there is a discrepancy between expected and actual
behavior, including incorrect data display, failed API responses, missed notifications, or incorrect
face classification, the test case fails.

4.1 Exit Criteria
Testing is considered successful when:
● 100% of the test cases are executed
● At least 90% of the test cases pass
● All High priority test cases pass
● No critical functional errors remain in the core modules (authentication, sensor
monitoring, emergency alerts, face recognition)

5. REFERENCES
● [1] A Smart Home System — Project Report (CENG 407), 2026
● [2] A Smart Home System — System Architecture & Design Document, 2026
● [3] A Smart Home System — Product Vision & Scope Document, 2026
● [4] Supabase Documentation, https://supabase.com/docs
6. TEST DESIGN SPECIFICATIONS
6.1 User Authentication (UA)
6.1.1 Subfeatures to be tested
● Email/Password Login (UA.EP): This subfeature allows users to sign in using their
registered email address and password via the Supabase authentication service on both the
mobile app and web dashboard.
● Sign Out (UA.SO): This subfeature allows authenticated users to sign out of the
application, clearing the session and redirecting to the login screen.
6.1.2 Test Cases
TC ID Requirements Priority Scenario Description
UA.EP.01 2.4 H Enter valid email and
password and verify
successful login
UA.EP.02 2.4 H Enter valid email and
blank password and
verify error
UA.EP.03 2.4 M Enter invalid email
format and verify
error message
UA.SO.01 2.4 H Sign out from the app
and verify redirect to
login screen
6.2 Sensor Monitoring (SM)
6.2.1 Subfeatures to be tested
● Climate Telemetry (SM.CT): This subfeature reads temperature and humidity data from
the DHT11 sensor at configurable intervals and transmits readings to the cloud via the
FastAPI gateway.
● Gas Detection (SM.GD): This subfeature monitors the MQ-2 sensor for gas/smoke
detection using GPIO digital input and reports state changes to the backend.
● Soil Moisture (SM.SM): This subfeature monitors the soil moisture sensor and reports
dry/wet state transitions to the backend.
6.2.2 Test Cases
TC ID Requirements Priority Scenario Description
SM.CT.01 2.1.1 H Verify temperature
and humidity
readings are sent at
configured interval
SM.CT.02 2.1.1 H Verify sensor
readings appear on
the dashboard within
1 minute
SM.GD.01 2.1.2 H Trigger gas sensor
and verify state
change is reported
SM.GD.02 2.1.2 M Clear gas condition
and verify “cleared”
alert is sent
SM.SM.01 2.1.6 H Verify dry soil state
triggers a low
moisture alert
TC ID Requirements Priority Scenario Description
SM.SM.02 2.1.6 M Verify soil moisture
restored notification
after re-watering
6.3 Emergency Alert System (EA)
6.3.1 Subfeatures to be tested
● Fire/Gas Alert (EA.FA): This subfeature generates critical alerts when the MQ-2 sensor
detects gas/smoke, triggers the local buzzer, and sends push notifications.
● Alert Notification Delivery (EA.ND): This subfeature delivers push notifications to the
mobile app when critical events occur, even if the app is in the background.
● Alert Acknowledgement (EA.AK): This subfeature allows users to acknowledge alerts
through the dashboard or mobile app.
6.3.2 Test Cases
TC ID Requirements Priority Scenario Description
EA.FA.01 2.1.2 H Trigger gas sensor
and verify critical
alert is created in
database
EA.FA.02 2.1.2 H Verify alert
notification latency is
under 5 seconds
EA.ND.01 2.4.1 H Verify push
notification is
received on mobile
for fire alert
TC ID Requirements Priority Scenario Description
EA.ND.02 2.4.1 M Verify notification
content includes
event type and
timestamp
EA.AK.01 2.4 H Acknowledge an
alert and verify status
update in database
6.4 Face Recognition & Security (FR)
6.4.1 Subfeatures to be tested
● Motion Detection & Capture (FR.MC): This subfeature activates the camera when the
PIR sensor detects motion and captures a burst of images for analysis.
● Face Detection (FR.FD): This subfeature processes captured images using MediaPipe or
face_recognition library to detect face bounding boxes.
● Face Embedding & Matching (FR.FM): This subfeature generates 128-dimensional face
embeddings and compares them against registered resident embeddings using Euclidean
distance with a configurable threshold.
● Security Event Upload (FR.SU): This subfeature uploads the best frame with face
classification results to the cloud and creates security events.
6.4.2 Test Cases
TC ID Requirements Priority Scenario Description
FR.MC.01 2.2.1 H Trigger PIR sensor
and verify camera
captures burst images
FR.MC.02 2.2.1 M Verify motion
cooldown prevents
TC ID Requirements Priority Scenario Description
excessive captures
FR.FD.01 2.2.2 H Present a face to
camera and verify
face is detected
FR.FD.02 2.2.2 M Verify no-face frames
are correctly skipped
FR.FM.01 2.2.2 H Present a registered
resident and verify
authorized
classification
FR.FM.02 2.2.2 H Present an
unregistered person
and verify
unauthorized
classification
FR.FM.03 2.2.2 M Verify match score is
below threshold
(0.55) for authorized
persons
FR.SU.01 2.2.2 H Verify security event
with snapshot is
uploaded to Supabase
FR.SU.02 2.2.2 H Verify unauthorized
detection triggers an
intrusion alert

6.5 Dashboard & Data Visualization (DV)
6.5.1 Subfeatures to be tested
● Real-time Sensor Display (DV.RS): This subfeature displays current temperature,
humidity, gas status, and soil moisture on both the web dashboard and mobile app.
● Historical Data Charts (DV.HC): This subfeature visualizes historical sensor readings as
charts with date range selection.
● Camera Event Display (DV.CE): This subfeature shows recent camera events with face
detection results, snapshot images, and classification labels.
6.5.2 Test Cases
TC ID Requirements Priority Scenario Description
DV.RS.01 2.3.2 H Verify real-time
sensor values are
displayed on the
dashboard
DV.RS.02 2.3.2 M Verify sensor values
update when new
readings arrive
DV.HC.01 2.3.2 H Verify historical
temperature chart
renders correctly
DV.HC.02 2.3.2 M Select a date range
and verify chart data
filters accordingly
DV.CE.01 2.2 H Verify latest camera
event with snapshot
is displayed
DV.CE.02 2.2 M Verify face
TC ID Requirements Priority Scenario Description
classification label is
shown for camera
events
6.6 Resident Management (RM)
6.6.1 Subfeatures to be tested
● Add Resident (RM.AR): This subfeature allows users to add a new resident with a name
and optional photo through the mobile app or web dashboard.
● Delete Resident (RM.DR): This subfeature allows users to remove a resident from the
system.
● Embedding Sync (RM.ES): This subfeature automatically computes face embeddings for
newly uploaded resident photos and syncs them to the edge device.
6.6.2 Test Cases
TC ID Requirements Priority Scenario Description
RM.AR.01 2.4.3 H Add a new resident
with name and photo
and verify database
entry
RM.AR.02 2.4.3 M Add a resident
without a photo and
verify entry is created
RM.DR.01 2.4.3 H Delete a resident and
verify removal from
database
RM.ES.01 2.4.3 H Upload resident
TC ID Requirements Priority Scenario Description
photo and verify
embedding is
computed
automatically
RM.ES.02 2.4.3 H Verify edge device
syncs updated
resident embeddings
7. DETAILED TEST CASES
7.1 UA.EP.01
TC_ID UA.EP.
Purpose Verify that a user can log in with valid email and password.
Requirements 2.
Priority High
Estimated Time
Needed
3 Minutes
Dependency A user account must be registered in Supabase.
Setup The application is running and the login screen is displayed.
Procedure [A01] Open the mobile app or web dashboard.
[A02] Enter a valid registered email address.
[A03] Enter the correct password for this account.
[A04] Tap/click the “Sign In” button.
[V01] Observe that the login is successful and the dashboard screen
appears.
Cleanup Sign out.

7.2 UA.EP.02
TC_ID UA.EP.
Purpose Verify that login fails when password is blank.
Requirements 2.
Priority High
Estimated Time
Needed
2 Minutes
Dependency None.
Setup The login screen is displayed.
Procedure [A01] Enter a valid email address.
[A02] Leave the password field blank.
[A03] Tap/click the “Sign In” button.
[V01] Observe that an error message is displayed.
[V02] Verify that the user remains on the login screen.
Cleanup None.

7.3 UA.EP.03
TC_ID UA.EP.
Purpose Verify that an invalid email format is rejected.
Requirements 2.
Priority Medium

Estimated Time
Needed
2 Minutes
Dependency None.
Setup The login screen is displayed.
Procedure [A01] Enter an invalid email format (e.g., “abc@”).
[A02] Enter any password.
[A03] Tap/click the “Sign In” button.
[V01] Verify that a validation error message is displayed.
Cleanup None.

7.4 UA.SO.01
TC_ID UA.SO.
Purpose Verify that the user can sign out and is redirected to the login screen.
Requirements 2.
Priority High
Estimated Time
Needed
2 Minutes
Dependency UA.EP.01 should pass.
Setup The user is logged in and on the dashboard.
Procedure [A01] Navigate to the Settings screen.
[A02] Tap/click the “Sign Out” button.
[V01] Observe that the user is redirected to the login screen.
[V02] Verify that the session is cleared.
Cleanup None.

7.5 SM.CT.01
TC_ID SM.CT.
Purpose Verify that temperature and humidity readings are transmitted at the
configured interval.
Requirements 2.1.
Priority High
Estimated Time
Needed
5 Minutes
Dependency Edge device must be running with DHT11 sensor connected.
Setup The Raspberry Pi edge controller is powered on and the FastAPI
gateway is running.
Procedure [A01] Start the edge controller (run_edge.py).
[A02] Wait for two climate intervals (default 60s each).
[V01] Check the Supabase sensor_readings table for new entries.
[V02] Verify that temperature and humidity readings are recorded
with timestamps.
[V03] Verify that the interval between readings matches the
configured CLIMATE_INTERVAL_SECONDS.
Cleanup None.

7.6 SM.CT.02
TC_ID SM.CT.
Purpose Verify that sensor readings appear on the dashboard within 1 minute.
Requirements 2.1.

Priority High
Estimated Time
Needed
3 Minutes
Dependency SM.CT.01 should pass.
Setup Edge device is running and the dashboard is open.
Procedure [A01] Open the web dashboard or mobile app dashboard.
[A02] Wait for a new sensor reading cycle.
[V01] Verify that the displayed temperature and humidity values
update.
[V02] Verify the latency is less than 1 minute.
Cleanup None.

7.7 SM.GD.01
TC_ID SM.GD.
Purpose Verify that gas/smoke detection triggers a state change report.
Requirements 2.1.
Priority High
Estimated Time
Needed
3 Minutes
Dependency Edge device must be running with MQ-2 sensor connected.
Setup The edge controller is running and gas sensor reads “NO GAS”.
Procedure [A01] Simulate gas detection by triggering the MQ-2 sensor.
[V01] Verify that the edge controller logs “Gas: ALERT”.
[V02] Verify that a fire_alert event is created in the events table.

[V03] Verify that the alert severity is “critical”.
Cleanup Clear the gas condition.

7.8 EA.FA.01
TC_ID EA.FA.
Purpose Verify that a critical alert is created in the database when gas is
detected.
Requirements 2.1.
Priority High
Estimated Time
Needed
3 Minutes
Dependency SM.GD.01 should pass.
Setup Edge controller is running in normal state.
Procedure [A01] Trigger the MQ-2 gas sensor.
[V01] Query the Supabase events table.
[V02] Verify a new event with event_type “fire_alert” and priority
“critical” exists.
[V03] Verify the event message contains “Gas/smoke detected”.
Cleanup Clear gas condition.

7.9 EA.ND.01
TC_ID EA.ND.
Purpose Verify that a push notification is received on the mobile device for a
fire alert.

Requirements 2.4.1
Priority High
Estimated Time
Needed
5 Minutes
Dependency EA.FA.01 should pass. The mobile app must be installed with
notifications enabled.
Setup Mobile app is installed and user is logged in. App may be in
background.
Procedure [A01] Trigger a gas detection event on the edge device.
[V01] Observe the mobile device for a push notification.
[V02] Verify the notification appears with audible/vibration alert.
[V03] Verify the notification content states the event type.
Cleanup Dismiss the notification.
7.10 EA.AK.01
TC_ID EA.AK.01
Purpose Verify that acknowledging an alert updates its status in the database.
Requirements 2.4
Priority High
Estimated Time
Needed
3 Minutes
Dependency EA.FA.01 should pass.
Setup An unacknowledged alert exists in the system.
Procedure [A01] Open the Alerts screen on the mobile app or web dashboard.
[A02] Tap/click the acknowledge button on an active alert.
[V01] Verify the alert status changes to “acknowledged” in the UI.
[V02] Query the events table and verify the acknowledged field is
true.
Cleanup None.
7.11 FR.MC.01
TC_ID FR.MC.01
Purpose Verify that the camera captures burst images when motion is detected.
Requirements 2.2.1
Priority High
Estimated Time
Needed
5 Minutes
Dependency Edge device with PIR sensor and camera module connected.
Setup The edge controller is running and no motion is active.
Procedure [A01] Trigger the PIR motion sensor by moving in front of it.
[V01] Observe the edge controller log for “DETECTED” motion
state.
[V02] Verify that burst images are captured (check data/ directory).
[V03] Verify the number of captured images matches
BURST_COUNT configuration.
Cleanup Remove captured test images.
7.12 FR.FD.01
TC_ID FR.FD.01
Purpose Verify that the face detection pipeline identifies faces in captured
images.
Requirements 2.2.2
Priority High
Estimated Time
Needed
5 Minutes
Dependency FR.MC.01 should pass.
Setup Edge controller is running with camera active.
Procedure [A01] Stand in front of the camera and trigger motion.
[V01] Observe edge logs for face detection results.
[V02] Verify that the log reports the number of faces detected.
[V03] Verify that bounding box coordinates are logged for each face.
Cleanup None.
7.13 FR.FM.01
TC_ID FR.FM.01
Purpose Verify that a registered resident is classified as “authorized”.
Requirements 2.2.2
Priority High
Estimated Time
Needed
5 Minutes
Dependency FR.FD.01 should pass. RM.ES.01 should pass.
Setup A resident is registered with a valid face embedding in the system.
Procedure [A01] The registered resident stands in front of the camera.
[A02] Trigger motion detection.
[V01] Observe the edge logs for face matching results.
[V02] Verify the status is “authorized”.
[V03] Verify the recognized name matches the resident’s name.
[V04] Verify the match score (Euclidean distance) is below the
threshold (0.55).
Cleanup None.
7.14 FR.FM.02
TC_ID FR.FM.02
Purpose Verify that an unregistered person is classified as “unauthorized”.
Requirements 2.2.2
Priority High
Estimated Time
Needed
5 Minutes
Dependency FR.FD.01 should pass.
Setup The person in front of the camera is NOT registered in the residents
database.
Procedure [A01] An unregistered person stands in front of the camera.
[A02] Trigger motion detection.
[V01] Observe the edge logs for face matching results.
[V02] Verify the status is “unauthorized”.
[V03] Verify that a “stranger_detected” security event is created.
Cleanup None.
7.15 FR.SU.01
TC_ID FR.SU.01
Purpose Verify that a security event with snapshot is uploaded to Supabase.
Requirements 2.2.2
Priority High
Estimated Time
Needed
5 Minutes
Dependency FR.FM.01 or FR.FM.02 should pass.
Setup The edge device is online and connected to the FastAPI gateway.
Procedure [A01] Trigger a face recognition event (motion + face detected).
[V01] Query the Supabase events table for a new security event.
[V02] Query the camera_events table for a snapshot_path entry.
[V03] Verify the image exists in the Supabase Storage bucket.
[V04] Verify the event_faces table contains the classification result.
Cleanup None.
7.16 DV.RS.01
TC_ID DV.RS.01
Purpose Verify that real-time sensor values are displayed on the dashboard.
Requirements 2.3.2
Priority High
Estimated Time
Needed
3 Minutes
Dependency SM.CT.01 should pass. User must be authenticated.
Setup The edge device is sending telemetry and the user is logged in.
Procedure [A01] Open the dashboard (web or mobile).
[V01] Observe the temperature reading widget.
[V02] Observe the humidity reading widget.
[V03] Verify that the displayed values are within expected ranges.
[V04] Verify that gas and soil moisture statuses are displayed.
Cleanup None.
7.17 DV.HC.01
TC_ID DV.HC.01
Purpose Verify that historical sensor data is rendered as a chart.
Requirements 2.3.2
Priority High
Estimated Time
Needed
3 Minutes
Dependency Multiple sensor readings must exist in the database.
Setup The user is logged in and navigates to the history page.
Procedure [A01] Navigate to the History screen.
[V01] Verify that a line chart is displayed for temperature data.
[V02] Verify that data points correspond to stored sensor readings.
Cleanup None.
7.18 DV.CE.01
TC_ID DV.CE.01
Purpose Verify that the latest camera event with snapshot is displayed.
Requirements 2.2
Priority High
Estimated Time
Needed
3 Minutes
Dependency FR.SU.01 should pass.
Setup A camera event with snapshot exists in the database.
Procedure [A01] Open the Camera screen on the mobile app or web dashboard.
[V01] Verify that the latest camera event is listed.
[V02] Verify that the snapshot image is loaded and visible.
[V03] Verify that the face classification label is displayed (e.g.,
“Resident” or “Unknown”).
Cleanup None.
7.19 RM.AR.01
TC_ID RM.AR.01
Purpose Verify that a new resident can be added with name and photo.
Requirements 2.4.3
Priority High
Estimated Time
Needed
5 Minutes
Dependency User must be authenticated.
Setup The user is on the Residents screen.
Procedure [A01] Navigate to the Residents screen.
[A02] Tap/click “Add Resident”.
[A03] Enter the resident’s name.
[A04] Upload a face photo.
[A05] Confirm the addition.
[V01] Verify that the new resident appears in the residents list.
[V02] Query the Supabase residents table and confirm the entry
exists.
[V03] Verify that the photo is uploaded to Supabase Storage.
Cleanup Delete the test resident if needed.
7.20 RM.DR.01
TC_ID RM.DR.01
Purpose Verify that a resident can be deleted from the system.
Requirements 2.4.3
Priority High
Estimated Time
Needed
3 Minutes
Dependency RM.AR.01 should pass.
Setup A test resident exists in the system.
Procedure [A01] Navigate to the Residents screen.
[A02] Select the test resident.
[A03] Tap/click the delete option.
[A04] Confirm the deletion.
[V01] Verify the resident is removed from the UI list.
[V02] Query the Supabase residents table and confirm the entry is
deleted.
Cleanup None.
7.21 RM.ES.01
TC_ID RM.ES.01
Purpose Verify that face embedding is automatically computed for uploaded
resident photos.
Requirements 2.4.3
Priority High
Estimated Time
Needed
5 Minutes
Dependency RM.AR.01 should pass. FastAPI gateway must be running.
Setup A resident with a photo but no embedding exists.
Procedure [A01] Add a new resident with a valid face photo.
[A02] Wait for the resident embedding backfill thread to run.
[V01] Query the Supabase residents table for the new resident.
[V02] Verify that the embedding field is populated with a
128-dimensional vector.
Cleanup None.
7.22 RM.ES.02
TC_ID RM.ES.02
Purpose Verify that the edge device syncs updated resident embeddings from
the cloud.
Requirements 2.4.3
Priority High
Estimated Time
Needed
5 Minutes
Dependency RM.ES.01 should pass. Edge device must be running.
Setup A resident with a computed embedding exists in Supabase.
Procedure [A01] Ensure the edge controller is running with resident sync thread
active.
[A02] Wait for the sync interval to elapse (default 60s).
[V01] Check the local residents.json file on the Raspberry Pi.
[V02] Verify that the newly embedded resident appears in the local
file.
[V03] Verify that the resident’s embedding data matches the cloud
data.
Cleanup None.
7.23 SM.GD.02
TC_ID SM.GD.02
Purpose Verify that a “cleared” alert is sent when the gas condition ends.
Requirements 2.1.2
Priority Medium
Estimated Time
Needed
3 Minutes
Dependency SM.GD.01 should pass.
Setup The edge controller is running and gas sensor currently reads
“ALERT”.
Procedure [A01] Remove the gas source from the MQ-2 sensor.
[A02] Wait for the sensor state to transition to “NO GAS”.
[V01] Verify the edge controller logs the state change to “NO GAS”.
[V02] Query the Supabase events table for a “fire_alert_cleared”
event.
[V03] Verify the alert severity is “info”.
Cleanup None.
7.24 SM.SM.01
TC_ID SM.SM.01
Purpose Verify that dry soil state triggers a low moisture alert.
Requirements 2.1.6
Priority High
Estimated Time
Needed
3 Minutes
Dependency Edge device must be running with soil moisture sensor connected.
Setup The edge controller is running and soil sensor reads “WET”.
Procedure [A01] Remove the sensor from moist soil to simulate a dry condition.
[V01] Verify the edge controller logs “Soil: DRY”.
[V02] Query the Supabase events table for a “low_moisture” event.
[V03] Verify the alert severity is “warning” and the message contains
“critically low”.
Cleanup Restore the sensor to moist soil.
7.25 SM.SM.02
TC_ID SM.SM.02
Purpose Verify that a “moisture restored” notification is sent after re-watering.
Requirements 2.1.6
Priority Medium
Estimated Time
Needed
3 Minutes
Dependency SM.SM.01 should pass.
Setup The edge controller is running and soil sensor currently reads “DRY”.
Procedure [A01] Place the sensor back into moist soil.
[A02] Wait for the sensor state to transition to “WET”.
[V01] Verify the edge controller logs “Soil: WET”.
[V02] Query the Supabase events table for a “moisture_restored”
event.
[V03] Verify the alert severity is “info”.
Cleanup None.
7.26 EA.FA.02
TC_ID EA.FA.02
Purpose Verify that the alert notification latency is under 5 seconds.
Requirements 2.1.2
Priority High
Estimated Time
Needed
5 Minutes
Dependency EA.FA.01 and EA.ND.01 should pass.
Setup Edge controller is running. Mobile app is installed.
Procedure [A01] Record the current time (T1).
[A02] Trigger the MQ-2 gas sensor.
[V01] Observe the mobile device for the push notification arrival and
record time (T2).
[V02] Calculate the latency: T2 - T1.
[V03] Verify the latency is under 5 seconds.
Cleanup Clear the gas condition.
7.27 EA.ND.02
TC_ID EA.ND.02
Purpose Verify that notification content includes event type and timestamp.
Requirements 2.4.1
Priority Medium
Estimated Time
Needed
3 Minutes
Dependency EA.ND.01 should pass.
Setup Mobile app is installed and user is logged in.
Procedure [A01] Trigger a critical event.
[A02] Wait for the push notification to arrive.
[V01] Expand the notification and read its content.
[V02] Verify the notification body includes the event type.
[V03] Verify the notification includes a timestamp or time reference.
Cleanup Dismiss the notification.
7.28 FR.MC.02
TC_ID FR.MC.02
Purpose Verify that the motion cooldown prevents excessive captures.
Requirements 2.2.1
Priority Medium
Estimated Time
Needed
5 Minutes
Dependency FR.MC.01 should pass.
Setup The edge controller is running.
Procedure [A01] Trigger the PIR sensor to cause a first burst capture.
[A02] Immediately trigger the PIR sensor again within the cooldown
period.
[V01] Verify that the first burst capture occurs normally.
[V02] Verify that the second trigger does NOT start a new burst
capture.
[V03] Wait for the cooldown to expire, trigger again, and verify a new
capture occurs.
Cleanup None.
7.29 FR.FD.02
TC_ID FR.FD.02
Purpose Verify that frames without faces are correctly skipped.
Requirements 2.2.2
Priority Medium
Estimated Time
Needed
5 Minutes
Dependency FR.MC.01 should pass.
Setup Edge controller is running. No person is in front of the camera.
Procedure [A01] Trigger motion detection by moving an object (not a person).
[V01] Observe edge logs for the burst capture.
[V02] Verify the log reports “No face in burst — skipping cloud
upload.”
[V03] Verify that no security event or snapshot upload is triggered.
Cleanup None.
7.30 FR.FM.03
TC_ID FR.FM.03
Purpose Verify that the match score is below the threshold (0.55) for
authorized persons.
Requirements 2.2.2
Priority Medium
Estimated Time
Needed
5 Minutes
Dependency FR.FM.01 should pass.
Setup A registered resident exists. Edge controller is running.
Procedure [A01] The registered resident stands in front of the camera.
[A02] Trigger motion detection.
[V01] Observe the edge logs for the face matching result.
[V02] Extract the Euclidean distance score from the log.
[V03] Verify that the score is less than or equal to 0.55.
Cleanup None.

7.31 FR.SU.02
TC_ID FR.SU.02
Purpose Verify that unauthorized detection triggers an intrusion alert
notification.
Requirements 2.2.2
Priority High
Estimated Time
Needed
5 Minutes
Dependency FR.FM.02 and EA.ND.01 should pass.
Setup Edge controller is running. Mobile app is installed.
Procedure [A01] An unregistered person stands in front of the camera.
[A02] Trigger motion detection.
[V01] Verify a “stranger_detected” security event is created.
[V02] Verify a push notification is received on the mobile device.
[V03] Verify the notification content indicates an unauthorized person
was detected.
Cleanup None.

7.32 DV.RS.02
TC_ID DV.RS.02
Purpose Verify that sensor values update on the dashboard when new readings
arrive.
Requirements 2.3.2
Priority Medium
Estimated Time
Needed
5 Minutes
Dependency DV.RS.01 should pass.
Setup User logged in and dashboard open.
Procedure [A01] Note the current temperature and humidity values displayed.
[A02] Wait for the next sensor reading cycle to complete (default
60s).
[V01] Verify that the displayed values are refreshed with the new
reading.
[V02] Verify the timestamp of the displayed reading has been
updated.
Cleanup None.
7.33 DV.HC.02
TC_ID DV.HC.02
Purpose Verify that selecting a date range filters the historical chart data
accordingly.
Requirements 2.3.2
Priority Medium
Estimated Time
Needed
3 Minutes
Dependency DV.HC.01 should pass.
Setup The user is logged in and on the History screen.
Procedure [A01] Select a specific date range using the date filter controls.
[V01] Verify the chart re-renders to show only data within the selected
range.
[A02] Change the date range to a different period.
[V02] Verify the chart updates to reflect the new range.
Cleanup None.
7.34 DV.CE.02
TC_ID DV.CE.02
Purpose Verify that the face classification label is shown for camera events.
Requirements 2.2
Priority Medium
Estimated Time
Needed
3 Minutes
Dependency DV.CE.01 should pass.
Setup Camera events with both classifications exist.
Procedure [A01] Open the Camera screen.
[V01] Locate a camera event where the person was classified as a
resident.
[V02] Verify the label displays the resident’s name.
[V03] Locate a camera event where the person was classified as
unknown.
[V04] Verify the label displays “Unknown” or “Unauthorized”.
Cleanup None.
7.35 RM.AR.02
TC_ID RM.AR.02
Purpose Verify that a resident can be added without a photo.
Requirements 2.4.3
Priority Medium
Estimated Time
Needed
3 Minutes
Dependency User must be authenticated.
Setup The user is on the Residents screen.
Procedure [A01] Navigate to the Residents screen.
[A02] Tap/click “Add Resident”.
[A03] Enter only the resident’s name without uploading a photo.
[A04] Confirm the addition.
[V01] Verify the new resident appears in the residents list.
[V02] Query the Supabase residents table and confirm the entry exists
with a null photo_path.
[V03] Verify the embedding field remains null (no photo to compute
from).
Cleanup Delete the test resident if needed.