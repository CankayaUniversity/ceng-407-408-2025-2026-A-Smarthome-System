import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home_screen.dart';
import '../screens/identity_review_screen.dart';
import '../screens/residents_screen.dart';
import '../screens/rooms_screen.dart';
import '../screens/history_screen.dart';
import '../camera_screen.dart';
import '../alerts_screen.dart';
import '../settings_screen.dart';
import '../models/face_capture.dart';
import '../providers/notification_provider.dart';
import '../security_alert_screen.dart';
import '../theme/app_theme.dart';

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
      context.read<NotificationProvider>().addListener(_onNotificationChange);
    });
  }

  @override
  void dispose() {
    context.read<NotificationProvider>().removeListener(_onNotificationChange);
    super.dispose();
  }

  // Tabs are addressed by stable string keys so notification/deep-link flows
  // can switch screens without depending on role-specific indices.
  List<_TabSpec> _buildTabs() {
    return [
      const _TabSpec('home', Icons.dashboard_rounded, 'Dash'),
      const _TabSpec('rooms', Icons.meeting_room_rounded, 'Rooms'),
      const _TabSpec('history', Icons.analytics_rounded, 'History'),
      const _TabSpec('camera', Icons.videocam_rounded, 'Camera'),
      const _TabSpec('residents', Icons.groups_rounded, 'Residents'),
      const _TabSpec('alerts', Icons.notifications_rounded, 'Alerts'),
      const _TabSpec('identity', Icons.face_retouching_natural, 'Identity'),
      const _TabSpec('settings', Icons.settings_rounded, 'Settings'),
    ];
  }

  void _switchToTab(String key) {
    final tabs = _buildTabs();
    final index = tabs.indexWhere((t) => t.key == key);
    if (index >= 0) setState(() => _currentIndex = index);
  }

  Widget _buildScreenFor(String key) {
    switch (key) {
      case 'home':
        return HomeScreen(onOpenCamera: () => _switchToTab('camera'));
      case 'rooms':
        return const RoomsScreen();
      case 'history':
        return const HistoryScreen();
      case 'camera':
        return const CameraScreen();
      case 'residents':
        return const ResidentsScreen(showBackButton: false);
      case 'alerts':
        return const AlertsScreen();
      case 'identity':
        return const IdentityReviewScreen();
      case 'settings':
        return const SettingsScreen();
    }
    return const SizedBox.shrink();
  }

  void _onNotificationChange() {
    final notif = context.read<NotificationProvider>();
    if (!notif.pendingPopup || !mounted) return;

    final shouldShowModal = notif.showSecurityModal;

    // Resolve the Alerts tab dynamically: when an admin is signed in the
    // Identity tab is inserted before Settings and any hard-coded index
    // would silently land on the wrong screen.
    final tabs = _buildTabs();
    final alertsIndex = tabs.indexWhere((t) => t.key == 'alerts');
    setState(() => _currentIndex = alertsIndex >= 0 ? alertsIndex : 0);
    notif.clearPopup();

    // Non-person events (fire, gas, motion, …) only switch to the Alerts
    // tab; opening SecurityAlertScreen for them is misleading and shows
    // "No snapshot available".
    if (!shouldShowModal) return;

    final cameraEvent = notif.latestCameraEvent;
    final capture = cameraEvent == null
        ? null
        : FaceCapture.fromCameraEvent(cameraEvent);
    final snapshotPath = cameraEvent?['snapshot_path']?.toString();
    final timestamp = cameraEvent?['created_at']?.toString();

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SecurityAlertScreen(
          snapshotPath: capture?.snapshotPath ?? snapshotPath,
          timestamp: timestamp,
          classification: capture?.classification,
          residentName: capture?.residentName,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tabs = _buildTabs();

    // Clamp defensively in case future role-specific tabs are added.
    final safeIndex = _currentIndex >= tabs.length
        ? tabs.length - 1
        : _currentIndex;

    final screens = [for (final t in tabs) _buildScreenFor(t.key)];

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: tokens.bgSurface,
          border: Border(top: BorderSide(color: tokens.borderSoft)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          // With top-level Residents plus the admin Identity tab, the bar can
          // overflow on narrow devices; allow horizontal scroll as fallback.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useScroll = tabs.length > 6 && constraints.maxWidth < 420;
                final row = Row(
                  mainAxisAlignment: useScroll
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.spaceAround,
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: useScroll ? 4 : 0,
                        ),
                        child: _buildNavItem(
                          tabs[i].icon,
                          tabs[i].label,
                          i,
                          safeIndex,
                        ),
                      ),
                  ],
                );
                if (useScroll) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: row,
                  );
                }
                return row;
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    int activeIndex,
  ) {
    final tokens = context.tokens;
    final isSelected = activeIndex == index;
    final activeColor = tokens.emberCore;
    final inactiveColor = tokens.textMuted;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? tokens.emberGlow : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabSpec {
  final String key;
  final IconData icon;
  final String label;
  const _TabSpec(this.key, this.icon, this.label);
}
