import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/supabase_embeds.dart';

/// Mobile parity for the web `IdentityPage.jsx` data layer.
///
/// Wraps:
///   * `unknown_face_profiles` / `unknown_face_sightings` / `face_label_actions`
///     reads (mirrors `EVENT_FACE_SELECT` and `ACTION_SELECT`).
///   * RPCs for assigning resident faces and managing visitor profiles
///     (admin-only by RLS).
///
/// All RPCs are SECURITY DEFINER and enforce admin via `profiles.role`, so
/// non-admins surface as Postgres errors which the caller should map to a
/// "View-only" toast.
class IdentityService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Same shape as web `EVENT_FACE_SELECT`.
  static const String _eventFaceSelect = SupabaseEmbeds.eventFaceRow;

  /// Same shape as web `ACTION_SELECT`.
  static const String _actionSelect = '''
id, action, created_at, metadata, event_face_id, to_resident_id, from_unknown_profile_id,
from_profile:unknown_face_profiles!from_unknown_profile_id(id, representative_snapshot_path),
to_resident:residents!to_resident_id(id, name, photo_path),
event_faces(
  id, classification, resident_id,
  camera_events(id, snapshot_path, created_at)
)
''';

  // ────────────────────────────────────────────────────────────────────
  // Reads
  // ────────────────────────────────────────────────────────────────────

  /// `unknown_face_profiles` rows still being reviewed (status = 'active').
  /// Ordered by recency for the left list of the Identity Review screen.
  static Future<List<Map<String, dynamic>>> fetchUnknownProfiles({
    int limit = 60,
  }) async {
    final data = await _client
        .from('unknown_face_profiles')
        .select()
        .eq('status', 'active')
        .order('last_seen_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Latest unknown `event_faces`. Web sorts by `camera_events.created_at`
  /// client-side and keeps the top 30; we mirror that ordering here.
  static Future<List<Map<String, dynamic>>> fetchRecentUnknownFaces({
    int fetchLimit = 40,
    int keep = 30,
  }) async {
    final raw = await _client
        .from('event_faces')
        .select(_eventFaceSelect)
        .eq('classification', 'unknown')
        .limit(fetchLimit);
    final faces = List<Map<String, dynamic>>.from(raw);
    faces.sort((a, b) {
      final ta = (a['camera_events'] is Map)
          ? (a['camera_events']['created_at']?.toString() ?? '')
          : '';
      final tb = (b['camera_events'] is Map)
          ? (b['camera_events']['created_at']?.toString() ?? '')
          : '';
      return tb.compareTo(ta);
    });
    return faces.take(keep).toList();
  }

  /// Manual correction history (assign / revert / unlink).
  static Future<List<Map<String, dynamic>>> fetchRecentActions({
    int limit = 40,
  }) async {
    final data = await _client
        .from('face_label_actions')
        .select(_actionSelect)
        .inFilter('action', const [
          'assign_resident',
          'revert_assign',
          'unlink_from_resident',
          'merge_profiles',
          'rename_profile',
          'move_sighting',
          'dismiss_profile',
        ])
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Sightings for the currently selected unknown profile.
  static Future<List<Map<String, dynamic>>> fetchProfileSightings(
    String profileId, {
    int limit = 50,
  }) async {
    final data = await _client
        .from('unknown_face_sightings')
        .select('''
id, match_distance, created_at,
camera_events(id, snapshot_path, created_at),
event_faces(id, classification, match_score)
''')
        .eq('unknown_face_profile_id', profileId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  /// `event_faces` already linked to a resident — used by the gallery
  /// "Resident linked detections" panel + "Not this person" unlink CTA.
  static Future<List<Map<String, dynamic>>> fetchResidentDetections(
    String residentId, {
    int limit = 60,
  }) async {
    final raw = await _client
        .from('event_faces')
        .select(_eventFaceSelect)
        .eq('resident_id', residentId)
        .eq('classification', 'resident')
        .order('id', ascending: false)
        .limit(limit);
    final faces = List<Map<String, dynamic>>.from(raw);
    faces.sort((a, b) {
      final ta = (a['camera_events'] is Map)
          ? (a['camera_events']['created_at']?.toString() ?? '')
          : '';
      final tb = (b['camera_events'] is Map)
          ? (b['camera_events']['created_at']?.toString() ?? '')
          : '';
      return tb.compareTo(ta);
    });
    return faces;
  }

  /// Slim residents list for the assign / gallery pickers.
  static Future<List<Map<String, dynamic>>> fetchResidentPickerList() async {
    final data = await _client
        .from('residents')
        .select('id, name, photo_path')
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  // ────────────────────────────────────────────────────────────────────
  // RPCs (admin-only via RLS / SECURITY DEFINER guard)
  // ────────────────────────────────────────────────────────────────────

  /// Assigns an unknown `event_faces` row to a resident. When
  /// [useSnapshotForEnrollment] is true, also rewrites the resident's
  /// `photo_path` from the detection snapshot and nulls `embedding` so the
  /// FR pipeline re-extracts it on next sight. Returns the raw RPC payload
  /// (`{ success, action_id, enrollment_updated, ... }`).
  static Future<Map<String, dynamic>> assignEventFaceToResident({
    required String eventFaceId,
    required String residentId,
    required bool useSnapshotForEnrollment,
  }) async {
    final data = await _client.rpc(
      'assign_event_face_to_resident',
      params: {
        'p_event_face_id': eventFaceId,
        'p_resident_id': residentId,
        'p_use_snapshot_for_enrollment': useSnapshotForEnrollment,
      },
    );
    return _coerceRpcResult(data);
  }

  /// Reverts a previous `assign_resident` action (matched by id). The RPC
  /// rejects already-reverted actions; bubble that error up to the UI.
  static Future<Map<String, dynamic>> revertFaceLabelAction(
    String actionId,
  ) async {
    final data = await _client.rpc(
      'revert_face_label_action',
      params: {'p_action_id': actionId},
    );
    return _coerceRpcResult(data);
  }

  /// Flips a resident-classified `event_faces` row back to unknown. The
  /// enrollment photo / embedding are intentionally left untouched.
  static Future<Map<String, dynamic>> unlinkEventFaceFromResident(
    String eventFaceId,
  ) async {
    final data = await _client.rpc(
      'unlink_event_face_from_resident',
      params: {'p_event_face_id': eventFaceId},
    );
    return _coerceRpcResult(data);
  }

  static Future<Map<String, dynamic>> renameUnknownFaceProfile({
    required String profileId,
    required String displayLabel,
  }) async {
    final data = await _client.rpc(
      'rename_unknown_face_profile',
      params: {'p_profile_id': profileId, 'p_display_label': displayLabel},
    );
    return _coerceRpcResult(data);
  }

  static Future<Map<String, dynamic>> mergeUnknownFaceProfiles({
    required String sourceProfileId,
    required String targetProfileId,
  }) async {
    final data = await _client.rpc(
      'merge_unknown_face_profiles',
      params: {
        'p_source_profile_id': sourceProfileId,
        'p_target_profile_id': targetProfileId,
      },
    );
    return _coerceRpcResult(data);
  }

  static Future<Map<String, dynamic>> moveEventFaceToUnknownProfile({
    required String eventFaceId,
    required String targetProfileId,
  }) async {
    final data = await _client.rpc(
      'move_event_face_to_unknown_profile',
      params: {
        'p_event_face_id': eventFaceId,
        'p_target_profile_id': targetProfileId,
      },
    );
    return _coerceRpcResult(data);
  }

  static Future<Map<String, dynamic>> ungroupEventFace(
    String eventFaceId,
  ) async {
    final data = await _client.rpc(
      'ungroup_event_face',
      params: {'p_event_face_id': eventFaceId},
    );
    return _coerceRpcResult(data);
  }

  static Future<Map<String, dynamic>> dismissUnknownFaceProfile(
    String profileId,
  ) async {
    final data = await _client.rpc(
      'dismiss_unknown_face_profile',
      params: {'p_profile_id': profileId},
    );
    return _coerceRpcResult(data);
  }

  // ────────────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────────────

  /// `Supabase.rpc` may decode JSONB into a `Map` or a `List`; we always
  /// hand UI code a plain `Map<String, dynamic>`.
  static Map<String, dynamic> _coerceRpcResult(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return <String, dynamic>{'success': true, 'raw': raw};
  }

  /// Build the `revertedActionIds` set used to dim/disable already-reverted
  /// rows in the recent corrections panel (web parity).
  static Set<String> deriveRevertedActionIds(
    List<Map<String, dynamic>> actions,
  ) {
    final out = <String>{};
    for (final a in actions) {
      if (a['action']?.toString() == 'revert_assign') {
        final src = (a['metadata'] is Map)
            ? a['metadata']['source_action_id']?.toString()
            : null;
        if (src != null && src.isNotEmpty) out.add(src);
      }
    }
    return out;
  }
}
