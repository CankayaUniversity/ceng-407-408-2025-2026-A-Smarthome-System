import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/supabase_realtime_service.dart';
import '../utils/event_meta.dart';
import 'supabase_data_provider.dart';

class NotificationProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _faceAlerts = [];
  bool _pendingPopup = false;
  bool _showSecurityModal = false;
  Map<String, dynamic>? _latestCameraEvent;

  final SupabaseRealtimeService _realtimeService = SupabaseRealtimeService();

  /// Event types that warrant opening the SecurityAlertScreen modal on a
  /// push tap. Other event types (fire_alert, gas, motion, etc.) still
  /// switch the user to the Alerts tab but do not open the popup.
  static const Set<String> _personEventTypes = {
    'stranger_detected',
    'resident_entry',
    'unknown_person_detected',
    'known_resident_identified',
    'resident_detected',
    'face_detected',
    'intrusion',
  };

  /// Reference to the data provider so realtime payloads can be forwarded.
  /// Set via [attachDataProvider] from the ProxyProvider in `main.dart`.
  SupabaseDataProvider? _data;

  List<Map<String, dynamic>> get faceAlerts => List.unmodifiable(_faceAlerts);
  bool get pendingPopup => _pendingPopup;
  bool get showSecurityModal => _showSecurityModal;
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
      final cameraEventId = row['id']?.toString();
      if (cameraEventId != null && cameraEventId.isNotEmpty) {
        Future<void>.delayed(const Duration(milliseconds: 1500), () async {
          final joined = await _data?.fetchCameraEventById(cameraEventId);
          if (joined != null) {
            _latestCameraEvent = joined;
            notifyListeners();
          }
        });
      }

      final alert = <String, dynamic>{
        'id':
            row['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'type': 'face_detected',
        'title': 'Person Detected!',
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
        payload: jsonEncode({
          'event_type': 'face_detected',
          'event_id': row['event_id']?.toString() ?? '',
        }),
      );
      triggerPopup();
    });

    _eventSub = _realtimeService.events.listen((row) {
      // Forward INSERTs into the events list so AlertsScreen updates live.
      if (!isEventResolved(Map<String, dynamic>.from(row))) {
        _data?.prependEvent(Map<String, dynamic>.from(row));
      } else {
        return;
      }

      final eventType = (row['event_type'] ?? row['type'] ?? '')
          .toString()
          .toLowerCase();

      final meta = getEventMeta(eventType);
      final title = meta.title;

      final entry = <String, dynamic>{
        'id':
            row['id']?.toString() ??
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
        payload: jsonEncode({
          'event_type': eventType,
          'event_id': row['id']?.toString() ?? '',
          'priority': row['priority']?.toString() ?? '',
          'device_id': row['device_id']?.toString() ?? '',
        }),
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

  /// Used by realtime camera-event subscribers where the trigger is
  /// always a face/person detection — always opens the security modal.
  void triggerPopup() {
    _pendingPopup = true;
    _showSecurityModal = true;
    notifyListeners();
  }

  /// Used by FCM / local-notification taps. Always navigates the user to
  /// the Alerts tab; only opens the SecurityAlertScreen modal when the
  /// originating event_type is in [_personEventTypes].
  Future<void> handlePushTap({String? eventType, String? eventId}) async {
    final isPerson = _isPersonEvent(eventType);
    if (isPerson) {
      Map<String, dynamic>? joined;
      if (eventId != null && eventId.isNotEmpty) {
        joined = await _data?.fetchCameraEventForEventId(eventId);
      }
      joined ??= _data?.latestCameraEvent;
      if (joined != null) {
        _latestCameraEvent = joined;
      }
    }
    _pendingPopup = true;
    _showSecurityModal = isPerson;
    notifyListeners();
  }

  bool _isPersonEvent(String? eventType) {
    if (eventType == null) return false;
    return _personEventTypes.contains(eventType.trim().toLowerCase());
  }

  void clearPopup() {
    _pendingPopup = false;
    _showSecurityModal = false;
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
