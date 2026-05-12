import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/supabase_data_provider.dart';
import '../models/environment_data.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedMetric = 'temperature';
  String _timeRange = '24h';

  List<Map<String, dynamic>> _metrics(AppTokens tokens) => [
        {
          'key': 'temperature',
          'label': 'Temp',
          'unit': '°C',
          'icon': Icons.thermostat,
          'color': tokens.sensorTemp,
        },
        {
          'key': 'humidity',
          'label': 'Humidity',
          'unit': '%',
          'icon': Icons.water_drop,
          'color': tokens.sensorHumid,
        },
        {
          'key': 'water',
          'label': 'Water',
          'unit': '',
          'icon': Icons.grass,
          'color': tokens.sensorMoisture,
        },
        {
          'key': 'smoke',
          'label': 'Smoke',
          'unit': '',
          'icon': Icons.cloud,
          'color': tokens.sensorSmoke,
        },
      ];

  Map<String, dynamic> _currentMetric(AppTokens tokens) =>
      _metrics(tokens).firstWhere((m) => m['key'] == _selectedMetric);

  Duration get _rangeDuration {
    switch (_timeRange) {
      case '7d':
        return const Duration(days: 7);
      case '30d':
        return const Duration(days: 30);
      default:
        return const Duration(hours: 24);
    }
  }

  int get _bucketCount {
    switch (_timeRange) {
      case '7d':
        return 7 * 6;
      case '30d':
        return 30;
      default:
        return 24;
    }
  }

  List<SensorReading> _filterByRange(List<SensorReading> all) {
    final now = DateTime.now();
    final from = now.subtract(_rangeDuration);
    return all.where((d) => d.recordedAt.isAfter(from)).toList();
  }

  List<_ChartBucket> _bucketize(List<SensorReading> readings) {
    final now = DateTime.now();
    final from = now.subtract(_rangeDuration);
    final bucketDuration = _rangeDuration ~/ _bucketCount;

    final buckets = List.generate(_bucketCount, (i) {
      final start = from.add(bucketDuration * i);
      final end = from.add(bucketDuration * (i + 1));
      return _ChartBucket(start: start, end: end);
    });

    for (final r in readings) {
      final idx =
          r.recordedAt.difference(from).inSeconds ~/ bucketDuration.inSeconds;
      if (idx >= 0 && idx < _bucketCount) {
        buckets[idx].values.add(r.value);
      }
    }
    return buckets;
  }

  double _minVal(List<SensorReading> data) {
    if (data.isEmpty) return 0;
    return data.map((d) => d.value).reduce((a, b) => a < b ? a : b);
  }

  double _maxVal(List<SensorReading> data) {
    if (data.isEmpty) return 0;
    return data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
  }

  double _avgVal(List<SensorReading> data) {
    if (data.isEmpty) return 0;
    final sum = data.map((d) => d.value).reduce((a, b) => a + b);
    return sum / data.length;
  }

  Widget _buildChart(
      List<_ChartBucket> buckets, Color color, String unit, AppTokens tokens) {
    final spots = buckets.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.avg);
    }).toList();

    final allValues = spots.map((s) => s.y).toList();
    final lo = allValues.reduce((a, b) => a < b ? a : b);
    final hi = allValues.reduce((a, b) => a > b ? a : b);
    final spread = (hi - lo) > 0 ? (hi - lo) : 1.0;

    String formatLabel(double idx) {
      final i = idx.toInt();
      if (i < 0 || i >= buckets.length) return '';
      final dt = buckets[i].start;
      switch (_timeRange) {
        case '30d':
          return DateFormat('MM/dd').format(dt);
        case '7d':
          return DateFormat('E').format(dt);
        default:
          return DateFormat('HH:mm').format(dt);
      }
    }

    final bottomInterval = _timeRange == '24h'
        ? 6.0
        : _timeRange == '7d'
            ? 6.0
            : 5.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: spread / 4,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: tokens.borderSoft, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: bottomInterval,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  formatLabel(v),
                  style: TextStyle(fontSize: 9, color: tokens.textMuted),
                ),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: TextStyle(fontSize: 10, color: tokens.textMuted),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideVertically: true,
            fitInsideHorizontally: true,
            tooltipRoundedRadius: 10,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final i = s.x.toInt();
              final bucket =
                  (i >= 0 && i < buckets.length) ? buckets[i] : null;
              final timeLabel = bucket != null
                  ? DateFormat('MMM dd HH:mm').format(bucket.start)
                  : '';
              return LineTooltipItem(
                '${s.y.toStringAsFixed(1)}${unit.isNotEmpty ? unit : ''}\n$timeLabel',
                TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, String unit, Color color,
      AppTokens tokens) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.borderSoft),
        ),
        child: Column(
          children: [
            Text(
              '$value$unit',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: tokens.textMuted)),
          ],
        ),
      ),
    );
  }

  String _formatValue(SensorReading r, String unit) {
    if (r.unit == 'status') {
      if (r.sensorType == 'water') {
        return r.value > 0 ? 'Moist' : 'Dry';
      }
      return r.value > 0 ? 'Detected' : 'Clear';
    }
    return '${r.value.toStringAsFixed(1)}${unit.isNotEmpty ? unit : ' ${r.unit}'}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final supabaseData = context.watch<SupabaseDataProvider>();
    final allForType = supabaseData.readingsForType(_selectedMetric);
    final filtered = _filterByRange(allForType);
    final buckets = _bucketize(filtered);
    final metric = _currentMetric(tokens);
    final color = metric['color'] as Color;
    final unit = metric['unit'] as String;
    final metrics = _metrics(tokens);

    return Scaffold(
      backgroundColor: tokens.bgVoid,
      body: SafeArea(
        child: supabaseData.loading && supabaseData.sensorReadings.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : supabaseData.error != null &&
                    supabaseData.sensorReadings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off,
                            size: 56, color: tokens.textWhisper),
                        const SizedBox(height: 12),
                        Text(supabaseData.error!,
                            style: TextStyle(color: tokens.textMuted)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () =>
                              context.read<SupabaseDataProvider>().fetchAll(),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.emberCore,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        context.read<SupabaseDataProvider>().fetchAll(),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Analytics',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Historical sensor data',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: tokens.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: Row(
                              children: metrics.map((m) {
                                final isSelected =
                                    m['key'] == _selectedMetric;
                                final col = m['color'] as Color;
                                return Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () => setState(() =>
                                          _selectedMetric =
                                              m['key'] as String),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 200),
                                        padding:
                                            const EdgeInsets.symmetric(
                                                vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? col.withValues(alpha: 0.12)
                                              : tokens.bgSurface,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isSelected
                                                ? col
                                                : tokens.borderSoft,
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              m['icon'] as IconData,
                                              color: isSelected
                                                  ? col
                                                  : tokens.textMuted,
                                              size: 20,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              m['label'] as String,
                                              textAlign:
                                                  TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: isSelected
                                                    ? col
                                                    : tokens.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 14, 20, 0),
                            child: Row(
                              children:
                                  ['24h', '7d', '30d'].map((range) {
                                final selected = _timeRange == range;
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _timeRange = range),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 200),
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 10),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? tokens.emberCore
                                            : tokens.bgSurface,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                          color: selected
                                              ? tokens.emberCore
                                              : tokens.borderSoft,
                                        ),
                                      ),
                                      child: Text(
                                        range,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? Colors.white
                                              : tokens.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Row(
                              children: [
                                _buildMiniStat(
                                    'Min',
                                    _minVal(filtered).toStringAsFixed(1),
                                    unit,
                                    color,
                                    tokens),
                                const SizedBox(width: 10),
                                _buildMiniStat(
                                    'Max',
                                    _maxVal(filtered).toStringAsFixed(1),
                                    unit,
                                    color,
                                    tokens),
                                const SizedBox(width: 10),
                                _buildMiniStat(
                                    'Avg',
                                    _avgVal(filtered).toStringAsFixed(1),
                                    unit,
                                    color,
                                    tokens),
                                const SizedBox(width: 10),
                                _buildMiniStat(
                                    'Count',
                                    '${filtered.length}',
                                    '',
                                    tokens.textSecondary,
                                    tokens),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: Container(
                              height: 280,
                              padding: const EdgeInsets.fromLTRB(
                                  8, 36, 16, 8),
                              decoration: BoxDecoration(
                                color: tokens.bgSurface,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: tokens.borderSoft),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: _buildChart(
                                  buckets, color, unit, tokens),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                20, 20, 20, 8),
                            child: Text(
                              'Recent Readings',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: tokens.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        if (filtered.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) {
                                  final limit = filtered.length > 30
                                      ? 30
                                      : filtered.length;
                                  if (i >= limit) return null;
                                  final entry = filtered[i];
                                  return Container(
                                    margin:
                                        const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: tokens.bgSurface,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                          color: tokens.borderSoft),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.circle,
                                            size: 8, color: color),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            DateFormat('MMM dd, HH:mm')
                                                .format(entry.recordedAt),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: tokens.textSecondary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatValue(entry, unit),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: entry.isAlert
                                                ? tokens.crimsonCore
                                                : color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                childCount: filtered.length > 30
                                    ? 30
                                    : filtered.length,
                              ),
                            ),
                          ),
                        if (filtered.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              child: Text(
                                'No readings in this period',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: tokens.textWhisper),
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 24)),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _ChartBucket {
  final DateTime start;
  final DateTime end;
  final List<double> values = [];

  _ChartBucket({required this.start, required this.end});

  double get avg =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
}
