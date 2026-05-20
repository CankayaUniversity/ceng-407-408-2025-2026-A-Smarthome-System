/// PostgREST embed hints — required after [event_faces.best_match_resident_id]
/// (multiple FKs between event_faces and residents).
class SupabaseEmbeds {
  SupabaseEmbeds._();

  static const String eventFaces =
      'id, classification, match_score, resident_id, unknown_profile_id, '
      'camera_event_id, best_match_resident_id, '
      'residents!resident_id(name, id), '
      'unknown_face_profiles(id, display_label, sighting_count, first_seen_at, status)';

  static const String cameraEvent =
      '*, events(*), event_faces($eventFaces)';

  static const String eventFaceRow =
      'id, classification, match_score, resident_id, unknown_profile_id, '
      'camera_event_id, best_match_resident_id, '
      'camera_events(id, snapshot_path, created_at, event_id), '
      'residents!resident_id(name), '
      'unknown_face_profiles(id, display_label, sighting_count, first_seen_at, status)';
}
