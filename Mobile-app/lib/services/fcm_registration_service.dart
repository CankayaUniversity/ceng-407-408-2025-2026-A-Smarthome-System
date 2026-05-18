import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Registers the device FCM token in Supabase [user_devices] for the
/// signed-in user. Call after successful auth.
class FcmRegistrationService {
  FcmRegistrationService._();

  static StreamSubscription<String>? _tokenRefreshSub;

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {
      // Platform not available (e.g. some tests)
    }
    return 'unknown';
  }

  /// Subscribe to FCM token rotation once per app lifecycle.
  static void ensureTokenRefreshListener() {
    if (_tokenRefreshSub != null) return;
    try {
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (newToken) async {
          try {
            await _upsertToken(newToken);
          } catch (e, st) {
            if (kDebugMode) {
              debugPrint('FCM onTokenRefresh upsert failed: $e $st');
            }
          }
        },
        onError: (Object e, StackTrace st) {
          if (kDebugMode) {
            debugPrint('FCM onTokenRefresh error: $e $st');
          }
        },
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FCM ensureTokenRefreshListener: $e $st');
      }
    }
  }

  /// Requests notification permission (iOS), reads FCM token, upserts [user_devices].
  static Future<void> syncForCurrentUser() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          if (kDebugMode) {
            debugPrint('FCM: notification permission denied');
          }
          return;
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('FCM requestPermission: $e $st');
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          debugPrint('FCM: no token (check google-services.json / Firebase setup)');
        }
        return;
      }

      await _upsertToken(token);
      ensureTokenRefreshListener();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FcmRegistrationService.syncForCurrentUser: $e $st');
      }
    }
  }

  static Future<void> _upsertToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final row = <String, dynamic>{
      'user_id': user.id,
      'fcm_token': token,
      'platform': _platformLabel(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await Supabase.instance.client.from(SupabaseConfig.userDevicesTable).upsert(
          row,
          onConflict: 'fcm_token',
        );
  }

  /// Removes this device's row before sign-out (best-effort).
  static Future<void> unregisterCurrentDevice() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      String? token;
      try {
        token = await FirebaseMessaging.instance.getToken();
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('FCM getToken during unregister: $e $st');
        }
      }

      if (token != null && token.isNotEmpty) {
        await Supabase.instance.client
            .from(SupabaseConfig.userDevicesTable)
            .delete()
            .eq('user_id', user.id)
            .eq('fcm_token', token);
      }

      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('FCM deleteToken: $e $st');
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FcmRegistrationService.unregisterCurrentDevice: $e $st');
      }
    }
  }

  static Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }
}
