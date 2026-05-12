import 'package:flutter/material.dart';
import '../models/environment_data.dart';
import '../theme/app_theme.dart';

/// Compact hazard tile for the dashboard. Shows
/// "active n/total" + "peak" with an alert frame and badge
/// when any of the sensors trips (`value > 0`).
class HazardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<SensorReading> sensors;
  final Color accent;
  final String alertText;

  const HazardCard({
    super.key,
    required this.icon,
    required this.label,
    required this.sensors,
    required this.accent,
    required this.alertText,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final active = sensors.where((s) => s.value > 0).length;
    final total = sensors.length;
    final peak = sensors.isEmpty
        ? 0.0
        : sensors
            .map((s) => s.value)
            .reduce((a, b) => a > b ? a : b);
    final isAlert = active > 0;

    final cardBg = isAlert
        ? tokens.crimsonCore.withValues(alpha: 0.06)
        : tokens.bgSurface;
    final cardBorder = isAlert
        ? tokens.crimsonCore.withValues(alpha: 0.25)
        : tokens.borderSoft;
    final iconColor = isAlert ? tokens.crimsonCore : accent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
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
                child: Icon(icon, size: 16, color: iconColor),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isAlert)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tokens.crimsonCore.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    alertText,
                    style: TextStyle(
                      color: tokens.crimsonCore,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  label: 'Active',
                  alert: isAlert,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$active',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: isAlert
                                ? tokens.crimsonCore
                                : tokens.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: '/$total',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Tile(
                  label: 'Peak',
                  alert: false,
                  child: Text(
                    total > 0 ? peak.toStringAsFixed(1) : '—',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: isAlert ? tokens.crimsonCore : accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final bool alert;
  final Widget child;

  const _Tile({
    required this.label,
    required this.alert,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: alert
            ? tokens.crimsonCore.withValues(alpha: 0.08)
            : tokens.bgRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: alert
              ? tokens.crimsonCore.withValues(alpha: 0.25)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }
}
