import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/environment_data.dart';
import '../models/face_capture.dart';

class SupabaseDataService {
  static final _client = Supabase.instance.client;

  // ─── SENSOR READINGS ────────────────────────────────────────

  /// Fetches raw sensor readings, optionally filtered by sensor type.
  static Future<List<SensorReading>> getSensorReadings({
    String? sensorType,
    int limit = 500,
  }) async {
    var query = _client
        .from(SupabaseConfig.sensorReadingsTable)
        .select();

    if (sensorType != null) {
      query = query.eq('sensor_type', sensorType);
    }

    final data = await query
        .order('recorded_at', ascending: false)
        .limit(limit);

    return (data as List).map((e) => SensorReading.fromJson(e)).toList();
  }

  /// Fetches the latest reading for each sensor type.
  static Future<Map<String, SensorReading>> getLatestPerSensorType() async {
    final types = ['temperature', 'humidity', 'smoke', 'water'];
    final result = <String, SensorReading>{};

    final futures = types.map((type) async {
      final data = await _client
          .from(SupabaseConfig.sensorReadingsTable)
          .select()
          .eq('sensor_type', type)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data != null) {
        result[type] = SensorReading.fromJson(data);
      }
    });

    await Future.wait(futures);
    return result;
  }

  // ─── CAMERA EVENTS (with face joins) ────────────────────────

  static Future<List<Map<String, dynamic>>> getCameraEvents({
    int limit = 20,
  }) async {
    final data = await _client
        .from(SupabaseConfig.cameraEventsTable)
        .select('*, event_faces(*, residents(name, id))')
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>?> getLatestCameraEvent() async {
    final data = await _client
        .from(SupabaseConfig.cameraEventsTable)
        .select('*, event_faces(*, residents(name, id))')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return data;
  }

  // ─── EVENTS / ALERTS ───────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getEvents({
    int limit = 50,
  }) async {
    final data = await _client
        .from(SupabaseConfig.eventsTable)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> acknowledgeEvent(String id) async {
    await _client
        .from(SupabaseConfig.eventsTable)
        .update({'acknowledged': true}).eq('id', id);
  }

  // ─── RESIDENTS ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getResidents() async {
    final data = await _client
        .from(SupabaseConfig.residentsTable)
        .select('*, resident_faces(*)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> addResident({
    required String name,
    required String userId,
    String? photoPath,
  }) async {
    await _client.from(SupabaseConfig.residentsTable).insert({
      'name': name,
      'user_id': userId,
      if (photoPath != null) 'photo_path': photoPath,
    });
  }

  static Future<void> updateResident(
      String id, Map<String, dynamic> updates) async {
    await _client
        .from(SupabaseConfig.residentsTable)
        .update(updates)
        .eq('id', id);
  }

  static Future<void> deleteResident(String id) async {
    await _client.from(SupabaseConfig.residentsTable).delete().eq('id', id);
  }

  // ─── DEVICES ────────────────────────────────────────────────

  /// Returns the device registry (id, name, room).
  ///
  /// The `room` column is set by [updateDeviceRoom] when the user
  /// reassigns a device on the floor plan. When null/empty the UI
  /// falls back to the heuristic `_resolveRoom(device.name)`.
  static Future<List<Map<String, dynamic>>> getDevices() async {
    final data = await _client
        .from(SupabaseConfig.devicesTable)
        .select('id, name, room')
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Reassigns a device to a different room on the floor plan.
  static Future<void> updateDeviceRoom(String deviceId, String room) async {
    await _client
        .from(SupabaseConfig.devicesTable)
        .update({'room': room}).eq('id', deviceId);
  }

  // ─── FACE CAPTURES (legacy compat) ─────────────────────────

  static Future<List<FaceCapture>> getFaceCaptures({int limit = 20}) async {
    try {
      final data = await _client
          .from(SupabaseConfig.eventFacesTable)
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).map((e) => FaceCapture.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }
}
