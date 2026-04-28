import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/environment_data.dart';
import '../providers/supabase_data_provider.dart';
import '../theme/app_theme.dart';

// ─── Floor plan room layout ─────────────────────────────────
// Bire-bir web RoomsPage.jsx ROOMS dizisinin Flutter eşdeğeri.
// left/top/w/h değerleri viewport-yüzdesi cinsinden.

class _Room {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final double left;
  final double top;
  final double w;
  final double h;
  const _Room(this.id, this.label, this.icon, this.color,
      this.left, this.top, this.w, this.h);
}

const _rooms = <_Room>[
  _Room('living', 'Living Room', Icons.weekend, Color(0xFF7C6FFF),
      2, 2, 36, 45),
  _Room('kitchen', 'Kitchen', Icons.countertops, Color(0xFFFF6B35),
      40, 2, 28, 45),
  _Room('garden', 'Garden', Icons.local_florist, Color(0xFF52B788),
      70, 2, 28, 45),
  _Room('bedroom', 'Master Bedroom', Icons.bed, Color(0xFF00D4FF),
      2, 51, 36, 46),
  _Room('entrance', 'Entrance', Icons.lock, Color(0xFF00E5A0),
      40, 51, 17, 46),
  _Room('bathroom', 'Bathroom', Icons.shower, Color(0xFF3B9EFF),
      59, 51, 39, 46),
];

const _roomIds = <String>{
  'living',
  'kitchen',
  'garden',
  'bedroom',
  'entrance',
  'bathroom',
};

String _deviceToRoomFromName(String? name) {
  final n = (name ?? '').toLowerCase();
  if (n.contains('kitchen')) return 'kitchen';
  if (n.contains('bedroom')) return 'bedroom';
  if (n.contains('door') || n.contains('front') || n.contains('entrance')) {
    return 'entrance';
  }
  if (n.contains('bath')) return 'bathroom';
  if (n.contains('garden')) return 'garden';
  return 'living';
}

String _resolveRoom(Map<String, dynamic>? device) {
  if (device == null) return 'living';
  final r = device['room']?.toString();
  if (r != null && _roomIds.contains(r)) return r;
  return _deviceToRoomFromName(device['name']?.toString());
}

class _SensorIconCfg {
  final IconData icon;
  final Color Function(AppTokens) color;
  const _SensorIconCfg(this.icon, this.color);
}

const _sensorIcons = <String, _SensorIconCfg>{
  'temperature':
      _SensorIconCfg(Icons.thermostat, _sensorTempColor),
  'humidity': _SensorIconCfg(Icons.water_drop, _sensorHumidColor),
  'smoke': _SensorIconCfg(Icons.cloud, _sensorSmokeColor),
  'water': _SensorIconCfg(Icons.grass, _sensorWaterColor),
  'motion': _SensorIconCfg(Icons.directions_walk, _sensorMotionColor),
};

Color _sensorTempColor(AppTokens t) => t.sensorTemp;
Color _sensorHumidColor(AppTokens t) => t.sensorHumid;
Color _sensorSmokeColor(AppTokens t) => t.sensorSmoke;
Color _sensorWaterColor(AppTokens t) => t.sensorWater;
Color _sensorMotionColor(AppTokens t) => t.sensorMotion;

_SensorIconCfg _sicOf(String type) =>
    _sensorIcons[type.toLowerCase()] ??
    _SensorIconCfg(Icons.sensors, (t) => t.textSecondary);

class _DeviceGroup {
  final String id;
  final Map<String, dynamic>? device;
  final List<SensorReading> sensors;
  const _DeviceGroup({
    required this.id,
    required this.device,
    required this.sensors,
  });

  String get name => device?['name']?.toString() ?? 'Unknown device';
}

// ─── Screen ──────────────────────────────────────────────────

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final data = context.watch<SupabaseDataProvider>();
    final isLoading = data.loading && data.sensorReadings.isEmpty;

    final groupsByRoom = _buildGroups(data);

    return Scaffold(
      backgroundColor: tokens.bgVoid,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => data.fetchAll(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text('Rooms',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: tokens.textPrimary)),
              const SizedBox(height: 4),
              Text(
                'Tap a room to manage its devices and reassign sensors',
                style: TextStyle(fontSize: 13, color: tokens.textMuted),
              ),
              const SizedBox(height: 20),

              if (isLoading)
                SizedBox(
                  height: 320,
                  child: const Center(child: CircularProgressIndicator()),
                )
              else
                _BlueprintCanvas(
                  groupsByRoom: groupsByRoom,
                  onRoomTap: (room) => _showRoomSheet(
                    context,
                    room,
                    groupsByRoom[room.id] ?? const [],
                  ),
                ),

              const SizedBox(height: 20),
              _Legend(),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, List<_DeviceGroup>> _buildGroups(SupabaseDataProvider data) {
    final byDevice = <String, List<SensorReading>>{};
    for (final s in data.latestPerDeviceAndType) {
      final id = s.deviceId ?? '__orphan__';
      byDevice.putIfAbsent(id, () => []).add(s);
    }
    final result = <String, List<_DeviceGroup>>{
      for (final r in _rooms) r.id: <_DeviceGroup>[],
    };
    final devicesById = data.devicesById;
    byDevice.forEach((deviceId, sensors) {
      final device = devicesById[deviceId];
      final roomId = _resolveRoom(device);
      result.putIfAbsent(roomId, () => []).add(_DeviceGroup(
            id: deviceId,
            device: device,
            sensors: sensors,
          ));
    });
    return result;
  }

  void _showRoomSheet(
      BuildContext context, _Room room, List<_DeviceGroup> groups) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoomSheet(room: room, groups: groups),
    );
  }
}

// ─── Blueprint Canvas ────────────────────────────────────────

class _BlueprintCanvas extends StatelessWidget {
  final Map<String, List<_DeviceGroup>> groupsByRoom;
  final void Function(_Room room) onRoomTap;

  const _BlueprintCanvas({
    required this.groupsByRoom,
    required this.onRoomTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AspectRatio(
      // Landscape-ish blueprint: keeps both rows compact on a phone.
      aspectRatio: 16 / 11,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.blueprintBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tokens.blueprintFrame),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DotGridPainter(color: tokens.blueprintGrid),
              ),
            ),
            LayoutBuilder(
              builder: (context, c) {
                return Stack(
                  children: _rooms.map((room) {
                    final groups = groupsByRoom[room.id] ?? const [];
                    final sensorCount =
                        groups.fold<int>(0, (s, g) => s + g.sensors.length);
                    return Positioned(
                      left: c.maxWidth * (room.left / 100),
                      top: c.maxHeight * (room.top / 100),
                      width: c.maxWidth * (room.w / 100),
                      height: c.maxHeight * (room.h / 100),
                      child: _RoomTile(
                        room: room,
                        deviceCount: groups.length,
                        sensorCount: sensorCount,
                        onTap: () => onRoomTap(room),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color color;
  _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 18.0;
    const radius = 0.6;
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _RoomTile extends StatelessWidget {
  final _Room room;
  final int deviceCount;
  final int sensorCount;
  final VoidCallback onTap;

  const _RoomTile({
    required this.room,
    required this.deviceCount,
    required this.sensorCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
          decoration: BoxDecoration(
            color: room.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: tokens.blueprintRoomBorder, width: 1),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              // For really narrow rooms (e.g. Entrance) collapse to a
              // pure icon+label vertical layout. Otherwise use a top
              // row + bottom meta strip.
              final narrow = c.maxWidth < 90;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: icon (+ label if there's room)
                  if (narrow)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: room.color.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(room.icon, size: 11, color: room.color),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: room.color.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child:
                              Icon(room.icon, size: 11, color: room.color),
                        ),
                        const SizedBox(width: 6),
                        if (sensorCount > 0)
                          _SensorPin(count: sensorCount, alert: false),
                      ],
                    ),
                  const SizedBox(height: 4),

                  // Label
                  Expanded(
                    child: Text(
                      room.label,
                      style: TextStyle(
                        fontSize: narrow ? 9.5 : 11,
                        fontWeight: FontWeight.w700,
                        color: tokens.blueprintRoomLabel,
                        height: 1.15,
                      ),
                      maxLines: narrow ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Meta strip (always visible — hides for super narrow)
                  if (!narrow)
                    Text(
                      '$deviceCount dev · $sensorCount sens',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.blueprintRoomMeta,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (sensorCount > 0)
                    _SensorPin(count: sensorCount, alert: false),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SensorPin extends StatelessWidget {
  final int count;
  final bool alert;
  const _SensorPin({required this.count, required this.alert});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final tokens = context.tokens;
    final color = alert ? tokens.crimsonCore : tokens.emberCore;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.blueprintPinBg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: tokens.blueprintPinShadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: _sensorIcons.entries.map((e) {
        final cfg = e.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cfg.icon, size: 13, color: cfg.color(tokens)),
            const SizedBox(width: 4),
            Text(
              e.key,
              style: TextStyle(
                fontSize: 11,
                color: tokens.textMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ─── Room Bottom Sheet ───────────────────────────────────────

class _RoomSheet extends StatelessWidget {
  final _Room room;
  final List<_DeviceGroup> groups;

  const _RoomSheet({required this.room, required this.groups});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: tokens.bgSurface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: tokens.borderSoft),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.borderMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: room.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(room.icon, color: room.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room.label,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: tokens.textPrimary)),
                        Text(
                          '${groups.length} device${groups.length == 1 ? '' : 's'} · '
                          '${groups.fold<int>(0, (s, g) => s + g.sensors.length)} sensors',
                          style: TextStyle(
                              fontSize: 12.5, color: tokens.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: tokens.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.borderSoft),
            Expanded(
              child: groups.isEmpty
                  ? _Empty(roomLabel: room.label)
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: groups.length,
                      itemBuilder: (_, i) => _DeviceCard(
                        group: groups[i],
                        currentRoomId: room.id,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String roomLabel;
  const _Empty({required this.roomLabel});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.devices_other,
                size: 56, color: tokens.textWhisper),
            const SizedBox(height: 12),
            Text('No devices in $roomLabel yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 4),
            Text(
              'Move a device from another room using the dropdown.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final _DeviceGroup group;
  final String currentRoomId;

  const _DeviceCard({required this.group, required this.currentRoomId});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasOrphanId = group.id == '__orphan__' || group.device == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.bgRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: tokens.emberGlow,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.devices_other,
                    color: tokens.emberCore, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${group.sensors.length} sensor${group.sensors.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 11, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Sensor chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: group.sensors
                .map((s) => _SensorChip(reading: s))
                .toList(),
          ),

          const SizedBox(height: 12),

          // Room selector dropdown (disabled for orphans)
          Row(
            children: [
              Text(
                'ROOM',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: hasOrphanId
                    ? Text(
                        'Orphan reading — no device record',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: tokens.textWhisper,
                            fontStyle: FontStyle.italic),
                      )
                    : _RoomDropdown(
                        deviceId: group.id,
                        currentRoomId: currentRoomId,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SensorChip extends StatelessWidget {
  final SensorReading reading;
  const _SensorChip({required this.reading});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final cfg = _sicOf(reading.sensorType);
    final color = cfg.color(tokens);
    final isAlert = reading.isAlert;
    final isStatus = reading.unit == 'status';

    String displayValue;
    if (isStatus) {
      if (reading.sensorType == 'water') {
        displayValue = reading.value > 0 ? 'Moist' : 'Dry';
      } else if (reading.sensorType == 'motion') {
        displayValue = reading.value == 1 ? 'Active' : 'Idle';
      } else {
        displayValue = reading.value > 0 ? 'Detected' : 'Clear';
      }
    } else {
      displayValue =
          '${reading.value.toStringAsFixed(1)}${reading.unit.isNotEmpty ? reading.unit : ''}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAlert
            ? tokens.crimsonCore.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isAlert
              ? tokens.crimsonCore.withValues(alpha: 0.35)
              : color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg.icon,
              size: 12, color: isAlert ? tokens.crimsonCore : color),
          const SizedBox(width: 5),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isAlert ? tokens.crimsonCore : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomDropdown extends StatelessWidget {
  final String deviceId;
  final String currentRoomId;

  const _RoomDropdown({
    required this.deviceId,
    required this.currentRoomId,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSoft),
      ),
      child: DropdownButton<String>(
        value: currentRoomId,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: Icon(Icons.expand_more, color: tokens.textSecondary, size: 18),
        dropdownColor: tokens.bgSurface,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
        ),
        items: _rooms
            .map((r) => DropdownMenuItem<String>(
                  value: r.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(r.icon, size: 14, color: r.color),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(r.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: tokens.textPrimary)),
                      ),
                    ],
                  ),
                ))
            .toList(),
        onChanged: (next) async {
          if (next == null || next == currentRoomId) return;
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          final ok = await context
              .read<SupabaseDataProvider>()
              .assignDeviceRoom(deviceId, next);
          if (!ok) {
            messenger.showSnackBar(
              SnackBar(
                content: const Text('Failed to update room. Try again.'),
                backgroundColor: tokens.crimsonCore,
              ),
            );
          } else {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                    'Moved to ${_rooms.firstWhere((r) => r.id == next).label}'),
              ),
            );
            // Close current bottom sheet so the device shows in its new room.
            if (navigator.canPop()) navigator.pop();
          }
        },
      ),
    );
  }
}
