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

  const FaceCapture({
    required this.id,
    this.imagePath,
    this.snapshotPath,
    required this.capturedAt,
    this.label,
    this.classification,
    this.residentName,
    this.confidence,
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
        ? Map<String, dynamic>.from(faces.first)
        : null;

    final resident = firstFace?['residents'] as Map<String, dynamic>?;

    return FaceCapture(
      id: row['id']?.toString() ?? '',
      snapshotPath: row['snapshot_path']?.toString(),
      imagePath: firstFace?['image_path']?.toString(),
      capturedAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now(),
      classification: firstFace?['classification']?.toString(),
      residentName: resident?['name']?.toString(),
      confidence: (firstFace?['confidence'] as num?)?.toDouble(),
      label: firstFace?['classification']?.toString(),
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

  String get displayName => isResident
      ? (residentName ?? 'Known Person')
      : 'Unknown Person';

  @override
  String toString() =>
      'FaceCapture(id: $id, classification: $classification, at: $capturedAt)';
}
