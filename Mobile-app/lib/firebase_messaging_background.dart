import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'config/firebase_options.dart';

/// Must be a top-level function. Runs in a separate isolate when a data
/// message arrives while the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    if (kDebugMode) {
      debugPrint('FCM background: ${message.messageId} data=${message.data}');
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('FCM background init error: $e $st');
    }
  }
}
