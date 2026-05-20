/**
 * PostgREST embed hints — required after event_faces.best_match_resident_id FK
 * (multiple relationships between event_faces and residents).
 */
export const EVENT_FACES_EMBED =
  'id, classification, match_score, resident_id, unknown_profile_id, camera_event_id, best_match_resident_id, ' +
  'residents!resident_id(name), ' +
  'best_match:residents!best_match_resident_id(id, name), ' +
  'unknown_face_profiles(id, display_label, sighting_count, first_seen_at, status)';

export const CAMERA_EVENT_EMBED =
  `*, events(*), event_faces(${EVENT_FACES_EMBED})`;
