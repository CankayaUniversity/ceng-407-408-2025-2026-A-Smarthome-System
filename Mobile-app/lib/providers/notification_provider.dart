import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/supabase_realtime_service.dart';
import 'supabase_data_provider.dart';

class NotificationProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _faceAlerts = [];
  bool _pendingPopup = false;
  Map<String, dynamic>? _latestCameraEvent;

  final SupabaseRealtimeService _realtimeService = SupabaseRealtimeService();

  /// Reference to the data provider so realtime payloads can be forwarded.
  /// Set via [attachDataProvider] from the ProxyProvider in `main.dart`.
  SupabaseDataProvider? _data;

  List<Map<String, dynamic>> get faceAlerts => List.unmodifiable(_faceAlerts);
  bool get pendingPopup => _pendingPopup;
  Map<String, dynamic>? get latestCameraEvent => _latestCameraEvent;
  SupabaseRealtimeService get realtimeService => _realtimeService;

  StreamSubscription? _cameraSub;
  StreamSubscription? _eventSub;
  StreamSubscription? _sensorSub;
  StreamSubscription? _connectionSub;
  bool _wasAuthenticated = false;
  bool _realtimeConnected = false;

  bool get realtimeConnected => _realtimeConnected;

  /// Wire-in the SupabaseDataProvider so realtime callbacks can mutate
  /// shared state (latestCameraEvent / sensor readings) without forcing
  /// a refetch — web parity with `RealtimeContext` that mutates React state.
  void attachDataProvider(SupabaseDataProvider data) {
    _data = data;
  }

  /// Called by ProxyProvider whenever AuthProvider changes.
  void updateAuth({bool isAuthenticated = false}) {
    if (isAuthenticated && !_wasAuthenticated) {
      _realtimeService.subscribe();
      _listenToStreams();
    } else if (!isAuthenticated && _wasAuthenticated) {
      _cameraSub?.cancel();
      _eventSub?.cancel();
      _sensorSub?.cancel();
      _connectionSub?.cancel();
      _realtimeService.unsubscribe();
      _realtimeConnected = false;
      notifyListeners();
    }
    _wasAuthenticated = isAuthenticated;
  }

  void _listenToStreams() {
    _cameraSub?.cancel();
    _eventSub?.cancel();
    _sensorSub?.cancel();
    _connectionSub?.cancel();

    _connectionSub = _realtimeService.connectionStatus.listen((connected) {
      _realtimeConnected = connected;
      notifyListeners();
    });

    _cameraSub = _realtimeService.cameraEvents.listen((row) {
      _latestCameraEvent = row;

      // Forward to SupabaseDataProvider so the dashboard "last snapshot"
      // banner and the camera screen list update without a refetch.
      _data?.prependCameraEvent(Map<String, dynamic>.from(row));

      final alert = <String, dynamic>{
        'id': row['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'type': 'intrusion',
        'title': 'Unknown Person Detected!',
        'message': 'Camera detected a person at the entrance.',
        'acknowledged': false,
        'createdAt':
            row['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'snapshot_path': row['snapshot_path'],
        'isFromCamera': true,
      };
      _addFaceAlert(alert);
      NotificationService.show(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: 'Person Detected!',
        body: 'Camera captured a new face event.',
      );
      triggerPopup();
    });

    _eventSub = _realtimeService.events.listen((row) {
      // Forward INSERTs into the events list so AlertsScreen updates live.
      if (row['acknowledged'] != true) {
        _data?.prependEvent(Map<String, dynamic>.from(row));
      } else {
        return;
      }

      final eventType =
          (row['event_type'] ?? row['type'] ?? '').toString().toLowerCase();

      String title;
      switch (eventType) {
        case 'fire_alert':
          title = 'Fire Alert!';
          break;
        case 'flood':
          title = 'Flood Detected!';
          break;
        case 'stranger_detected':
          title = 'Stranger Detected!';
          break;
        default:
          title = 'New Alert';
      }

      final entry = <String, dynamic>{
        'id': row['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'type': eventType,
        'title': title,
        'message': row['message']?.toString() ?? 'A new event was detected.',
        'acknowledged': false,
        'createdAt':
            row['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'isFromCamera': false,
      };

      _addFaceAlert(entry);
      NotificationService.show(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: title,
        body: entry['message'] as String,
      );
    });

    // Forward sensor reading inserts so the home dashboard, rooms screen
    // and history pages update without a re-fetch — web RealtimeContext
    // parity (`subscribe('sensor_reading', ...)`).
    _sensorSub = _realtimeService.sensorReadings.listen((row) {
      _data?.updateSensorFromRealtime(Map<String, dynamic>.from(row));
    });
  }

  void _addFaceAlert(Map<String, dynamic> alert) {
    final id = alert['id']?.toString() ?? '';
    if (id.isNotEmpty && _faceAlerts.any((a) => a['id'].toString() == id)) {
      return;
    }
    _faceAlerts.insert(0, alert);
    notifyListeners();
  }

  void triggerPopup() {
    _pendingPopup = true;
    notifyListeners();
  }

  void clearPopup() {
    _pendingPopup = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _cameraSub?.cancel();
    _eventSub?.cancel();
    _sensorSub?.cancel();
    _connectionSub?.cancel();
    _realtimeService.dispose();
    super.dispose();
  }
}
