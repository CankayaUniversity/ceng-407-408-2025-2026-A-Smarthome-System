import 'dart:async';
import 'package:flutter/material.dart';
import '../models/environment_data.dart';
import '../models/face_capture.dart';
import '../services/supabase_data_service.dart';
import '../utils/event_meta.dart';

class SupabaseDataProvider extends ChangeNotifier {
  List<SensorReading> _sensorReadings = [];
  Map<String, SensorReading> _latestPerType = {};
  List<FaceCapture> _faceCaptures = [];
  List<Map<String, dynamic>> _cameraEvents = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _residents = [];
  List<Map<String, dynamic>> _devices = [];
  Map<String, dynamic>? _latestCameraEvent;
  Map<String, dynamic>? _household;
  bool _loading = false;
  String? _error;

  List<SensorReading> get sensorReadings => List.unmodifiable(_sensorReadings);
  Map<String, SensorReading> get latestPerType =>
      Map.unmodifiable(_latestPerType);
  List<FaceCapture> get faceCaptures => List.unmodifiable(_faceCaptures);
  List<Map<String, dynamic>> get cameraEvents =>
      List.unmodifiable(_cameraEvents);
  List<Map<String, dynamic>> get events => List.unmodifiable(_events);
  List<Map<String, dynamic>> get residents => List.unmodifiable(_residents);
  List<Map<String, dynamic>> get devices => List.unmodifiable(_devices);
  Map<String, dynamic>? get latestCameraEvent => _latestCameraEvent;

  /// Singleton household row (web parity: `household_settings` id=1).
  /// Null while loading or when the row has not been seeded.
  Map<String, dynamic>? get household => _household;

  /// Web parity: `Sidebar.jsx` reads `household_settings.name` and falls
  /// back to "My Home" when null.
  String get householdName {
    final n = _household?['name']?.toString().trim();
    return (n != null && n.isNotEmpty) ? n : 'My Home';
  }

  /// Web parity: `SettingsPage.jsx` household address field.
  String get householdAddress {
    return _household?['address']?.toString() ?? '';
  }

  bool get loading => _loading;
  String? get error => _error;

  List<Map<String, dynamic>> get activeEvents =>
      _events.where((e) => !isEventResolved(e)).toList();

  int get activeCriticalEventCount => activeEvents
      .where((e) => e['priority']?.toString().toLowerCase() == 'critical')
      .length;

  Map<String, Map<String, dynamic>> get devicesById => {
    for (final d in _devices)
      if (d['id'] != null) d['id'].toString(): d,
  };

  SensorReading? get latestTemperature => _latestPerType['temperature'];
  SensorReading? get latestHumidity => _latestPerType['humidity'];
  SensorReading? get latestSmoke => _latestPerType['smoke'];
  SensorReading? get latestSoilMoisture =>
      _latestPerType['soil_moisture'] ?? _latestPerType['water'];

  /// Returns latest reading per (device_id, sensor_type) pair.
  /// Web parity with `DashboardPage.fetchData` `latestByType` map.
  List<SensorReading> get latestPerDeviceAndType {
    final byKey = <String, SensorReading>{};
    for (final r in _sensorReadings) {
      final key = '${r.deviceId ?? '_'}_${r.sensorType}';
      final existing = byKey[key];
      if (existing == null || r.recordedAt.isAfter(existing.recordedAt)) {
        byKey[key] = r;
      }
    }
    return byKey.values.toList();
  }

  List<SensorReading> get smokeReadings =>
      latestPerDeviceAndType.where((r) => r.sensorType == 'smoke').toList();

  List<SensorReading> get soilMoistureReadings => latestPerDeviceAndType
      .where((r) => r.normalizedType == 'soil_moisture')
      .toList();

  @Deprecated('Use soilMoistureReadings')
  List<SensorReading> get waterReadings => soilMoistureReadings;

  List<SensorReading> get temperatureReadings => latestPerDeviceAndType
      .where((r) => r.sensorType == 'temperature')
      .toList();

  List<SensorReading> get humidityReadings =>
      latestPerDeviceAndType.where((r) => r.sensorType == 'humidity').toList();

  List<SensorReading> get motionReadings =>
      latestPerDeviceAndType.where((r) => r.sensorType == 'motion').toList();

  SupabaseDataProvider() {
    fetchAll();
  }

  Future<void> fetchAll() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final errors = <String>[];

    // Each query runs independently so one failure doesn't block others.
    await Future.wait([
      _safeFetch('sensor_readings', () async {
        _sensorReadings = await SupabaseDataService.getSensorReadings(
          limit: 2000,
        );
      }, errors),
      _safeFetch('latest_per_type', () async {
        _latestPerType = await SupabaseDataService.getLatestPerSensorType();
      }, errors),
      _safeFetch('face_captures', () async {
        _faceCaptures = await SupabaseDataService.getFaceCaptures(limit: 20);
      }, errors),
      _safeFetch('camera_events', () async {
        _cameraEvents = await SupabaseDataService.getCameraEvents(limit: 20);
        if (_cameraEvents.isNotEmpty) {
          _latestCameraEvent = _cameraEvents.first;
        }
      }, errors),
      _safeFetch('events', () async {
        _events = await SupabaseDataService.getEvents(limit: 50);
      }, errors),
      _safeFetch('residents', () async {
        _residents = await SupabaseDataService.getResidents();
      }, errors),
      _safeFetch('devices', () async {
        _devices = await SupabaseDataService.getDevices();
      }, errors),
      _safeFetch('household', () async {
        _household = await SupabaseDataService.fetchHouseholdSettings();
      }, errors),
    ]);

    if (errors.length == 8) {
      _error = 'Failed to load data. Pull to refresh.';
    } else if (errors.isNotEmpty) {
      debugPrint('SupabaseDataProvider partial errors: $errors');
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> _safeFetch(
    String label,
    Future<void> Function() fn,
    List<String> errors,
  ) async {
    try {
      await fn();
    } catch (e) {
      debugPrint('SupabaseDataProvider.$label failed: $e');
      errors.add(label);
    }
  }

  List<SensorReading> readingsForType(String sensorType) {
    final key = sensorType == 'water' ? 'soil_moisture' : sensorType;
    return _sensorReadings
        .where((r) => r.normalizedType == key)
        .toList();
  }

  Future<void> fetchCameraEvents({int limit = 20}) async {
    try {
      _cameraEvents = await SupabaseDataService.getCameraEvents(limit: limit);
      if (_cameraEvents.isNotEmpty) {
        _latestCameraEvent = _cameraEvents.first;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> fetchCameraEventById(String id) async {
    try {
      final row = await SupabaseDataService.getCameraEventById(id);
      if (row != null) {
        _upsertCameraEvent(row);
        notifyListeners();
      }
      return row;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchCameraEventForEventId(
    String eventId,
  ) async {
    try {
      final row = await SupabaseDataService.getCameraEventForEventId(eventId);
      if (row != null) {
        _upsertCameraEvent(row);
        notifyListeners();
      }
      return row;
    } catch (_) {
      return null;
    }
  }

  Future<void> fetchEvents({int limit = 50}) async {
    try {
      _events = await SupabaseDataService.getEvents(limit: limit);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> acknowledgeEvent(String id) async {
    if (id.isEmpty) return;
    await SupabaseDataService.acknowledgeEvent(id);
    _markEventsAcknowledged({id});
  }

  Future<int> acknowledgeAllActiveEvents() async {
    final ids = activeEvents
        .map((e) => e['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return 0;
    await SupabaseDataService.acknowledgeAllActiveEvents();
    _markEventsAcknowledged(ids);
    return ids.length;
  }

  Future<void> fetchResidents() async {
    try {
      _residents = await SupabaseDataService.getResidents();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchFaceCaptures({int limit = 20}) async {
    try {
      _faceCaptures = await SupabaseDataService.getFaceCaptures(limit: limit);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchDevices() async {
    try {
      _devices = await SupabaseDataService.getDevices();
      notifyListeners();
    } catch (_) {}
  }

  /// Refreshes the singleton `household_settings` row.
  Future<void> fetchHousehold() async {
    try {
      _household = await SupabaseDataService.fetchHouseholdSettings();
      notifyListeners();
    } catch (_) {}
  }

  /// Admin-only (RLS-enforced) household update. Optimistically patches the
  /// local cache so HomeScreen / Settings reflect the new name immediately,
  /// then reconciles with the server response. Returns the updated row, or
  /// throws so the caller can surface the error.
  Future<Map<String, dynamic>?> saveHousehold({
    String? name,
    String? address,
  }) async {
    final prev = _household == null
        ? null
        : Map<String, dynamic>.from(_household!);
    if (_household != null) {
      _household = {
        ..._household!,
        if (name != null) 'name': name,
        if (address != null) 'address': address,
      };
      notifyListeners();
    }
    try {
      final saved = await SupabaseDataService.updateHouseholdSettings(
        name: name,
        address: address,
      );
      if (saved != null) {
        _household = saved;
        notifyListeners();
      }
      return saved;
    } catch (e) {
      _household = prev;
      notifyListeners();
      rethrow;
    }
  }

  /// Optimistic device → room reassignment with rollback on error.
  /// Web parity with `RoomsPage.assignDeviceRoom`.
  Future<bool> assignDeviceRoom(String deviceId, String room) async {
    final prev = List<Map<String, dynamic>>.from(_devices);
    _devices = _devices
        .map((d) => d['id']?.toString() == deviceId ? {...d, 'room': room} : d)
        .toList();
    notifyListeners();
    try {
      await SupabaseDataService.updateDeviceRoom(deviceId, room);
      return true;
    } catch (e) {
      debugPrint('assignDeviceRoom failed: $e');
      _devices = prev;
      notifyListeners();
      return false;
    }
  }

  void prependCameraEvent(Map<String, dynamic> row) {
    _upsertCameraEvent(row);
    notifyListeners();
  }

  void prependEvent(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    final existing = id == null
        ? -1
        : _events.indexWhere((e) => e['id']?.toString() == id);
    if (existing >= 0) {
      _events[existing] = row;
    } else {
      _events.insert(0, row);
    }
    if (_events.length > 50) _events.removeLast();
    notifyListeners();
  }

  void _upsertCameraEvent(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    final existing = id == null
        ? -1
        : _cameraEvents.indexWhere((e) => e['id']?.toString() == id);
    if (existing >= 0) {
      _cameraEvents[existing] = row;
    } else {
      _cameraEvents.insert(0, row);
    }
    _cameraEvents.sort((a, b) {
      final at =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bt =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    if (_cameraEvents.length > 20) {
      _cameraEvents = _cameraEvents.take(20).toList();
    }
    _latestCameraEvent = _cameraEvents.isNotEmpty
        ? _cameraEvents.first
        : _latestCameraEvent;
  }

  void _markEventsAcknowledged(Set<String> ids) {
    final now = DateTime.now().toUtc().toIso8601String();
    _events = _events
        .map(
          (e) => ids.contains(e['id']?.toString())
              ? {
                  ...e,
                  'acknowledged': true,
                  'acknowledged_at': e['acknowledged_at'] ?? now,
                  'status': 'acknowledged',
                }
              : e,
        )
        .toList();
    notifyListeners();
  }

  void updateSensorFromRealtime(Map<String, dynamic> row) {
    try {
      final reading = SensorReading.fromJson(row);
      _sensorReadings.insert(0, reading);
      if (_sensorReadings.length > 2000) _sensorReadings.removeLast();
      _latestPerType[reading.sensorType] = reading;
      notifyListeners();
    } catch (_) {}
  }
}
