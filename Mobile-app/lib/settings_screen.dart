import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'services/supabase_auth_service.dart';
import 'screens/residents_screen.dart';
import 'screens/rooms_screen.dart';
import 'screens/history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _editingName = false;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id;
    if (userId == null) return;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    try {
      await SupabaseAuthService.updateProfile(userId, {'name': newName});
      // Reload profile
      auth.clearError();
      setState(() => _editingName = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update name: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final user = auth.user;
    final profile = auth.profile;

    final userName = profile?['name'] ?? user?.userMetadata?['name'] ?? 'User';
    final userEmail = user?.email ?? '';
    final userRole = (profile?['role'] ?? 'resident').toString();
    final realtimeConnected = notifProvider.realtimeConnected;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text('Settings',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1a1a2e))),
              const SizedBox(height: 24),

              // User profile card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5C61B2), Color(0xFF7C83E8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5C61B2).withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        userName.isNotEmpty
                            ? userName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_editingName)
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _nameController,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 18),
                                    decoration: InputDecoration(
                                      hintText: 'Enter name',
                                      hintStyle: TextStyle(
                                          color:
                                              Colors.white.withOpacity(0.5)),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check,
                                      color: Colors.white, size: 20),
                                  onPressed: _saveName,
                                ),
                              ],
                            )
                          else
                            GestureDetector(
                              onTap: () {
                                _nameController.text = userName;
                                setState(() => _editingName = true);
                              },
                              child: Row(
                                children: [
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.edit,
                                      color: Colors.white.withOpacity(0.6),
                                      size: 16),
                                ],
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            userEmail,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              userRole.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              _buildSectionTitle('Face Recognition'),
              _buildSettingsTile(
                icon: Icons.people,
                title: 'Manage Residents',
                subtitle: 'Add, remove or update face profiles',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ResidentsScreen()),
                ),
              ),
              const SizedBox(height: 20),

              _buildSectionTitle('Other Pages'),
              _buildSettingsTile(
                icon: Icons.meeting_room_rounded,
                title: 'Rooms',
                subtitle: 'View sensors by room',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RoomsScreen()),
                ),
              ),
              _buildSettingsTile(
                icon: Icons.analytics_rounded,
                title: 'History',
                subtitle: 'View historical sensor data',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const HistoryScreen()),
                ),
              ),
              const SizedBox(height: 20),

              _buildSectionTitle('System'),
              _buildSettingsTile(
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: 'v1.0.0',
              ),
              _buildSettingsTile(
                icon: Icons.cloud,
                title: 'Supabase',
                subtitle: 'Connected via Realtime',
                trailing: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: realtimeConnected
                        ? const Color(0xFF00E5A0)
                        : Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildSectionTitle('Account'),
              _buildSettingsTile(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                iconColor: Colors.red,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text(
                          'Are you sure you want to sign out?'),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Logout',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await context.read<AuthProvider>().logout();
                  }
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color iconColor = const Color(0xFF5C61B2),
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style:
                TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        trailing: trailing ??
            (onTap != null
                ? Icon(Icons.chevron_right,
                    color: Colors.grey.shade400)
                : null),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
