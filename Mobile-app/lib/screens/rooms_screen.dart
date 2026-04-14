import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/supabase_data_provider.dart';

const List<Map<String, dynamic>> _rooms = [
  {'id': 'kitchen', 'label': 'Kitchen Hub', 'icon': Icons.countertops, 'color': Color(0xFFFF6B35), 'keys': ['Kitchen']},
  {'id': 'living', 'label': 'Living Room', 'icon': Icons.weekend, 'color': Color(0xFF5C61B2), 'keys': ['living', 'Main RPi']},
  {'id': 'bedroom', 'label': 'Master Bedroom', 'icon': Icons.bed, 'color': Color(0xFF9B59FF), 'keys': ['Bedroom', 'Master']},
  {'id': 'entrance', 'label': 'Entrance', 'icon': Icons.lock, 'color': Color(0xFF00E5A0), 'keys': ['Door', 'Front', 'Entrance']},
  {'id': 'bathroom', 'label': 'Bathroom', 'icon': Icons.shower, 'color': Color(0xFF3B9EFF), 'keys': ['Bathroom']},
  {'id': 'garden', 'label': 'Garden', 'icon': Icons.local_florist, 'color': Color(0xFF52B788), 'keys': ['Garden']},
];

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<SupabaseDataProvider>();
    final isLoading = data.loading && data.sensorReadings.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => data.fetchAll(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rooms',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a1a2e))),
                      const SizedBox(height: 4),
                      Text('Tap a room to see its sensors',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ),
              if (isLoading)
                const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()))
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.95,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _buildRoomCard(context, _rooms[i], data),
                      childCount: _rooms.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomCard(
      BuildContext context, Map<String, dynamic> room, SupabaseDataProvider data) {
    final color = room['color'] as Color;

    final sensors = <Map<String, dynamic>>[];
    final latestTemp = data.latestTemperature;
    final latestHum = data.latestHumidity;
    final latestSmoke = data.latestSmoke;
    final latestWater = data.latestWater;

    if (latestTemp != null) {
      sensors.add({
        'type': 'temperature',
        'label': 'Temperature',
        'value': latestTemp.value,
        'unit': '°C',
      });
    }
    if (latestHum != null) {
      sensors.add({
        'type': 'humidity',
        'label': 'Humidity',
        'value': latestHum.value,
        'unit': '%',
      });
    }
    if (latestSmoke != null) {
      sensors.add({
        'type': 'smoke',
        'label': 'Smoke',
        'value': latestSmoke.value,
        'unit': latestSmoke.unit == 'status' ? '' : ' ${latestSmoke.unit}',
        'alert': latestSmoke.value > 0,
      });
    }
    if (latestWater != null) {
      sensors.add({
        'type': 'water',
        'label': 'Water / Soil',
        'value': latestWater.value,
        'unit': latestWater.unit == 'status' ? '' : ' ${latestWater.unit}',
        'alert': latestWater.value == 0,
      });
    }

    return GestureDetector(
      onTap: () => _showRoomDrawer(context, room, sensors, color),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(room['icon'] as IconData, color: color, size: 26),
            ),
            const Spacer(),
            Text(
              room['label'],
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1a1a2e)),
            ),
            const SizedBox(height: 4),
            Text(
              '${sensors.length} sensors',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomDrawer(BuildContext context, Map<String, dynamic> room,
      List<Map<String, dynamic>> sensors, Color color) {
    final sensorIcons = {
      'temperature': {'icon': Icons.thermostat, 'color': const Color(0xFFFF6B35)},
      'humidity': {'icon': Icons.water_drop, 'color': const Color(0xFF3B9EFF)},
      'smoke': {'icon': Icons.cloud, 'color': const Color(0xFFFF6348)},
      'water': {'icon': Icons.grass, 'color': const Color(0xFF52B788)},
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
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
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(room['icon'] as IconData,
                          color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(room['label'],
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          Text('${sensors.length} sensors',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: sensors.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sensors_off,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text('No sensors in this room',
                                style: TextStyle(
                                    color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20),
                        itemCount: sensors.length,
                        itemBuilder: (_, i) {
                          final s = sensors[i];
                          final si = sensorIcons[s['type']] ??
                              {
                                'icon': Icons.sensors,
                                'color': Colors.grey
                              };
                          final c = si['color'] as Color;
                          final isAlert = s['alert'] == true;
                          final isStatus = s['unit'] == '' &&
                              (s['type'] == 'smoke' || s['type'] == 'water');
                          final displayValue = isStatus
                              ? ((s['value'] as num) > 0 ? 'Detected' : 'Clear')
                              : '${(s['value'] as num).toStringAsFixed(1)}${s['unit'] ?? ''}';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isAlert
                                  ? const Color(0xFFFFF0F1)
                                  : c.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: isAlert
                                      ? const Color(0xFFFF4757)
                                          .withOpacity(0.3)
                                      : c.withOpacity(0.12)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: c.withOpacity(0.12),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Icon(si['icon'] as IconData,
                                      color: c, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s['label'] ?? s['type'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                      if (isAlert)
                                        const Text('ALERT',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.bold,
                                                color:
                                                    Color(0xFFFF4757))),
                                    ],
                                  ),
                                ),
                                Text(
                                  displayValue,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isAlert
                                          ? const Color(0xFFFF4757)
                                          : c),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
