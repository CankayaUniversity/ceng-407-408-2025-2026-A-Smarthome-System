import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/face_capture.dart';
import 'providers/notification_provider.dart';
import 'providers/supabase_data_provider.dart';
import 'services/supabase_data_service.dart';
import 'security_alert_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _selectedFilter = 'All';
  final Set<String> _acknowledgedIds = {};

  final Map<String, Map<String, dynamic>> _alertConfig = {
    'fire_alert':  {'icon': Icons.local_fire_department, 'color': const Color(0xFFFF4757), 'bg': const Color(0xFFFFF0F1), 'category': 'Environment'},
    'fire':        {'icon': Icons.local_fire_department, 'color': const Color(0xFFFF4757), 'bg': const Color(0xFFFFF0F1), 'category': 'Environment'},
    'smoke':       {'icon': Icons.cloud,                 'color': const Color(0xFFFF6348), 'bg': const Color(0xFFFFF0F1), 'category': 'Environment'},
    'flood':       {'icon': Icons.water_drop,            'color': const Color(0xFF3B9EFF), 'bg': const Color(0xFFF0F9FF), 'category': 'Environment'},
    'water':       {'icon': Icons.water_drop,            'color': const Color(0xFF3B9EFF), 'bg': const Color(0xFFF0F9FF), 'category': 'Environment'},
    'gas':         {'icon': Icons.air,                   'color': const Color(0xFFFFB020), 'bg': const Color(0xFFFFF7ED), 'category': 'Environment'},
    'stranger_detected': {'icon': Icons.person,          'color': const Color(0xFFF97316), 'bg': const Color(0xFFFFF7ED), 'category': 'Security'},
    'intrusion':   {'icon': Icons.person,                'color': const Color(0xFFF97316), 'bg': const Color(0xFFFFF7ED), 'category': 'Security'},
    'resident_detected': {'icon': Icons.person,          'color': const Color(0xFF00E5A0), 'bg': const Color(0xFFE6FCF5), 'category': 'Security'},
    'face_detected': {'icon': Icons.person,              'color': const Color(0xFF5C61B2), 'bg': const Color(0xFFF0F0FF), 'category': 'Security'},
    'motion':      {'icon': Icons.directions_run,        'color': const Color(0xFF9B59FF), 'bg': const Color(0xFFF5F0FF), 'category': 'Security'},
    'door':        {'icon': Icons.door_front_door,       'color': const Color(0xFF00E5A0), 'bg': const Color(0xFFE6FCF5), 'category': 'Security'},
    'system':      {'icon': Icons.system_update,         'color': const Color(0xFF8C92B5), 'bg': const Color(0xFFF7F8FA), 'category': 'System'},
  };

  Future<void> _acknowledge(String id) async {
    try {
      await SupabaseDataService.acknowledgeEvent(id);
    } catch (_) {}
    if (mounted) setState(() => _acknowledgedIds.add(id));
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0)    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    if (diff.inHours > 0)   return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
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
        timestamp: alert['createdAt']?.toString() ?? alert['created_at']?.toString(),
        classification: alert['classification']?.toString(),
        residentName: alert['residentName']?.toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const filters = ['All', 'Security', 'Environment', 'System'];

    final supabaseData = context.watch<SupabaseDataProvider>();
    final notifProvider = context.watch<NotificationProvider>();

    // Build alerts from the events table
    final dbEvents = supabaseData.events.map((e) {
      final eventType = (e['event_type'] ?? e['type'] ?? 'system').toString();
      return <String, dynamic>{
        'id': 'evt_${e['id']?.toString() ?? ''}',
        'type': eventType,
        'title': e['message']?.toString() ?? eventType,
        'message': e['message']?.toString() ?? 'Event detected.',
        'acknowledged': e['acknowledged'] ?? false,
        'createdAt': e['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'snapshot_path': e['snapshot_path'],
      };
    }).toList();

    // Build alerts from camera events (these have face data)
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
        'createdAt': row['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'snapshot_path': row['snapshot_path']?.toString(),
        'classification': capture.classification,
        'residentName': capture.residentName,
        'isFromCamera': true,
      };
    }).toList();

    // Realtime alerts from NotificationProvider
    final notifAlerts = notifProvider.faceAlerts;

    final seen = <String>{};
    final mergedAlerts = [...notifAlerts, ...camEvents, ...dbEvents].where((a) {
      final id = (a['id'] ?? '').toString();
      return id.isEmpty ? true : seen.add(id);
    }).toList()
      ..sort((a, b) {
        final aT = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(0);
        final bT = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(0);
        return bT.compareTo(aT);
      });

    for (final alert in mergedAlerts) {
      final id = alert['id']?.toString() ?? '';
      if (_acknowledgedIds.contains(id)) alert['acknowledged'] = true;
    }

    final filteredAlerts = mergedAlerts.where((a) {
      if (_selectedFilter == 'All') return true;
      final type = (a['type'] ?? '').toString().toLowerCase();
      final cat = _alertConfig[type]?['category'] ?? 'System';
      return cat == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: const [
                  Icon(Icons.arrow_back, color: Color(0xFF1a1a2e)),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Recent Alerts',
                        style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold,
                          color: Color(0xFF1a1a2e),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 24),
                ],
              ),
            ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: filters.map((filter) {
                  final isSelected = filter == _selectedFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilter = filter),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF5C61B2) : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF5C61B2) : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              filter,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.grey.shade700,
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
            const SizedBox(height: 16),

            Expanded(
              child: supabaseData.loading && mergedAlerts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredAlerts.isEmpty
                      ? Center(
                          child: Text(
                            'No alerts found.',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => context.read<SupabaseDataProvider>().fetchAll(),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: filteredAlerts.length,
                            itemBuilder: (context, index) {
                              final alert = filteredAlerts[index];
                              final type = (alert['type'] ?? 'system').toString().toLowerCase();
                              final config = _alertConfig[type] ?? _alertConfig['system']!;
                              final ack = alert['acknowledged'] == true;
                              final dt = DateTime.tryParse(alert['createdAt'] ?? '') ?? DateTime.now();
                              final title = alert['title']?.toString() ?? 'Alert';
                              final desc = alert['message'] ?? 'Unknown condition';

                              return GestureDetector(
                                onTap: () => _handleAlertTap(alert),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: config['bg'] as Color,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              config['icon'] as IconData,
                                              color: config['color'] as Color,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1a1a2e),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  desc,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _timeAgo(dt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade400,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: ack ? null : () => _acknowledge(alert['id'] ?? ''),
                                            child: Text(
                                              ack ? 'ACKNOWLEDGED' : 'ACKNOWLEDGE',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                                color: ack ? Colors.grey.shade400 : const Color(0xFF5C61B2),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
