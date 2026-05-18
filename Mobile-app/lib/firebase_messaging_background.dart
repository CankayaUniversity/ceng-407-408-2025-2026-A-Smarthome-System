import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'config/firebase_options.dart';
import 'services/notification_service.dart';

/// Must be a top-level function. Runs in a separate isolate when a data
/// message arrives while the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      debugPrint('FCM background: ${message.messageId} data=${message.data}');
    }

    // Android displays notification-payload messages itself while the app is
    // backgrounded/terminated. Data-only pushes need an explicit local
    // notification from this isolate.
    if (message.notification == null) {
      final eventType = message.data['event_type']?.toString() ?? 'Alert';
      final title =
          message.data['title']?.toString() ??
          eventType
              .replaceAll('_', ' ')
              .trim()
              .split(' ')
              .map((word) {
                if (word.isEmpty) return word;
                return '${word[0].toUpperCase()}${word.substring(1)}';
              })
              .join(' ');
      final body =
          message.data['body']?.toString() ??
          message.data['message']?.toString() ??
          'Smart home notification.';

      await NotificationService.initializeBackground();
      await NotificationService.show(
        id: message.hashCode & 0x7fffffff,
        title: title.isEmpty ? 'Smart Home Alert' : title,
        body: body,
        payload: jsonEncode(message.data),
      );
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('FCM background init error: $e $st');
    }
  }
}
