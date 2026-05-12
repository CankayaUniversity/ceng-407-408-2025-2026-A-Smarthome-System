import 'dart:async';
import 'package:flutter/material.dart';
import '../models/environment_data.dart';
import '../models/face_capture.dart';
import '../services/supabase_data_service.dart';

class SupabaseDataProvider extends ChangeNotifier {
  List<SensorReading> _sensorReadings = [];
  Map<String, SensorReading> _latestPerType = {};
  List<FaceCapture> _faceCaptures = [];
  List<Map<String, dynamic>> _cameraEvents = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _residents = [];
  List<Map<String, dynamic>> _devices = [];
  Map<String, dynamic>? _latestCameraEvent;
  bool _loading = false;
  String? _error;

  List<SensorReading> get sensorReadings =>
      List.unmodifiable(_sensorReadings);
  Map<String, SensorReading> get latestPerType =>
      Map.unmodifiable(_latestPerType);
  List<FaceCapture> get faceCaptures => List.unmodifiable(_faceCaptures);
  List<Map<String, dynamic>> get cameraEvents =>
      List.unmodifiable(_cameraEvents);
  List<Map<String, dynamic>> get events => List.unmodifiable(_events);
  List<Map<String, dynamic>> get residents => List.unmodifiable(_residents);
  List<Map<String, dynamic>> get devices => List.unmodifiable(_devices);
  Map<String, dynamic>? get latestCameraEvent => _latestCameraEvent;
  bool get loading => _loading;
  String? get error => _error;

  Map<String, Map<String, dynamic>> get devicesById => {
        for (final d in _devices)
          if (d['id'] != null) d['id'].toString(): d
      };

  SensorReading? get latestTemperature => _latestPerType['temperature'];
  SensorReading? get latestHumidity => _latestPerType['humidity'];
  SensorReading? get latestSmoke => _latestPerType['smoke'];
  SensorReading? get latestWater => _latestPerType['water'];

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

  List<SensorReading> get smokeReadings => latestPerDeviceAndType
      .where((r) => r.sensorType == 'smoke')
      .toList();

  List<SensorReading> get waterReadings => latestPerDeviceAndType
      .where((r) => r.sensorType == 'water')
      .toList();

  List<SensorReading> get temperatureReadings => latestPerDeviceAndType
      .where((r) => r.sensorType == 'temperature')
      .toList();

  List<SensorReading> get humidityReadings => latestPerDeviceAndType
      .where((r) => r.sensorType == 'humidity')
      .toList();

  List<SensorReading> get motionReadings => latestPerDeviceAndType
      .where((r) => r.sensorType == 'motion')
      .toList();

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
        _sensorReadings =
            await SupabaseDataService.getSensorReadings(limit: 2000);
      }, errors),
      _safeFetch('latest_per_type', () async {
        _latestPerType = await SupabaseDataService.getLatestPerSensorType();
      }, errors),
      _safeFetch('face_captures', () async {
        _faceCaptures =
            await SupabaseDataService.getFaceCaptures(limit: 20);
      }, errors),
      _safeFetch('camera_events', () async {
        _cameraEvents =
            await SupabaseDataService.getCameraEvents(limit: 20);
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
    ]);

    if (errors.length == 7) {
      _error = 'Failed to load data. Pull to refresh.';
    } else if (errors.isNotEmpty) {
      debugPrint('SupabaseDataProvider partial errors: $errors');
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> _safeFetch(
      String label, Future<void> Function() fn, List<String> errors) async {
    try {
      await fn();
    } catch (e) {
      debugPrint('SupabaseDataProvider.$label failed: $e');
      errors.add(label);
    }
  }

  List<SensorReading> readingsForType(String sensorType) {
    return _sensorReadings
        .where((r) => r.sensorType == sensorType)
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

  Future<void> fetchEvents({int limit = 50}) async {
    try {
      _events = await SupabaseDataService.getEvents(limit: limit);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchResidents() async {
    try {
      _residents = await SupabaseDataService.getResidents();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchFaceCaptures({int limit = 20}) async {
    try {
      _faceCaptures =
          await SupabaseDataService.getFaceCaptures(limit: limit);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchDevices() async {
    try {
      _devices = await SupabaseDataService.getDevices();
      notifyListeners();
    } catch (_) {}
  }

  /// Optimistic device → room reassignment with rollback on error.
  /// Web parity with `RoomsPage.assignDeviceRoom`.
  Future<bool> assignDeviceRoom(String deviceId, String room) async {
    final prev = List<Map<String, dynamic>>.from(_devices);
    _devices = _devices
        .map((d) => d['id']?.toString() == deviceId
            ? {...d, 'room': room}
            : d)
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
    _cameraEvents.insert(0, row);
    if (_cameraEvents.length > 20) _cameraEvents.removeLast();
    _latestCameraEvent = row;
    notifyListeners();
  }

  void prependEvent(Map<String, dynamic> row) {
    _events.insert(0, row);
    if (_events.length > 50) _events.removeLast();
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
