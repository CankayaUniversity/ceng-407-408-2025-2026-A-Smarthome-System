import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Web parity: `ResidentsPage.jsx` recognition row (embedding / photo).
enum ResidentRecognitionTone { success, warning, neutral }

class ResidentRecognitionStatus {
  final String statusLine;
  final String badgeLabel;
  final IconData badgeIcon;
  final ResidentRecognitionTone tone;

  const ResidentRecognitionStatus({
    required this.statusLine,
    required this.badgeLabel,
    required this.badgeIcon,
    required this.tone,
  });
}

bool hasResidentEmbedding(Map<String, dynamic> resident) {
  final raw = resident['embedding'];
  if (raw == null) return false;
  if (raw is List) return raw.isNotEmpty;
  if (raw is String) return raw.trim().isNotEmpty && raw.trim() != '[]';
  return true;
}

/// Mirrors web `ResidentsPage` statusLine + badge logic.
ResidentRecognitionStatus getResidentRecognitionStatus(
  Map<String, dynamic> resident,
) {
  final hasEmbedding = hasResidentEmbedding(resident);
  final hasPhoto = resident['photo_path']?.toString().trim().isNotEmpty == true;

  if (hasEmbedding) {
    return const ResidentRecognitionStatus(
      statusLine: 'Ready for recognition at the front door.',
      badgeLabel: 'Recognized',
      badgeIcon: Icons.verified_user_outlined,
      tone: ResidentRecognitionTone.success,
    );
  }
  if (hasPhoto) {
    return const ResidentRecognitionStatus(
      statusLine:
          'Photo saved. Face profile is being prepared — pull to refresh in a few seconds.',
      badgeLabel: 'Processing',
      badgeIcon: Icons.hourglass_top_outlined,
      tone: ResidentRecognitionTone.warning,
    );
  }
  return const ResidentRecognitionStatus(
    statusLine: 'Add a clear, front-facing photo to enable recognition.',
    badgeLabel: 'No photo',
    badgeIcon: Icons.image_not_supported_outlined,
    tone: ResidentRecognitionTone.neutral,
  );
}

Color recognitionToneColor(ResidentRecognitionTone tone, AppTokens tokens) {
  return switch (tone) {
    ResidentRecognitionTone.success => tokens.jadeCore,
    ResidentRecognitionTone.warning => tokens.amberCore,
    ResidentRecognitionTone.neutral => tokens.textMuted,
  };
}

Color recognitionToneBackground(
  ResidentRecognitionTone tone,
  AppTokens tokens,
) {
  return recognitionToneColor(tone, tokens).withValues(alpha: 0.12);
}
