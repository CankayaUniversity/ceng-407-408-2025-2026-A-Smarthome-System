import 'package:flutter/material.dart';

enum EventTone { critical, warning, info, success }

class EventMeta {
  final String key;
  final String title;
  final String short;
  final IconData icon;
  final EventTone tone;

  const EventMeta({
    required this.key,
    required this.title,
    required this.short,
    required this.icon,
    required this.tone,
  });
}

String _humanizeType(String? type) {
  if (type == null || type.trim().isEmpty) return 'System alert';
  return type
      .replaceAll('_', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

EventMeta getEventMeta(String? eventType) {
  final key = eventType?.toLowerCase().trim() ?? '';
  switch (key) {
    case 'fire_alert':
      return const EventMeta(
        key: 'fire_alert',
        title: 'Smoke or gas detected',
        short: 'Smoke alert',
        icon: Icons.local_fire_department,
        tone: EventTone.critical,
      );
    case 'fire_alert_cleared':
      return const EventMeta(
        key: 'fire_alert_cleared',
        title: 'Smoke alert cleared',
        short: 'Smoke cleared',
        icon: Icons.local_fire_department,
        tone: EventTone.info,
      );
    case 'stranger_detected':
      return const EventMeta(
        key: 'stranger_detected',
        title: 'Unknown visitor',
        short: 'Unknown visitor',
        icon: Icons.visibility,
        tone: EventTone.warning,
      );
    case 'resident_entry':
    case 'resident_detected':
      return EventMeta(
        key: key,
        title: 'Resident recognized',
        short: key == 'resident_entry' ? 'Resident entry' : 'Resident detected',
        icon: Icons.verified_user,
        tone: EventTone.success,
      );
    case 'flood':
      return const EventMeta(
        key: 'flood',
        title: 'Water leak detected',
        short: 'Water leak',
        icon: Icons.water_drop,
        tone: EventTone.critical,
      );
    case 'flood_cleared':
      return const EventMeta(
        key: 'flood_cleared',
        title: 'Water leak cleared',
        short: 'Leak cleared',
        icon: Icons.water_drop,
        tone: EventTone.info,
      );
    case 'motion_detected':
    case 'motion':
      return EventMeta(
        key: key,
        title: 'Motion detected',
        short: 'Motion',
        icon: Icons.directions_run,
        tone: EventTone.warning,
      );
    case 'door_open':
    case 'door':
      return EventMeta(
        key: key,
        title: 'Door opened',
        short: 'Door open',
        icon: Icons.door_front_door,
        tone: EventTone.warning,
      );
    case 'low_moisture':
      return const EventMeta(
        key: 'low_moisture',
        title: 'Low soil moisture',
        short: 'Low moisture',
        icon: Icons.air,
        tone: EventTone.warning,
      );
    default:
      final label = _humanizeType(eventType);
      return EventMeta(
        key: key,
        title: label,
        short: label,
        icon: Icons.warning_amber_rounded,
        tone: EventTone.warning,
      );
  }
}

bool isEventResolved(Map<String, dynamic> event) {
  final status = event['status']?.toString().toLowerCase();
  return event['acknowledged_at'] != null ||
      status == 'acknowledged' ||
      event['acknowledged'] == true;
}

String formatPriority(String? priority) {
  switch (priority?.toLowerCase()) {
    case 'critical':
      return 'Critical';
    case 'high':
      return 'High';
    case 'medium':
      return 'Medium';
    case 'low':
      return 'Low';
    case 'info':
      return 'Info';
    default:
      return priority == null || priority.isEmpty ? 'Alert' : priority;
  }
}
