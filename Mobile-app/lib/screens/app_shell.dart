import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home_screen.dart';
import '../screens/rooms_screen.dart';
import '../screens/history_screen.dart';
import '../camera_screen.dart';
import '../alerts_screen.dart';
import '../settings_screen.dart';
import '../providers/notification_provider.dart';
import '../security_alert_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<NotificationProvider>()
          .addListener(_onNotificationChange);
    });
  }

  @override
  void dispose() {
    context
        .read<NotificationProvider>()
        .removeListener(_onNotificationChange);
    super.dispose();
  }

  void _onNotificationChange() {
    final notif = context.read<NotificationProvider>();
    if (!notif.pendingPopup || !mounted) return;

    setState(() => _currentIndex = 4);
    notif.clearPopup();

    final cameraEvent = notif.latestCameraEvent;
    final snapshotPath = cameraEvent?['snapshot_path']?.toString();
    final timestamp = cameraEvent?['created_at']?.toString();

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SecurityAlertScreen(
          snapshotPath: snapshotPath,
          timestamp: timestamp,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = const [
      HomeScreen(),
      RoomsScreen(),
      HistoryScreen(),
      CameraScreen(),
      AlertsScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.dashboard_rounded, 'Dash', 0),
                _buildNavItem(Icons.meeting_room_rounded, 'Rooms', 1),
                _buildNavItem(Icons.analytics_rounded, 'History', 2),
                _buildNavItem(Icons.videocam_rounded, 'Camera', 3),
                _buildNavItem(Icons.notifications_rounded, 'Alerts', 4),
                _buildNavItem(Icons.settings_rounded, 'Settings', 5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5C61B2).withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? const Color(0xFF5C61B2) : Colors.grey.shade400,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF5C61B2) : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
