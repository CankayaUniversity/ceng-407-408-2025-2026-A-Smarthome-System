import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/environment_data.dart';
import '../models/face_capture.dart';
import '../utils/event_meta.dart';

class SupabaseDataService {
  static final _client = Supabase.instance.client;

  // ─── SENSOR READINGS ────────────────────────────────────────

  /// Fetches raw sensor readings, optionally filtered by sensor type.
  static Future<List<SensorReading>> getSensorReadings({
    String? sensorType,
    int limit = 500,
  }) async {
    var query = _client.from(SupabaseConfig.sensorReadingsTable).select();

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

  /// Web parity: `CameraPage.jsx` select. The nested
  /// `unknown_face_profiles(...)` brings the clustered identity payload so
  /// the UI can render labels like "Unknown #3 · 5x seen" via
  /// [face_display.getDetectionDisplayName].
  static const String _cameraEventSelect =
      '*, events(*), event_faces(*, residents(name, id), unknown_face_profiles(id, display_label, sighting_count, first_seen_at, status))';

  static Future<List<Map<String, dynamic>>> getCameraEvents({
    int limit = 20,
  }) async {
    final data = await _client
        .from(SupabaseConfig.cameraEventsTable)
        .select(_cameraEventSelect)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>?> getLatestCameraEvent() async {
    final data = await _client
        .from(SupabaseConfig.cameraEventsTable)
        .select(_cameraEventSelect)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return data;
  }

  static Future<Map<String, dynamic>?> getCameraEventById(String id) async {
    return await _client
        .from(SupabaseConfig.cameraEventsTable)
        .select(_cameraEventSelect)
        .eq('id', id)
        .maybeSingle();
  }

  static Future<Map<String, dynamic>?> getCameraEventForEventId(
    String eventId,
  ) async {
    return await _client
        .from(SupabaseConfig.cameraEventsTable)
        .select(_cameraEventSelect)
        .eq('event_id', eventId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  // ─── EVENTS / ALERTS ───────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getEvents({int limit = 50}) async {
    final data = await _client
        .from(SupabaseConfig.eventsTable)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> acknowledgeEvent(String id) async {
    await _updateEventAcknowledgement([id]);
  }

  static Future<int> acknowledgeAllActiveEvents({int limit = 500}) async {
    final rows = await getEvents(limit: limit);
    final ids = rows
        .where((e) => !isEventResolved(e))
        .map((e) => e['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return 0;
    await _updateEventAcknowledgement(ids);
    return ids.length;
  }

  static Future<void> _updateEventAcknowledgement(List<String> ids) async {
    if (ids.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await _client
          .from(SupabaseConfig.eventsTable)
          .update({
            'acknowledged': true,
            'acknowledged_at': now,
            'status': 'acknowledged',
          })
          .inFilter('id', ids);
    } on PostgrestException catch (e) {
      // Legacy schema fallback for deployments that only ran the initial
      // `acknowledged` column migration. Web/current DBs use the fields above.
      if (!e.message.toLowerCase().contains('acknowledged_at') &&
          !e.message.toLowerCase().contains('status')) {
        rethrow;
      }
      await _client
          .from(SupabaseConfig.eventsTable)
          .update({'acknowledged': true})
          .inFilter('id', ids);
    }
  }

  // ─── RESIDENTS ──────────────────────────────────────────────

  /// Web parity: `ResidentsPage.jsx` dropped the `resident_faces(*)` join.
  /// Photo lives in `residents.photo_path`; enrollment status is derived
  /// from `residents.embedding` (set by the FR pipeline, nulled when an
  /// admin replaces the enrollment via `assign_event_face_to_resident`).
  static Future<List<Map<String, dynamic>>> getResidents({
    bool includeAuthStatus = false,
  }) async {
    final data = await _client
        .from(SupabaseConfig.residentsTable)
        .select()
        .order('created_at', ascending: false);
    var rows = List<Map<String, dynamic>>.from(data);
    rows = await _attachLegacyAuthIdsByEmail(rows);
    if (includeAuthStatus) {
      rows = await attachResidentAuthStatus(rows);
    }
    return rows;
  }

  static Future<List<Map<String, dynamic>>> _attachLegacyAuthIdsByEmail(
    List<Map<String, dynamic>> rows,
  ) async {
    final emails = rows
        .where((r) => r['auth_user_id'] == null && r['account_email'] != null)
        .map((r) => r['account_email']?.toString().trim())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (emails.isEmpty) return rows;

    try {
      final profiles = await _client
          .from(SupabaseConfig.profilesTable)
          .select('id, email')
          .inFilter('email', emails);
      final byEmail = <String, String>{};
      for (final p in List<Map<String, dynamic>>.from(profiles)) {
        final email = p['email']?.toString().trim().toLowerCase();
        final id = p['id']?.toString();
        if (email != null && email.isNotEmpty && id != null) {
          byEmail[email] = id;
        }
      }
      return rows.map((r) {
        final email = r['account_email']?.toString().trim().toLowerCase();
        final id = email == null ? null : byEmail[email];
        return id == null ? r : {...r, 'auth_user_id': id};
      }).toList();
    } catch (_) {
      return rows;
    }
  }

  static Future<List<Map<String, dynamic>>> attachResidentAuthStatus(
    List<Map<String, dynamic>> rows,
  ) async {
    final userIds = rows
        .map((r) => r['auth_user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (userIds.isEmpty) return rows;

    try {
      final data = await _client.rpc(
        'get_auth_users_status',
        params: {'user_ids': userIds},
      );
      final byId = <String, Map<String, dynamic>>{};
      for (final row in List<Map<String, dynamic>>.from(data as List)) {
        final id = row['user_id']?.toString();
        if (id != null) byId[id] = row;
      }
      return rows.map((r) {
        final uid = r['auth_user_id']?.toString();
        return uid == null ? r : {...r, '_authStatus': byId[uid]};
      }).toList();
    } catch (_) {
      return rows;
    }
  }

  /// Inserts a resident and returns the inserted row id (so callers can link
  /// the row to a freshly created auth account via [updateResident]).
  ///
  /// When [authUserId] is provided up-front, it is written directly into
  /// `residents.auth_user_id` (web parity: `ResidentsPage.jsx` auth link).
  /// Returns null when the insert succeeded but no row was echoed back
  /// (defensive — RLS shouldn't strip it for the inserter).
  static Future<String?> addResident({
    required String name,
    String? userId,
    String? photoPath,
    String? accountEmail,
    String? authUserId,
  }) async {
    final inserted = await _client
        .from(SupabaseConfig.residentsTable)
        .insert({
          'name': name,
          'user_id': userId,
          if (photoPath != null) 'photo_path': photoPath,
          'account_email': accountEmail,
          if (authUserId != null) 'auth_user_id': authUserId,
        })
        .select('id')
        .maybeSingle();
    return inserted?['id']?.toString();
  }

  static Future<void> updateResident(
    String id,
    Map<String, dynamic> updates,
  ) async {
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
        .update({'room': room})
        .eq('id', deviceId);
  }

  // ─── HOUSEHOLD SETTINGS ────────────────────────────────────
  //
  // Web parity: single row keyed by id=1. RLS allows SELECT for any auth
  // user and UPDATE only for admins (see supabase_setup_v4.sql).

  /// Fetches the singleton household settings row (id=1). Returns null
  /// when the row does not exist yet (caller should default the name).
  static Future<Map<String, dynamic>?> fetchHouseholdSettings() async {
    return await _client
        .from(SupabaseConfig.householdSettingsTable)
        .select()
        .eq('id', 1)
        .maybeSingle();
  }

  /// Admin-only (RLS-enforced) update of the household name / address.
  /// At least one of [name] or [address] must be non-null.
  static Future<Map<String, dynamic>?> updateHouseholdSettings({
    String? name,
    String? address,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (address != null) payload['address'] = address;
    if (payload.isEmpty) return null;
    final res = await _client
        .from(SupabaseConfig.householdSettingsTable)
        .update(payload)
        .eq('id', 1)
        .select()
        .maybeSingle();
    return res;
  }

  // ─── FACE CAPTURES (legacy compat) ─────────────────────────
  // Loaded by SupabaseDataProvider but no screen reads faceCaptures yet.
  // Prefer camera_events + event_faces joins (see camera_screen.dart).
  // Safe to refactor when mobile identity review page is added.

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
