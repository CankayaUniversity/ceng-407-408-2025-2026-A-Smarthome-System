import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'models/face_capture.dart';
import 'models/environment_data.dart';
import 'providers/auth_provider.dart';
import 'providers/supabase_data_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/hazard_card.dart';
import 'camera_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final auth = context.watch<AuthProvider>();
    final supabaseData = context.watch<SupabaseDataProvider>();

    final profile = auth.profile;
    final userName = profile?['name'] ??
        auth.user?.userMetadata?['name'] ??
        'User';

    final tempReadings = supabaseData.temperatureReadings;
    final humReadings = supabaseData.humidityReadings;
    final smokeReadings = supabaseData.smokeReadings;
    final waterReadings = supabaseData.waterReadings;
    final motionReadings = supabaseData.motionReadings;

    final avgTemp = _avg(tempReadings);
    final avgHum = _avg(humReadings);
    final activeMotion =
        motionReadings.where((s) => s.value == 1).length;
    final criticalAlerts = supabaseData.events
        .where((e) =>
            (e['priority']?.toString().toLowerCase() == 'critical') &&
            e['acknowledged'] != true)
        .length;

    final latestCamRow = supabaseData.latestCameraEvent;
    final latestCapture = latestCamRow != null
        ? FaceCapture.fromCameraEvent(latestCamRow)
        : null;

    final recentEvents = supabaseData.events.take(3).toList();
    final hasAnyAlert =
        smokeReadings.any((s) => s.value > 0) ||
            waterReadings.any((s) => s.value == 0);

    return Scaffold(
      backgroundColor: tokens.bgVoid,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<SupabaseDataProvider>().fetchAll(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header — compact
                _Header(
                  userName: userName,
                  sensors: supabaseData.latestPerDeviceAndType.length,
                ),
                const SizedBox(height: 16),

                // Camera Hero (21:9 aspect)
                _CameraHero(
                  capture: latestCapture,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraScreen()),
                  ),
                ),
                const SizedBox(height: 12),

                // 2x2 stat grid — Security · Climate · Smoke · Water
                LayoutBuilder(builder: (_, constraints) {
                  final w = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: w,
                        child: _StatCard(
                          icon: Icons.shield,
                          label: 'SECURITY',
                          accent: tokens.violetCore,
                          alert: criticalAlerts > 0,
                          rows: [
                            _StatRow('Motion', '$activeMotion zones'),
                            _StatRow('Alerts', '$criticalAlerts active'),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: w,
                        child: _StatCard(
                          icon: Icons.thermostat,
                          label: 'CLIMATE',
                          accent: tokens.emberCore,
                          alert: false,
                          rows: [
                            _StatRow('Avg Temp',
                                '${avgTemp.toStringAsFixed(1)}°C'),
                            _StatRow('Avg Hum',
                                '${avgHum.toStringAsFixed(0)}%'),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: w,
                        child: HazardCard(
                          icon: Icons.cloud,
                          label: 'SMOKE',
                          sensors: smokeReadings,
                          accent: tokens.sensorSmoke,
                          alertText: 'ALERT',
                        ),
                      ),
                      SizedBox(
                        width: w,
                        child: HazardCard(
                          icon: Icons.water_drop,
                          label: 'WATER',
                          sensors: waterReadings,
                          accent: tokens.sensorWater,
                          alertText: 'LEAK',
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 20),

                // Briefing banner
                _BriefingBanner(hasAlert: hasAnyAlert),
                const SizedBox(height: 20),

                // Recent Alerts strip
                if (recentEvents.isNotEmpty) ...[
                  Text(
                    'RECENT ALERTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tokens.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...recentEvents.map((e) => _AlertRow(event: e)),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static double _avg(List<SensorReading> list) {
    if (list.isEmpty) return 0;
    final sum = list.map((s) => s.value).reduce((a, b) => a + b);
    return sum / list.length;
  }
}

// ─── Header ─────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String userName;
  final int sensors;
  const _Header({required this.userName, required this.sensors});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WELCOME BACK,',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: tokens.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                userName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: tokens.jadeCore,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$sensors sensors active',
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Camera Hero ─────────────────────────────────────────────

class _CameraHero extends StatelessWidget {
  final FaceCapture? capture;
  final VoidCallback onTap;
  const _CameraHero({required this.capture, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final imageUrl = capture?.imageUrl;

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 21 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0C10),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _empty(tokens, 'Snapshot unavailable'),
                )
              else
                _empty(tokens, 'No Recent Capture'),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),

              // Top-left LIVE pill
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.crimsonCore.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'LAST SNAPSHOT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Top-right classification badge
              if (capture != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: capture!.isResident
                          ? tokens.jadeCore.withValues(alpha: 0.9)
                          : tokens.crimsonCore.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      capture!.isResident ? 'RESIDENT' : 'UNKNOWN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

              // Bottom row — title + time
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Front Door Surveillance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (capture != null)
                      Text(
                        DateFormat('HH:mm').format(capture!.capturedAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(AppTokens tokens, String text) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.bgElevated,
            tokens.bgBase,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined,
                size: 28, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(height: 6),
            Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────

class _StatRow {
  final String label;
  final String value;
  _StatRow(this.label, this.value);
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool alert;
  final List<_StatRow> rows;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.accent,
    required this.alert,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alert
            ? tokens.crimsonCore.withValues(alpha: 0.06)
            : tokens.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert
              ? tokens.crimsonCore.withValues(alpha: 0.25)
              : tokens.borderSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tokens.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.textMuted,
                      ),
                    ),
                    Text(
                      r.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Briefing Banner ──────────────────────────────────────────

class _BriefingBanner extends StatelessWidget {
  final bool hasAlert;
  const _BriefingBanner({required this.hasAlert});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = hasAlert
        ? [tokens.crimsonCore, tokens.emberCore]
        : [tokens.violetCore, tokens.cyanCore];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasAlert ? Icons.warning_amber_rounded : Icons.auto_awesome,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAlert ? 'ATTENTION REQUIRED' : 'ALL SYSTEMS GREEN',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasAlert
                      ? 'One or more sensors triggered an alert. Tap an alert below for details.'
                      : 'No critical issues reported. Your home is operating normally.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
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

// ─── Alert Row ────────────────────────────────────────────────

class _AlertRow extends StatelessWidget {
  final Map<String, dynamic> event;
  const _AlertRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final eventType =
        (event['event_type'] ?? event['type'] ?? '').toString();
    final message = event['message']?.toString() ?? eventType;
    final createdAt =
        DateTime.tryParse(event['created_at']?.toString() ?? '');

    IconData icon;
    Color color;
    switch (eventType.toLowerCase()) {
      case 'fire_alert':
        icon = Icons.local_fire_department;
        color = tokens.crimsonCore;
        break;
      case 'flood':
        icon = Icons.water_drop;
        color = tokens.sensorWater;
        break;
      case 'stranger_detected':
        icon = Icons.person;
        color = tokens.emberCore;
        break;
      default:
        icon = Icons.notifications;
        color = tokens.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: tokens.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (createdAt != null)
            Text(
              DateFormat('HH:mm').format(createdAt),
              style: TextStyle(fontSize: 11, color: tokens.textMuted),
            ),
        ],
      ),
    );
  }
}
