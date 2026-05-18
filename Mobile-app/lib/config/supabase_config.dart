import 'package:supabase_flutter/supabase_flutter.dart';

import 'relay_config.dart';

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
  static const String devicesTable = 'devices';
  static const String userDevicesTable = 'user_devices';

  /// Singleton household row (id=1). Defined in `supabase_setup_v4.sql`.
  static const String householdSettingsTable = 'household_settings';

  /// Must match [NotificationService] channel id and FCM `android.notification.channel_id`.
  static const String fcmAndroidChannelId = 'smarthome_alerts';

  // Storage
  static const String snapshotBucket = 'event-snapshots';

  // Live camera — same relay as web (`RelayConfig` / `VITE_RELAY_WS_URL`).
  static const String relayWsUrl = RelayConfig.relayWsUrl;

  // FastAPI gateway used by Identity Review admin maintenance actions.
  // Example:
  //   --dart-define=GATEWAY_URL=http://192.168.1.25:8000
  //   --dart-define=DEVICE_ID=<devices.id UUID>
  static const String gatewayUrl = String.fromEnvironment(
    'GATEWAY_URL',
    defaultValue: 'http://172.20.10.7:8000',
  );
  static const String deviceId = String.fromEnvironment(
    'DEVICE_ID',
    defaultValue: '8c595d37-8f6a-40f3-95a0-91c493e255ac',
  );

  /// Returns a public URL for a file in Supabase Storage.
  static String getPublicUrl(String bucket, String path) {
    final data = Supabase.instance.client.storage
        .from(bucket)
        .getPublicUrl(path);
    return data;
  }

  /// Shorthand for snapshot bucket public URL.
  static String snapshotUrl(String path) => getPublicUrl(snapshotBucket, path);
}
