import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'services/supabase_auth_service.dart';
import 'screens/residents_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/theme_switch.dart';

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
      auth.clearError();
      if (!mounted) return;
      setState(() => _editingName = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name updated!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update name: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final auth = context.watch<AuthProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final user = auth.user;
    final profile = auth.profile;

    final userName = profile?['name'] ?? user?.userMetadata?['name'] ?? 'User';
    final userEmail = user?.email ?? '';
    final userRole = (profile?['role'] ?? 'resident').toString();
    final realtimeConnected = notifProvider.realtimeConnected;
    final hasLiveStream = SupabaseConfig.cameraStreamUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: tokens.bgVoid,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('Settings',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: tokens.textPrimary)),
              const SizedBox(height: 24),

              // ─── Account ─────────────────────────────
              _SectionTitle('Account'),
              _ProfileHero(
                userName: userName,
                userEmail: userEmail,
                userRole: userRole,
                editing: _editingName,
                controller: _nameController,
                onStartEdit: () {
                  _nameController.text = userName;
                  setState(() => _editingName = true);
                },
                onSave: _saveName,
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.people,
                title: 'Manage Residents',
                subtitle: 'Add, remove or update face profiles',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ResidentsScreen()),
                ),
              ),
              const SizedBox(height: 24),

              // ─── Appearance ──────────────────────────
              _SectionTitle('Appearance'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.bgSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tokens.borderSoft),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.cyanCore.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.brightness_6,
                          color: tokens.cyanCore, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Theme',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary,
                              )),
                          const SizedBox(height: 2),
                          Text(
                            'Toggle between cinematic dark and daylight light. Choice persists across sessions.',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: tokens.textMuted,
                                height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const ThemeSwitch(size: 'lg'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ─── System Information ──────────────────
              _SectionTitle('System Information'),
              _InfoRow(
                  icon: Icons.smartphone,
                  label: 'Platform',
                  value: 'Flutter ${Theme.of(context).platform.name}'),
              _InfoRow(
                  icon: Icons.storage,
                  label: 'Database',
                  value: 'Supabase (PostgreSQL)'),
              _InfoRow(
                  icon: Icons.router,
                  label: 'Gateway',
                  value: 'Realtime Channels'),
              _InfoRow(
                  icon: Icons.smart_toy,
                  label: 'AI Module',
                  value: 'Face Recognition Pipeline'),
              _InfoRow(
                icon: Icons.videocam,
                label: 'Live Camera Stream',
                value: hasLiveStream
                    ? '${SupabaseConfig.cameraStreamType.toUpperCase()} · configured'
                    : 'Not configured',
                valueColor: hasLiveStream ? tokens.jadeCore : tokens.textMuted,
              ),
              _SettingsTile(
                icon: Icons.cloud,
                title: 'Realtime Status',
                subtitle: realtimeConnected
                    ? 'Connected via Supabase Realtime'
                    : 'Disconnected',
                trailing: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: realtimeConnected
                        ? tokens.jadeCore
                        : tokens.crimsonCore,
                  ),
                ),
              ),
              _InfoRow(
                  icon: Icons.info_outline,
                  label: 'App Version',
                  value: 'v1.0.0'),
              const SizedBox(height: 28),

              // ─── Sign Out ────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign Out'),
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
                            child: Text('Sign out',
                                style:
                                    TextStyle(color: tokens.crimsonCore)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await context.read<AuthProvider>().logout();
                    }
                  },
                  icon: Icon(Icons.logout, color: tokens.crimsonCore),
                  label: Text('Sign out',
                      style: TextStyle(
                        color: tokens.crimsonCore,
                        fontWeight: FontWeight.w700,
                      )),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                        color:
                            tokens.crimsonCore.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── helpers ─────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: tokens.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String userRole;
  final bool editing;
  final TextEditingController controller;
  final VoidCallback onStartEdit;
  final VoidCallback onSave;

  const _ProfileHero({
    required this.userName,
    required this.userEmail,
    required this.userRole,
    required this.editing,
    required this.controller,
    required this.onStartEdit,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tokens.emberCore, tokens.emberBright],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: tokens.emberCore.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (editing)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 17),
                          decoration: InputDecoration(
                            hintText: 'Enter name',
                            hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check,
                            color: Colors.white, size: 20),
                        onPressed: onSave,
                      ),
                    ],
                  )
                else
                  GestureDetector(
                    onTap: onStartEdit,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            userName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.edit,
                            color: Colors.white.withValues(alpha: 0.6),
                            size: 14),
                      ],
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  userEmail,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
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
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    // ignore: unused_element_parameter
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final ic = iconColor ?? tokens.emberCore;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderSoft),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ic.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: ic, size: 20),
        ),
        title: Text(title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            )),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: tokens.textMuted)),
        trailing: trailing ??
            (onTap != null
                ? Icon(Icons.chevron_right, color: tokens.textWhisper)
                : null),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderSoft),
      ),
      child: Row(
        children: [
          Icon(icon, color: tokens.textMuted, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: valueColor ?? tokens.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
