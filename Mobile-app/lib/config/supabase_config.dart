import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://svdfzryqjfkccmgpspkz.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_UbJq3ukkpPOODWt-62PTpA_ZyR-Lhae';

  // Table names
  static const String sensorReadingsTable = 'sensor_readings';
  static const String eventsTable = 'events';
  static const String cameraEventsTable = 'camera_events';
  static const String eventFacesTable = 'event_faces';
  static const String residentsTable = 'residents';
  static const String profilesTable = 'profiles';

  // Storage
  static const String snapshotBucket = 'event-snapshots';

  /// Returns a public URL for a file in Supabase Storage.
  static String getPublicUrl(String bucket, String path) {
    final data =
        Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
    return data;
  }

  /// Shorthand for snapshot bucket public URL.
  static String snapshotUrl(String path) => getPublicUrl(snapshotBucket, path);
}
