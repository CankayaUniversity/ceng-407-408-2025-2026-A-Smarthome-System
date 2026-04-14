import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Mirrors the web's RealtimeContext.jsx — subscribes to postgres_changes
/// on sensor_readings, events, and camera_events.
class SupabaseRealtimeService {
  static final _client = Supabase.instance.client;

  RealtimeChannel? _channel;
  bool _isConnected = false;

  final _sensorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _cameraEventController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get sensorReadings =>
      _sensorController.stream;
  Stream<Map<String, dynamic>> get events => _eventController.stream;
  Stream<Map<String, dynamic>> get cameraEvents =>
      _cameraEventController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  bool get isConnected => _isConnected;

  void subscribe() {
    unsubscribe();

    _channel = _client
        .channel('db-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.sensorReadingsTable,
          callback: (payload) {
            _sensorController.add(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConfig.eventsTable,
          callback: (payload) {
            _eventController.add(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.cameraEventsTable,
          callback: (payload) {
            _cameraEventController.add(payload.newRecord);
          },
        )
        .subscribe((status, [error]) {
      final connected = status == RealtimeSubscribeStatus.subscribed;
      if (_isConnected != connected) {
        _isConnected = connected;
        _connectionController.add(connected);
      }
    });
  }

  void unsubscribe() {
    if (_channel != null) {
      _client.removeChannel(_channel!);
      _channel = null;
    }
    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    unsubscribe();
    _sensorController.close();
    _eventController.close();
    _cameraEventController.close();
    _connectionController.close();
  }
}
