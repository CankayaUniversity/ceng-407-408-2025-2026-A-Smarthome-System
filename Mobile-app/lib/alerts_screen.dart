import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/face_capture.dart';
import 'providers/notification_provider.dart';
import 'providers/supabase_data_provider.dart';
import 'services/supabase_data_service.dart';
import 'security_alert_screen.dart';
import 'theme/app_theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _selectedFilter = 'All';
  final Set<String> _acknowledgedIds = {};

  Map<String, Map<String, dynamic>> _alertConfig(AppTokens tokens) => {
        'fire_alert': {
          'icon': Icons.local_fire_department,
          'color': tokens.crimsonCore,
          'category': 'Environment'
        },
        'fire': {
          'icon': Icons.local_fire_department,
          'color': tokens.crimsonCore,
          'category': 'Environment'
        },
        'smoke': {
          'icon': Icons.cloud,
          'color': tokens.crimsonCore,
          'category': 'Environment'
        },
        'flood': {
          'icon': Icons.water_drop,
          'color': tokens.sensorWater,
          'category': 'Environment'
        },
        'water': {
          'icon': Icons.water_drop,
          'color': tokens.sensorWater,
          'category': 'Environment'
        },
        'gas': {
          'icon': Icons.air,
          'color': tokens.amberCore,
          'category': 'Environment'
        },
        'stranger_detected': {
          'icon': Icons.person,
          'color': tokens.emberCore,
          'category': 'Security'
        },
        'intrusion': {
          'icon': Icons.person,
          'color': tokens.emberCore,
          'category': 'Security'
        },
        'resident_detected': {
          'icon': Icons.person,
          'color': tokens.jadeCore,
          'category': 'Security'
        },
        'face_detected': {
          'icon': Icons.person,
          'color': tokens.violetCore,
          'category': 'Security'
        },
        'motion': {
          'icon': Icons.directions_run,
          'color': tokens.violetCore,
          'category': 'Security'
        },
        'door': {
          'icon': Icons.door_front_door,
          'color': tokens.jadeCore,
          'category': 'Security'
        },
        'system': {
          'icon': Icons.system_update,
          'color': tokens.textSecondary,
          'category': 'System'
        },
      };

  Future<void> _acknowledge(String id) async {
    if (id.isEmpty) return;
    // IDs in the merged list are prefixed with `evt_`, `cam_`, or empty
    // (notif provider). Only `evt_` rows correspond to a row in the
    // `events` table, so strip the prefix before persisting.
    if (id.startsWith('evt_')) {
      final rawId = id.substring(4);
      try {
        await SupabaseDataService.acknowledgeEvent(rawId);
      } catch (_) {}
    }
    if (mounted) setState(() => _acknowledgedIds.add(id));
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inMinutes > 0) return '${diff.inMinutes} mins ago';
    return 'Just now';
  }

  void _handleAlertTap(Map<String, dynamic> alert) {
    final hasSnapshot = alert['snapshot_path'] != null ||
        alert['classification'] != null ||
        alert['isFromCamera'] == true;
    if (!hasSnapshot) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SecurityAlertScreen(
        snapshotPath: alert['snapshot_path']?.toString(),
        timestamp: alert['createdAt']?.toString() ??
            alert['created_at']?.toString(),
        classification: alert['classification']?.toString(),
        residentName: alert['residentName']?.toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const filters = [
      'All',
      'Security',
      'Environment',
      'System',
      'Acknowledged',
    ];
    final tokens = context.tokens;
    final config = _alertConfig(tokens);

    final supabaseData = context.watch<SupabaseDataProvider>();
    final notifProvider = context.watch<NotificationProvider>();

    final dbEvents = supabaseData.events.map((e) {
      final eventType = (e['event_type'] ?? e['type'] ?? 'system').toString();
      return <String, dynamic>{
        'id': 'evt_${e['id']?.toString() ?? ''}',
        'type': eventType,
        'title': e['message']?.toString() ?? eventType,
        'message': e['message']?.toString() ?? 'Event detected.',
        'acknowledged': e['acknowledged'] ?? false,
        'createdAt':
            e['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'snapshot_path': e['snapshot_path'],
      };
    }).toList();

    final camEvents = supabaseData.cameraEvents.map((row) {
      final capture = FaceCapture.fromCameraEvent(row);
      final isResident = capture.isResident;
      final eventType = isResident ? 'resident_detected' : 'stranger_detected';
      return <String, dynamic>{
        'id': 'cam_${row['id']?.toString() ?? ''}',
        'type': eventType,
        'title': isResident
            ? 'Known resident identified'
            : 'Unknown person detected',
        'message': isResident
            ? '${capture.displayName} was detected by the camera.'
            : 'Camera detected an unidentified person.',
        'acknowledged': false,
        'createdAt':
            row['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'snapshot_path': row['snapshot_path']?.toString(),
        'classification': capture.classification,
        'residentName': capture.residentName,
        'isFromCamera': true,
      };
    }).toList();

    final notifAlerts = notifProvider.faceAlerts;

    final seen = <String>{};
    final mergedAlerts = [...notifAlerts, ...camEvents, ...dbEvents].where((a) {
      final id = (a['id'] ?? '').toString();
      return id.isEmpty ? true : seen.add(id);
    }).toList()
      ..sort((a, b) {
        final aT = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
            DateTime(0);
        final bT = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
            DateTime(0);
        return bT.compareTo(aT);
      });

    for (final alert in mergedAlerts) {
      final id = alert['id']?.toString() ?? '';
      if (_acknowledgedIds.contains(id)) alert['acknowledged'] = true;
    }

    final filteredAlerts = mergedAlerts.where((a) {
      if (_selectedFilter == 'Acknowledged') {
        return a['acknowledged'] == true;
      }
      if (_selectedFilter == 'All') return true;
      final type = (a['type'] ?? '').toString().toLowerCase();
      final cat = config[type]?['category'] ?? 'System';
      return cat == _selectedFilter;
    }).toList();

    final activeAlerts =
        filteredAlerts.where((a) => a['acknowledged'] != true).toList();
    final ackAlerts =
        filteredAlerts.where((a) => a['acknowledged'] == true).toList();

    return Scaffold(
      backgroundColor: tokens.bgVoid,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.arrow_back, color: tokens.textPrimary),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Recent Alerts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: filters.map((filter) {
                  final isSelected = filter == _selectedFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedFilter = filter),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? tokens.emberCore
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? tokens.emberCore
                                : tokens.borderMedium,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              filter,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: supabaseData.loading && mergedAlerts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredAlerts.isEmpty
                      ? Center(
                          child: Text(
                            'No alerts found.',
                            style: TextStyle(color: tokens.textMuted),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => context
                              .read<SupabaseDataProvider>()
                              .fetchAll(),
                          child: CustomScrollView(
                            slivers: [
                              if (activeAlerts.isNotEmpty) ...[
                                SliverToBoxAdapter(
                                  child: _SectionHeader(
                                    label: 'ACTIVE',
                                    count: activeAlerts.length,
                                    accent: tokens.emberCore,
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  sliver: SliverList.builder(
                                    itemCount: activeAlerts.length,
                                    itemBuilder: (_, i) => _buildAlertCard(
                                      context,
                                      activeAlerts[i],
                                      config,
                                      tokens,
                                    ),
                                  ),
                                ),
                              ],
                              if (ackAlerts.isNotEmpty) ...[
                                SliverToBoxAdapter(
                                  child: _SectionHeader(
                                    label: 'ACKNOWLEDGED',
                                    count: ackAlerts.length,
                                    accent: tokens.textMuted,
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  sliver: SliverList.builder(
                                    itemCount: ackAlerts.length,
                                    itemBuilder: (_, i) => _buildAlertCard(
                                      context,
                                      ackAlerts[i],
                                      config,
                                      tokens,
                                    ),
                                  ),
                                ),
                              ],
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 24),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    Map<String, dynamic> alert,
    Map<String, Map<String, dynamic>> config,
    AppTokens tokens,
  ) {
    final type = (alert['type'] ?? 'system').toString().toLowerCase();
    final cfg = config[type] ?? config['system']!;
    final cfgColor = cfg['color'] as Color;
    final ack = alert['acknowledged'] == true;
    final dt =
        DateTime.tryParse(alert['createdAt'] ?? '') ?? DateTime.now();
    final title = alert['title']?.toString() ?? 'Alert';
    final desc = alert['message'] ?? 'Unknown condition';

    return GestureDetector(
      onTap: () => _handleAlertTap(alert),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.borderSoft),
          boxShadow: ack
              ? const []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Opacity(
          opacity: ack ? 0.65 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: cfgColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      cfg['icon'] as IconData,
                      color: cfgColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                            decoration: ack
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: tokens.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc.toString(),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: tokens.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _timeAgo(dt),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: tokens.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: ack
                        ? null
                        : () => _acknowledge(alert['id'] ?? ''),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ack
                            ? tokens.bgRaised
                            : tokens.emberCore.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ack
                              ? tokens.borderSoft
                              : tokens.emberCore.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ack) ...[
                            Icon(Icons.check_circle,
                                size: 13, color: tokens.jadeCore),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            ack ? 'ACKNOWLEDGED' : 'ACKNOWLEDGE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: ack
                                  ? tokens.textMuted
                                  : tokens.emberCore,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color accent;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
