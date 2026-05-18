/// Mobile parity for `website/client/src/utils/faceDisplay.js`.
///
/// Shared label / tone helpers for camera + identity surveillance UI.
/// `camera_events.event_faces[0].classification` is the source of truth
/// (`'resident' | 'unknown'`); clustered unknowns also bring an attached
/// `unknown_face_profiles(id, display_label, sighting_count)` payload that
/// these helpers surface as e.g. `"Unknown #3 · 5x seen"`.
library;

enum DetectionTone { scanning, resident, unknown }

/// `event_faces[0]` from a camera_event row, or null.
Map<String, dynamic>? getFaceFromEvent(Map<String, dynamic>? event) {
  if (event == null) return null;
  final faces = event['event_faces'];
  if (faces is List && faces.isNotEmpty) {
    final first = faces.first;
    if (first is Map<String, dynamic>) return first;
    if (first is Map) return Map<String, dynamic>.from(first);
  }
  return null;
}

/// True for transient "scanning" overlay events (web sets `_scanning`).
/// Currently the mobile pipeline never produces this flag, but we keep the
/// check for behavioural parity if a future event mirrors the web shape.
bool isScanningEvent(Map<String, dynamic>? event) {
  if (event == null) return false;
  final face = getFaceFromEvent(event);
  return event['_scanning'] == true && face == null;
}

bool isResidentFace(Map<String, dynamic>? face) {
  if (face == null) return false;
  final c = face['classification']?.toString().toLowerCase();
  return c == 'resident';
}

/// Web parity: scanning → "Scanning...", resident → name, clustered unknown
/// → `display_label[ · Nx seen]`, fallback → "Unknown Person".
String getDetectionDisplayName(Map<String, dynamic>? event) {
  if (isScanningEvent(event)) return 'Scanning...';

  final face = getFaceFromEvent(event);
  if (face == null) return 'Unknown Person';

  if (isResidentFace(face)) {
    final residents = face['residents'];
    if (residents is Map) {
      final name = residents['name']?.toString();
      if (name != null && name.isNotEmpty) return name;
    }
    return 'Resident';
  }

  final profile = face['unknown_face_profiles'];
  if (profile is Map) {
    final label = profile['display_label']?.toString();
    if (label != null && label.isNotEmpty) {
      final n = profile['sighting_count'];
      final count = n is int ? n : (n is num ? n.toInt() : null);
      if (count != null && count > 1) {
        return '$label · ${count}x seen';
      }
      return label;
    }
  }

  return 'Unknown Person';
}

/// Web parity: 'scanning' | 'resident' | 'unknown'.
DetectionTone getDetectionTone(Map<String, dynamic>? event) {
  if (isScanningEvent(event)) return DetectionTone.scanning;
  final face = getFaceFromEvent(event);
  if (face != null && isResidentFace(face)) return DetectionTone.resident;
  return DetectionTone.unknown;
}
