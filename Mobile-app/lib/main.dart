import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/firebase_options.dart';
import 'config/supabase_config.dart';
import 'firebase_messaging_background.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/supabase_data_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';
import 'screens/change_password_modal.dart';
import 'screens/update_password_screen.dart';
import 'services/deep_link_service.dart';
import 'services/fcm_registration_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FcmRegistrationService.ensureTokenRefreshListener();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint(
        'Firebase init skipped (configure Firebase to enable FCM): $e $st',
      );
    }
  }

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Hook custom-scheme deep links into Supabase auth so password-recovery
  // emails (web parity: redirectTo=io.cankaya.smarthome://login-callback/)
  // fire AuthChangeEvent.passwordRecovery once the app is opened.
  try {
    await DeepLinkService.initialize();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('Deep link init skipped: $e $st');
    }
  }

  await NotificationService.initialize(onTap: _onNotificationTap);

  try {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      try {
        final n = message.notification;
        if (n != null) {
          await NotificationService.show(
            id: message.hashCode & 0x7fffffff,
            title: n.title ?? 'Alert',
            body: n.body ?? '',
            payload: jsonEncode(message.data),
          );
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('FCM onMessage: $e $st');
        }
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('FCM opened from background: ${message.data}');
      }
      _openAlertsFromPushTap(
        eventType: message.data['event_type']?.toString(),
        eventId: message.data['event_id']?.toString(),
      );
    });
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('FCM listeners not registered: $e $st');
    }
  }

  runApp(const MyApp());

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        if (kDebugMode) {
          debugPrint('FCM cold start: ${initial.data}');
        }
        _openAlertsFromPushTap(
          eventType: initial.data['event_type']?.toString(),
          eventId: initial.data['event_id']?.toString(),
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FCM getInitialMessage: $e $st');
      }
    }
  });
}

void _openAlertsFromPushTap({String? eventType, String? eventId}) {
  final context = navigatorKey.currentContext;
  if (context != null) {
    try {
      unawaited(
        context.read<NotificationProvider>().handlePushTap(
          eventType: eventType,
          eventId: eventId,
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FCM navigation: $e $st');
      }
    }
  }
}

void _onNotificationTap(NotificationResponse details) {
  final payload = details.payload;
  if (payload == null || payload.isEmpty) {
    _openAlertsFromPushTap();
    return;
  }
  try {
    final data = jsonDecode(payload);
    if (data is Map) {
      _openAlertsFromPushTap(
        eventType: data['event_type']?.toString(),
        eventId: data['event_id']?.toString(),
      );
      return;
    }
  } catch (_) {
    // Backward-compatible payloads carried only the event_type string.
  }
  _openAlertsFromPushTap(eventType: payload);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Cache ThemeData instances so a theme toggle doesn't rebuild the
  // (expensive) ThemeData tree on every Consumer rebuild.
  static final ThemeData _light = AppTheme.light();
  static final ThemeData _dark = AppTheme.dark();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SupabaseDataProvider()),
        ChangeNotifierProxyProvider2<
          AuthProvider,
          SupabaseDataProvider,
          NotificationProvider
        >(
          create: (_) => NotificationProvider(),
          update: (_, auth, data, notif) {
            notif!
              ..attachDataProvider(data)
              ..updateAuth(isAuthenticated: auth.isAuthenticated);
            return notif;
          },
        ),
      ],
      child: Selector<ThemeProvider, ThemeMode>(
        selector: (_, tp) => tp.mode,
        builder: (context, mode, child) {
          return MaterialApp(
            title: 'Smart Home App',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: _light,
            darkTheme: _dark,
            themeMode: mode,
            // Snappier cross-fade between themes (default is 200ms with linear).
            themeAnimationDuration: const Duration(milliseconds: 180),
            themeAnimationCurve: Curves.easeOutCubic,
            home: child,
          );
        },
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.loading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            // Web parity: PasswordRecoveryRedirect in App.jsx routes the user
            // to /update-password whenever a recovery session is active.
            if (auth.isPasswordRecovery) {
              return const UpdatePasswordScreen();
            }
            if (!auth.isAuthenticated) {
              return const LoginScreen();
            }
            // Web parity: GlobalOverlays in App.jsx replaces the app shell
            // entirely with the password change modal until the resident
            // rotates their invite password.
            if (auth.forcePasswordChange) {
              return const ChangePasswordModal();
            }
            return const AppShell();
          },
        ),
      ),
    );
  }
}
