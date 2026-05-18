import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// Admin-only screen mirroring the User Management section of
/// `website/client/src/pages/SettingsPage.jsx`.
///
/// Lists every profile and lets the admin delete non-admin auth users via
/// the `delete_auth_user` RPC (server-side enforces caller is admin).
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _profiles = [];
  bool _loading = true;
  String? _error;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AuthProvider>().fetchAllProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load users: $e';
        _loading = false;
      });
    }
  }

  Future<void> _delete(Map<String, dynamic> profile) async {
    final tokens = context.tokens;
    final id = profile['id']?.toString();
    final name =
        (profile['name'] ?? profile['email'] ?? 'this user').toString();
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.bgSurface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete user', style: TextStyle(color: tokens.textPrimary)),
        content: Text(
          'Permanently remove $name? This deletes their auth account and '
          'all associated profile data. This cannot be undone.',
          style: TextStyle(color: tokens.textMuted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.crimsonCore,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _deletingId = id);

    final res = await context.read<AuthProvider>().deleteAuthUser(id);
    if (!mounted) return;

    setState(() => _deletingId = null);

    if (res.success) {
      setState(() => _profiles.removeWhere((p) => p['id']?.toString() == id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed $name')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: ${res.error ?? 'unknown'}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentUserId = context.watch<AuthProvider>().user?.id;

    return Scaffold(
      backgroundColor: tokens.bgVoid,
      appBar: AppBar(
        backgroundColor: tokens.bgVoid,
        elevation: 0,
        title: Text('User Management',
            style: TextStyle(color: tokens.textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tokens.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.cloud_off,
                                  size: 56, color: tokens.textWhisper),
                              const SizedBox(height: 12),
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: tokens.textMuted)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: tokens.emberCore,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            '${_profiles.length} user${_profiles.length == 1 ? '' : 's'} in this household',
                            style: TextStyle(
                                fontSize: 13, color: tokens.textMuted),
                          ),
                        ),
                        ..._profiles.map(
                          (p) => _UserRow(
                            profile: p,
                            isSelf: p['id']?.toString() == currentUserId,
                            isDeleting: p['id']?.toString() == _deletingId,
                            onDelete: () => _delete(p),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final Map<String, dynamic> profile;
  final bool isSelf;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _UserRow({
    required this.profile,
    required this.isSelf,
    required this.isDeleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final name = (profile['name'] ?? '').toString();
    final email = (profile['email'] ?? '').toString();
    final role = (profile['role'] ?? 'resident').toString();
    final isAdminRow = role == 'admin';
    final canDelete = !isSelf && !isAdminRow;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderSoft),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isAdminRow
                ? tokens.emberCore.withValues(alpha: 0.18)
                : tokens.cyanCore.withValues(alpha: 0.18),
            child: Text(
              name.isNotEmpty
                  ? name[0].toUpperCase()
                  : email.isNotEmpty
                      ? email[0].toUpperCase()
                      : '?',
              style: TextStyle(
                color: isAdminRow ? tokens.emberCore : tokens.cyanCore,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name.isEmpty ? email : name,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tokens.borderSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'You',
                          style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style:
                        TextStyle(fontSize: 11.5, color: tokens.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAdminRow
                        ? tokens.emberCore.withValues(alpha: 0.15)
                        : tokens.cyanCore.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      color: isAdminRow ? tokens.emberCore : tokens.cyanCore,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (canDelete)
            isDeleting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline,
                        color: tokens.crimsonCore.withValues(alpha: 0.8)),
                    tooltip: 'Delete user',
                  ),
        ],
      ),
    );
  }
}
