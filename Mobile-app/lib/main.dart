import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/supabase_data_provider.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';
import 'services/notification_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SupabaseDataProvider()),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, notif) {
            notif!.updateAuth(isAuthenticated: auth.isAuthenticated);
            return notif;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Smart Home App',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(seedColor: const Color(0xFF5C61B2)),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        ),
        home: Consumer<AuthProvider>(
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
