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
      debugPrint('Firebase init skipped (configure Firebase to enable FCM): $e $st');
    }
  }

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

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
      _openAlertsFromPushTap();
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
        _openAlertsFromPushTap();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FCM getInitialMessage: $e $st');
      }
    }
  });
}

void _openAlertsFromPushTap() {
  final context = navigatorKey.currentContext;
  if (context != null) {
    try {
      context.read<NotificationProvider>().triggerPopup();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FCM navigation: $e $st');
      }
    }
  }
}

void _onNotificationTap(NotificationResponse details) {
  _openAlertsFromPushTap();
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
        ChangeNotifierProxyProvider2<AuthProvider, SupabaseDataProvider,
            NotificationProvider>(
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
            return auth.isAuthenticated
                ? const AppShell()
                : const LoginScreen();
          },
        ),
      ),
    );
  }
}
