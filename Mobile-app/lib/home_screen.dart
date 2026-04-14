import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'models/face_capture.dart';
import 'providers/auth_provider.dart';
import 'providers/supabase_data_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final supabaseData = context.watch<SupabaseDataProvider>();

    final profile = auth.profile;
    final userName = profile?['name'] ??
        auth.user?.userMetadata?['name'] ??
        'User';

    final latestTemp = supabaseData.latestTemperature;
    final latestHum = supabaseData.latestHumidity;
    final latestSmoke = supabaseData.latestSmoke;
    final latestWater = supabaseData.latestWater;

    final temp = latestTemp != null
        ? latestTemp.value.toStringAsFixed(0)
        : '--';
    final hum = latestHum != null
        ? latestHum.value.toStringAsFixed(0)
        : '--';
    final smokeDetected = latestSmoke != null && latestSmoke.value > 0;
    // water 1 = wet (good for soil), 0 = dry (needs watering → alert)
    final waterDry = latestWater != null && latestWater.value == 0;

    final latestCamRow = supabaseData.latestCameraEvent;
    final latestCapture = latestCamRow != null
        ? FaceCapture.fromCameraEvent(latestCamRow)
        : null;

    final recentEvents = supabaseData.events.take(3).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<SupabaseDataProvider>().fetchAll(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WELCOME BACK,',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1a1a2e),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.search,
                          color: Color(0xFF8C92B5)),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Daily Briefing / Alert banner
                _buildBriefingBanner(smokeDetected, waterDry),
                const SizedBox(height: 24),

                // Temperature & Humidity
                Row(
                  children: [
                    Expanded(
                      child: _buildSensorCard(
                        icon: Icons.thermostat,
                        iconColor: const Color(0xFFF97316),
                        bgColor: const Color(0xFFFFF7ED),
                        iconBg: const Color(0xFFFFEDD5),
                        value: '$temp°C',
                        label: 'TEMPERATURE',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSensorCard(
                        icon: Icons.water_drop_outlined,
                        iconColor: const Color(0xFF0EA5E9),
                        bgColor: const Color(0xFFF0F9FF),
                        iconBg: const Color(0xFFE0F2FE),
                        value: '$hum%',
                        label: 'HUMIDITY',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Smoke + Water row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusCard(
                        icon: Icons.cloud,
                        label: 'SMOKE',
                        detected: smokeDetected,
                        detectedText: 'DETECTED',
                        clearText: 'Clear',
                        alertColor: const Color(0xFFFF4757),
                        safeColor: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatusCard(
                        icon: Icons.grass,
                        label: 'WATER/SOIL',
                        detected: waterDry,
                        detectedText: 'DRY',
                        clearText: 'Moist',
                        alertColor: const Color(0xFFF97316),
                        safeColor: const Color(0xFF52B788),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Security Feed
                const Text(
                  'SECURITY FEED',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8C92B5),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSecurityFeed(latestCapture),
                const SizedBox(height: 32),

                // Recent Alerts
                if (recentEvents.isNotEmpty) ...[
                  const Text(
                    'RECENT ALERTS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8C92B5),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...recentEvents.map((e) => _buildAlertRow(e)),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBriefingBanner(bool smokeDetected, bool waterDry) {
    final hasAlert = smokeDetected || waterDry;
    final alertMsg = smokeDetected
        ? 'Smoke detected! Ventilate the area and check your sensors.'
        : waterDry
            ? 'Soil is dry! Your plants need watering.'
            : 'All systems operational. No critical issues reported today.';

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasAlert
              ? [const Color(0xFFFF6348), const Color(0xFFFF4757)]
              : [const Color(0xFF6B72D1), const Color(0xFF5C61B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (hasAlert
                    ? const Color(0xFFFF4757)
                    : const Color(0xFF5C61B2))
                .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasAlert
                          ? Icons.warning_amber_rounded
                          : Icons.auto_awesome,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    hasAlert ? 'ALERT' : 'DAILY BRIEFING',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward,
                  color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            alertMsg,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String label,
    required bool detected,
    required String detectedText,
    required String clearText,
    required Color alertColor,
    required Color safeColor,
  }) {
    final color = detected ? alertColor : safeColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: detected
            ? alertColor.withOpacity(0.06)
            : safeColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detected ? detectedText : clearText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color iconBg,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1a1a2e),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8C92B5),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityFeed(FaceCapture? capture) {
    final imageUrl = capture?.imageUrl;

    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111418),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.3), BlendMode.darken),
              )
            : null,
      ),
      child: Stack(
        children: [
          if (imageUrl == null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E1C21),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.videocam_off_outlined,
                        color: Color(0xFFFF4757), size: 24),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No Recent Capture',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          if (capture != null)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: capture.isResident
                      ? const Color(0xFF00E5A0).withOpacity(0.9)
                      : const Color(0xFFFF4757).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  capture.isResident ? 'RESIDENT' : 'UNKNOWN',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    capture != null
                        ? capture.displayName
                        : 'SECURITY CAMERA',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (capture != null)
                    Text(
                      DateFormat('HH:mm').format(capture.capturedAt),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertRow(Map<String, dynamic> event) {
    final eventType =
        (event['event_type'] ?? event['type'] ?? '').toString();
    final message =
        event['message']?.toString() ?? eventType;
    final createdAt =
        DateTime.tryParse(event['created_at']?.toString() ?? '');

    IconData icon;
    Color color;
    switch (eventType.toLowerCase()) {
      case 'fire_alert':
        icon = Icons.local_fire_department;
        color = const Color(0xFFFF4757);
        break;
      case 'flood':
        icon = Icons.water_drop;
        color = const Color(0xFF3B9EFF);
        break;
      case 'stranger_detected':
        icon = Icons.person;
        color = const Color(0xFFF97316);
        break;
      default:
        icon = Icons.notifications;
        color = const Color(0xFF8C92B5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (createdAt != null)
            Text(
              DateFormat('HH:mm').format(createdAt),
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
        ],
      ),
    );
  }
}
