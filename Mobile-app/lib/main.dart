import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/supabase_data_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  await NotificationService.initialize(onTap: _onNotificationTap);

  runApp(const MyApp());
}

void _onNotificationTap(NotificationResponse details) {
  final context = navigatorKey.currentContext;
  if (context != null) {
    context.read<NotificationProvider>().triggerPopup();
  }
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
