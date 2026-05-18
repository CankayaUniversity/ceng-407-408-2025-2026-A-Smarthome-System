import '../config/supabase_config.dart';

/// Represents a face capture event from the security camera.
/// Maps to rows in camera_events joined with event_faces.
class FaceCapture {
  final String id;
  final String? imagePath;
  final String? snapshotPath;
  final DateTime capturedAt;
  final String? label;
  final String? classification;
  final String? residentName;
  final double? confidence;

  /// Web parity: clustered unknown identity attached via
  /// `unknown_face_profiles(id, display_label, sighting_count)` join.
  final String? unknownProfileId;
  final String? unknownProfileLabel;
  final int? sightingCount;

  const FaceCapture({
    required this.id,
    this.imagePath,
    this.snapshotPath,
    required this.capturedAt,
    this.label,
    this.classification,
    this.residentName,
    this.confidence,
    this.unknownProfileId,
    this.unknownProfileLabel,
    this.sightingCount,
  });

  factory FaceCapture.fromJson(Map<String, dynamic> json) {
    return FaceCapture(
      id: json['id']?.toString() ?? '',
      imagePath: json['image_path']?.toString(),
      snapshotPath: json['snapshot_path']?.toString(),
      capturedAt:
          DateTime.tryParse(json['captured_at']?.toString() ?? '') ??
              DateTime.tryParse(json['created_at']?.toString() ?? '') ??
              DateTime.now(),
      label: json['label']?.toString(),
      classification: json['classification']?.toString(),
      residentName: json['resident_name']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  /// Build from a camera_events row with nested event_faces join.
  factory FaceCapture.fromCameraEvent(Map<String, dynamic> row) {
    final faces = row['event_faces'] as List?;
    final firstFace = (faces != null && faces.isNotEmpty)
        ? Map<String, dynamic>.from(faces.first as Map)
        : null;

    final resident = firstFace?['residents'];
    final residentMap = resident is Map ? resident : null;

    final profile = firstFace?['unknown_face_profiles'];
    final profileMap = profile is Map ? profile : null;
    final rawCount = profileMap?['sighting_count'];
    final sightings = rawCount is int
        ? rawCount
        : (rawCount is num ? rawCount.toInt() : null);

    return FaceCapture(
      id: row['id']?.toString() ?? '',
      snapshotPath: row['snapshot_path']?.toString(),
      imagePath: firstFace?['image_path']?.toString(),
      capturedAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now(),
      classification: firstFace?['classification']?.toString(),
      residentName: residentMap?['name']?.toString(),
      confidence: (firstFace?['confidence'] as num?)?.toDouble(),
      label: firstFace?['classification']?.toString(),
      unknownProfileId: profileMap?['id']?.toString(),
      unknownProfileLabel: profileMap?['display_label']?.toString(),
      sightingCount: sightings,
    );
  }

  String? get imageUrl {
    final path = imagePath ?? snapshotPath;
    if (path == null || path.isEmpty) return null;
    return SupabaseConfig.snapshotUrl(path);
  }

  bool get isUnknown {
    final c = classification?.toLowerCase().trim();
    return c == null || c.isEmpty || c == 'unknown' || c == 'unauthorized';
  }

  bool get isResident =>
      classification?.toLowerCase().trim() == 'resident';

  /// Web parity: resident name → clustered profile label (`Unknown #X · Nx
  /// seen`) → "Unknown Person". Mirrors `getDetectionDisplayName` in
  /// `website/client/src/utils/faceDisplay.js`.
  String get displayName {
    if (isResident) return residentName ?? 'Resident';
    final label = unknownProfileLabel;
    if (label != null && label.isNotEmpty) {
      final n = sightingCount;
      if (n != null && n > 1) return '$label · ${n}x seen';
      return label;
    }
    return 'Unknown Person';
  }

  @override
  String toString() =>
      'FaceCapture(id: $id, classification: $classification, at: $capturedAt)';
}
