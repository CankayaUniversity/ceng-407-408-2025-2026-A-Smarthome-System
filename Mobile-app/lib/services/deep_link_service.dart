import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bridges incoming custom-scheme deep links into the Supabase Flutter SDK
/// so password-recovery (and invite) emails open the app, install a
/// recovery session, and fire `AuthChangeEvent.passwordRecovery`.
///
/// Web parity:
///   - Web ContextProvider passes `passwordResetRedirectUrl = origin + '/update-password'`
///     to `resetPasswordForEmail`; Supabase appends the recovery hash to that URL.
///   - On mobile we use the custom scheme `io.cankaya.smarthome://login-callback/`
///     registered in AndroidManifest.xml. Tapping the link wakes the app
///     and routes the URI through here.
class DeepLinkService {
  DeepLinkService._();

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;
  static bool _initialized = false;

  /// Wires the cold-start URI plus a long-lived stream listener. Safe to call
  /// multiple times; subsequent calls are no-ops.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handle(initialUri);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[DeepLink] initial link error: $e $st');
      }
    }

    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _handle(uri),
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('[DeepLink] stream error: $e $st');
        }
      },
    );
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
  }

  static Future<void> _handle(Uri uri) async {
    if (kDebugMode) {
      debugPrint('[DeepLink] received: $uri');
    }
    // Supabase encodes the recovery session in the URL fragment
    // (#access_token=...&type=recovery&...). `getSessionFromUrl` parses it
    // and triggers `onAuthStateChange(AuthChangeEvent.passwordRecovery, ...)`.
    if (uri.fragment.isEmpty && uri.queryParameters.isEmpty) return;
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[DeepLink] getSessionFromUrl failed: $e $st');
      }
    }
  }
}
